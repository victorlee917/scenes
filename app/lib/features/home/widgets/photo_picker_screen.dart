import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../core/data/lru_cache.dart';
import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/floating_bottom_sheet.dart';
import '../../../l10n/app_localizations.dart';
import '../../upload/upload_queue_view_model.dart';
import '../models/scene.dart';
import 'detail_app_bar.dart';
import 'scene_detail_screen.dart';

/// 사진 선택 화면.
///
/// 업로드 단계는 다음을 거친다:
/// 1. AssetEntity의 `originBytes` 로드.
/// 2. EXIF 파싱(`PhotoMetadataExtractor`) — 없어도 기본 정보는 채움.
/// 3. thumb/full 두 변형 생성 (`flutter_image_compress`). tier 무관 동일.
///    - thumb: 600 long edge, q75
///    - full : 1920 long edge, q85
/// 4. EF `upload-photo-content` 호출 (multipart full+thumb+payload JSON).
/// 5. 받아온 Content를 contentsForSceneProvider 리스트에 append.
class PhotoPickerScreen extends ConsumerStatefulWidget {
  const PhotoPickerScreen({
    super.key,
    this.scene,
    this.momentDate,
    this.landOnSceneDetail = true,
    this.maxSelection = _kDefaultMaxSelection,
  });

  final Scene? scene;
  // AddMediaSheet에서 사용자가 고른 모먼트 날짜. 업로드 시 occurred_at으로
  // 저장됨 (EXIF taken_at보다 우선).
  final DateTime? momentDate;

  /// save 후 SceneDetail로 push할지 여부. home처럼 detail 밖에서 진입했을 땐
  /// true, 이미 SceneDetail 위에서 + 버튼으로 진입했을 땐 false — 같은 detail
  /// 화면이 stack에 중복 쌓이는 것 방지.
  final bool landOnSceneDetail;

  /// 한 batch에서 선택 가능한 최대 사진 수. AddMediaSheet가 scene의 남은
  /// 한도를 계산해 넘김(remaining = limit - count). picker 자체의 batch 상한
  /// (성능)과 함께 작은 쪽이 유효 한도로 적용된다.
  final int maxSelection;

  /// picker 자체의 batch 성능 상한 — 한 번에 너무 많이 고르면 압축·전송이
  /// 부담스러움. 사용자의 남은 slot이 더 작으면 그게 우선.
  static const int _kDefaultMaxSelection = 30;

  static Route<List<AssetEntity>?> route({
    Scene? scene,
    DateTime? momentDate,
    bool landOnSceneDetail = true,
    int maxSelection = _kDefaultMaxSelection,
  }) {
    return PageRouteBuilder<List<AssetEntity>?>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 340),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) =>
          PhotoPickerScreen(
        scene: scene,
        momentDate: momentDate,
        landOnSceneDetail: landOnSceneDetail,
        maxSelection: maxSelection,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
          reverseCurve: Curves.easeIn,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  @override
  ConsumerState<PhotoPickerScreen> createState() => _PhotoPickerScreenState();
}

class _PhotoPickerScreenState extends ConsumerState<PhotoPickerScreen> {
  // picker 성능 상한과 widget.maxSelection(scene의 남은 slot) 중 작은 값.
  int get _maxSelection => widget.maxSelection.clamp(
        1,
        PhotoPickerScreen._kDefaultMaxSelection,
      );

  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _currentAlbum;
  List<AssetEntity> _assets = [];
  final List<AssetEntity> _selected = [];
  // 그리드 썸네일 캐시 — LRU로 상한을 둬 대용량 라이브러리에서 메모리가
  // 무한히 늘지 않게. 300이면 일반적인 그리드 + 프리뷰는 모두 hot 유지.
  final LruCache<String, Uint8List> _thumbCache = LruCache(maxSize: 300);
  bool _loading = true;

  // 캡 도달 시 토스트 디듀프 — AppToast가 2.2초 표시되므로 같은 윈도우 안에서
  // 추가 탭이 와도 한 번만 보여주기 위함.
  bool _toastShowing = false;

  // ── 마키(영역) 셀렉트 ────────────────────────────────────────
  // 마우스 드래그 셀렉트와 동일한 모델. 드래그 시작점과 현재점이 만드는
  // 사각형 안에 들어간 셀들을 추가(또는 해제)한다. 영역에서 빠지면 원래대로
  // 복원되도록 시작 시점의 selection 스냅샷을 보관.
  final ScrollController _gridController = ScrollController();
  // GridView의 좌상단 좌표를 알기 위한 키 — globalPosition → localPosition
  // 변환에 사용.
  final GlobalKey _gridKey = GlobalKey();
  // 드래그 활성 여부.
  bool _dragSelecting = false;
  // origin 셀이 미선택이면 추가 모드, 선택이면 해제 모드.
  bool _dragTargetSelect = true;
  // origin 셀의 _assets 인덱스. drag-and-return cancel에 사용.
  int? _dragOriginCellIdx;
  // 드래그 도중 origin 셀 밖으로 한 번이라도 나갔는지. true 상태에서 다시
  // origin 셀로 돌아오면 origin도 inside에서 빼서 토글 취소.
  bool _dragMovedAwayFromOrigin = false;
  // 드래그 시작 시점의 selection 스냅샷 — 영역에서 빠진 셀을 원복할 때 참조.
  List<AssetEntity> _dragOriginalSelected = const [];
  // 드래그 중에만 채워지는 미리보기 선택. 셀의 selected/order는 이 값을 기준
  // 으로 그려지지만, 상단 _PreviewTile row와 _selected 자체는 건드리지 않음.
  // 드래그 종료 시 _selected에 commit.
  List<AssetEntity>? _dragPreviewSelected;
  // grid-content 좌표(스크롤 오프셋 포함). origin은 down 시점, current는 마지막
  // pan update.
  Offset? _dragOrigin;
  Offset? _dragCurrent;
  // 가장 최근 pan update의 globalPosition. auto-scroll tick에서 같은 손가락
  // 위치로 grid-content 좌표를 다시 계산하기 위해 보관.
  Offset? _lastDragGlobal;
  Timer? _autoScrollTimer;
  // 한 번이라도 edge zone 바깥에 있었는지 — 시작 지점이 edge zone이라
  // 즉시 auto-scroll이 발동되는 것을 막기 위함.
  bool _wasOutsideEdgeZone = false;
  double _gridCellSide = 0;
  static const double _kGridPadding = 2;
  static const double _kGridSpacing = 2;
  static const int _kGridCols = 3;
  // 그리드 viewport 가장자리에서 이만큼 안쪽으로 들어가면 auto-scroll 시작.
  static const double _kEdgeZone = 60;
  // 한 tick(~16ms)에 움직이는 최대 픽셀 수. 가장자리에 가까울수록 비례 증가.
  static const double _kMaxScrollPerTick = 10;
  // 마키(복수 선택) 모드 진입까지의 long-press 시간. 기본 500ms는 길게
  // 느껴져 단축 — 일반 스크롤(즉시 이동)과는 여전히 구분된다. 너무 짧으면
  // 느린 탭이 선택 모드로 오인될 수 있어 200ms를 하한으로 본다.
  // 스크롤 의도와 마키 의도 분리용. 너무 짧으면 손가락이 잠깐 머무는 사이에
  // long-press가 arena를 잡아 의도치 않은 selection이 생김. Flutter 기본
  // kLongPressTimeout(500ms)과의 절충점.
  static const Duration _kMarqueeLongPressDelay = Duration(milliseconds: 400);

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _gridController.dispose();
    super.dispose();
  }

  /// global → grid-content 좌표 변환(=스크롤 포함, 즉 콘텐츠 원점 기준).
  Offset? _toGridContent(Offset globalPos) {
    final ctx = _gridKey.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject();
    if (box is! RenderBox) return null;
    final local = box.globalToLocal(globalPos);
    return Offset(local.dx, local.dy + _gridController.offset);
  }

  /// grid-content 좌표(_toGridContent 결과) 한 점을 (row, col)로 환산.
  /// padding/spacing 위에 떨어져도 가까운 셀로 스냅.
  ({int row, int col})? _cellAt(Offset gridPos) {
    if (_gridCellSide <= 0) return null;
    final stride = _gridCellSide + _kGridSpacing;
    final lx = gridPos.dx - _kGridPadding;
    final ly = gridPos.dy - _kGridPadding;
    if (ly < 0) return null;
    final col = (lx / stride).floor().clamp(0, _kGridCols - 1);
    final row = (ly / stride).floor();
    if (row < 0) return null;
    return (row: row, col: col);
  }

  int? _indexAt(Offset gridPos) {
    final c = _cellAt(gridPos);
    if (c == null) return null;
    final idx = c.row * _kGridCols + c.col;
    if (idx < 0 || idx >= _assets.length) return null;
    return idx;
  }

  /// 마키 사각형(grid-content 좌표) → 그 안에 들어가는 _assets 인덱스 집합.
  /// 셀 본체와 사각형이 겹치면 포함.
  Set<int> _indicesInMarquee(Rect rect) {
    if (_gridCellSide <= 0) return const {};
    final stride = _gridCellSide + _kGridSpacing;
    // rect를 padding 기준으로 정규화.
    final left = rect.left - _kGridPadding;
    final right = rect.right - _kGridPadding;
    final top = rect.top - _kGridPadding;
    final bottom = rect.bottom - _kGridPadding;
    int colFrom = (left / stride).floor();
    int colTo = (right / stride).floor();
    int rowFrom = (top / stride).floor();
    int rowTo = (bottom / stride).floor();
    colFrom = colFrom.clamp(0, _kGridCols - 1);
    colTo = colTo.clamp(0, _kGridCols - 1);
    if (rowFrom < 0) rowFrom = 0;
    if (rowTo < 0) return const {};
    final result = <int>{};
    for (int r = rowFrom; r <= rowTo; r++) {
      for (int c = colFrom; c <= colTo; c++) {
        final idx = r * _kGridCols + c;
        if (idx >= 0 && idx < _assets.length) result.add(idx);
      }
    }
    return result;
  }

  /// 캡 binding이 picker batch(20)인지, scene 잔여 슬롯인지에 맞춰 토스트.
  void _showCapToastForBinding() {
    final l10n = AppLocalizations.of(context);
    final reachedBatchCap =
        _maxSelection >= PhotoPickerScreen._kDefaultMaxSelection;
    _showCapToast(
      reachedBatchCap
          ? l10n.photoPickerBatchCapToast(
              PhotoPickerScreen._kDefaultMaxSelection,
            )
          : l10n.photoPickerSceneCapToast,
    );
  }

  /// 마키 드래그 시작 — origin 셀의 선택 상태로 추가/해제 모드 결정.
  /// 이 시점부터 끝까지 _selected는 건드리지 않고 _dragPreviewSelected만
  /// 갱신. end 시 commit. 일반 vertical swipe는 그리드 스크롤로 가도록
  /// long-press가 인식된 뒤에만 마키 모드로 진입.
  void _onMarqueeStart(LongPressStartDetails details) {
    final origin = _toGridContent(details.globalPosition);
    if (origin == null) return;
    final originIdx = _indexAt(origin);
    final wasOriginSelected =
        originIdx != null && _selected.contains(_assets[originIdx]);
    setState(() {
      _dragSelecting = true;
      _dragTargetSelect = !wasOriginSelected;
      _dragOriginalSelected = List.of(_selected);
      _dragOrigin = origin;
      _dragCurrent = origin;
      _dragOriginCellIdx = originIdx;
      _dragMovedAwayFromOrigin = false;
      _lastDragGlobal = details.globalPosition;
      _wasOutsideEdgeZone = false;
      _dragPreviewSelected = _computeMarqueePreview();
    });
  }

  void _onMarqueeUpdate(LongPressMoveUpdateDetails details) {
    if (!_dragSelecting) return;
    _lastDragGlobal = details.globalPosition;
    final cur = _toGridContent(details.globalPosition);
    if (cur == null) return;
    final curIdx = _indexAt(cur);
    if (curIdx != null &&
        _dragOriginCellIdx != null &&
        curIdx != _dragOriginCellIdx) {
      _dragMovedAwayFromOrigin = true;
    }
    setState(() {
      _dragCurrent = cur;
      _dragPreviewSelected = _computeMarqueePreview();
    });
    _maybeStartAutoScroll();
  }

  void _onMarqueeEnd() {
    if (!_dragSelecting) return;
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    final committed = _dragPreviewSelected ?? _selected;
    setState(() {
      // 드래그 중 시각 상태로 보던 선택을 _selected에 확정.
      _selected
        ..clear()
        ..addAll(committed);
      _dragSelecting = false;
      _dragOrigin = null;
      _dragCurrent = null;
      _dragOriginalSelected = const [];
      _dragPreviewSelected = null;
      _lastDragGlobal = null;
      _wasOutsideEdgeZone = false;
      _dragOriginCellIdx = null;
      _dragMovedAwayFromOrigin = false;
    });
  }

  /// 현재 드래그 사각형으로 빌드한 미리보기 selection. _selected는 건드리지
  /// 않고 list만 반환. 영역에서 빠진 셀은 원복(=base에 그대로 유지)되므로
  /// 역방향 드래그 시 그동안 추가/제거된 게 자연스럽게 취소됨.
  List<AssetEntity> _computeMarqueePreview() {
    final origin = _dragOrigin;
    final cur = _dragCurrent;
    if (origin == null || cur == null) return List.of(_dragOriginalSelected);
    final rect = Rect.fromPoints(origin, cur);
    final inside = _indicesInMarquee(rect);
    // drag-and-return 캔슬: 한 번 origin 밖으로 나갔다가 다시 origin 셀로
    // 돌아왔으면 origin도 inside에서 제거 → 토글 취소(=base 그대로).
    if (_dragMovedAwayFromOrigin && _dragOriginCellIdx != null) {
      final curIdx = _indexAt(cur);
      if (curIdx == _dragOriginCellIdx) {
        inside.remove(_dragOriginCellIdx);
      }
    }
    final base = List<AssetEntity>.of(_dragOriginalSelected);
    bool capHit = false;
    if (_dragTargetSelect) {
      final sortedInside = inside.toList()..sort();
      for (final idx in sortedInside) {
        final asset = _assets[idx];
        if (base.contains(asset)) continue;
        if (base.length >= _maxSelection) {
          capHit = true;
          break;
        }
        base.add(asset);
      }
    } else {
      for (final idx in inside) {
        base.remove(_assets[idx]);
      }
    }
    if (capHit) _showCapToastForBinding();
    return base;
  }

  /// 손가락이 가장자리 zone에 들어가면 auto-scroll tick 시작. 이미 돌고
  /// 있으면 그대로. 가장자리에서 빠지면 tick 안에서 자기 정지.
  void _maybeStartAutoScroll() {
    if (_autoScrollTimer != null) return;
    if (_currentScrollVelocity() == 0) return;
    _autoScrollTimer = Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _autoScrollTick(),
    );
  }

  /// 현재 손가락 위치(_lastDragGlobal) 기준 viewport 좌표로 환산해 가장자리
  /// 침범 정도에 비례한 px/tick velocity 반환. 0이면 정지.
  ///
  /// **edge zone 가드** — 사용자가 edge zone에서 드래그를 시작하면 첫
  /// update 때 즉시 auto-scroll이 켜져서 "드래그하자마자 화면이 내려감"으로
  /// 보임. 그래서 한 번이라도 edge zone 밖으로 나간 적이 있을 때만 다시
  /// 들어왔을 때 auto-scroll 발동. 시작 지점이 edge zone이면 그곳을 떠난
  /// 뒤에야 의미 부여.
  double _currentScrollVelocity() {
    final pos = _lastDragGlobal;
    if (pos == null) return 0;
    final ctx = _gridKey.currentContext;
    if (ctx == null) return 0;
    final box = ctx.findRenderObject();
    if (box is! RenderBox) return 0;
    final local = box.globalToLocal(pos);
    final h = box.size.height;
    final inTop = local.dy < _kEdgeZone;
    final inBottom = local.dy > h - _kEdgeZone;
    if (!inTop && !inBottom) {
      _wasOutsideEdgeZone = true;
      return 0;
    }
    if (!_wasOutsideEdgeZone) return 0;
    if (inTop) {
      final ratio = (_kEdgeZone - local.dy) / _kEdgeZone;
      return -ratio.clamp(0.0, 1.0) * _kMaxScrollPerTick;
    }
    final ratio = (local.dy - (h - _kEdgeZone)) / _kEdgeZone;
    return ratio.clamp(0.0, 1.0) * _kMaxScrollPerTick;
  }

  void _autoScrollTick() {
    if (!_dragSelecting) {
      _autoScrollTimer?.cancel();
      _autoScrollTimer = null;
      return;
    }
    final v = _currentScrollVelocity();
    if (v == 0) {
      _autoScrollTimer?.cancel();
      _autoScrollTimer = null;
      return;
    }
    if (!_gridController.hasClients) return;
    final maxExt = _gridController.position.maxScrollExtent;
    final next = (_gridController.offset + v).clamp(0.0, maxExt);
    if (next == _gridController.offset) {
      // 끝까지 닿음 — tick은 계속 돌게 두고 손가락이 가장자리를 벗어나면
      // velocity=0으로 자기 정지.
      return;
    }
    _gridController.jumpTo(next);
    // 손가락은 그대로지만 스크롤 오프셋이 변했으니 grid-content 좌표를
    // 재계산해서 사각형 확장 + preview 갱신.
    final pos = _lastDragGlobal;
    if (pos == null) return;
    final cur = _toGridContent(pos);
    if (cur == null) return;
    setState(() {
      _dragCurrent = cur;
      _dragPreviewSelected = _computeMarqueePreview();
    });
  }

  Future<Uint8List?> _getThumb(AssetEntity asset, int size) async {
    final key = '${asset.id}_$size';
    final cached = _thumbCache.get(key);
    if (cached != null) return cached;
    final data = await asset.thumbnailDataWithSize(ThumbnailSize(size, size));
    if (data != null) _thumbCache.put(key, data);
    return data;
  }

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      filterOption: FilterOptionGroup(
        orders: [
          const OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      ),
    );
    if (albums.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted) setState(() => _albums = albums);
    await _selectAlbum(albums.first);
  }

  Future<void> _selectAlbum(AssetPathEntity album) async {
    setState(() {
      _currentAlbum = album;
      _loading = true;
    });
    // 메타데이터만 미리 로드 — 실제 thumb 디코드는 grid가 visible cell에 대해
    // lazy로 처리하므로, 앨범 전체 로드해도 첫 페인트 비용은 거의 동일.
    // 큰 앨범(>5만장 등)을 위한 안전 cap 적용.
    const safetyCap = 10000;
    final total = await album.assetCountAsync;
    final end = total > safetyCap ? safetyCap : total;
    final assets = await album.getAssetListRange(start: 0, end: end);
    if (mounted) {
      setState(() {
        _assets = assets;
        _loading = false;
      });
    }
  }

  void _showAlbumPicker() {
    FloatingBottomSheet.show(
      context: context,
      builder: (_) => _AlbumList(
        albums: _albums,
        currentId: _currentAlbum?.id,
        onSelect: (album) {
          Navigator.of(context).pop();
          _selectAlbum(album);
        },
      ),
    );
  }

  void _toggleSelect(AssetEntity asset) {
    if (_selected.contains(asset)) {
      setState(() => _selected.remove(asset));
      return;
    }
    if (_selected.length < _maxSelection) {
      setState(() => _selected.add(asset));
      return;
    }
    // cap 도달 — 더 추가 못 하는 이유(picker batch vs. scene 잔여)에 따라
    // 다른 메시지로.
    _showCapToastForBinding();
  }

  void _showCapToast(String message) {
    if (_toastShowing) return;
    _toastShowing = true;
    AppToast.show(context, message);
    Future<void>.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) _toastShowing = false;
    });
  }

  void _removeFromSelection(AssetEntity asset) {
    setState(() => _selected.remove(asset));
  }

  /// 선택된 자산을 글로벌 업로드 큐에 enqueue 후 picker를 즉시 닫고 scene
  /// detail로 이동. 압축·전송은 [UploadQueueNotifier]가 background로 처리하고
  /// 진행 상황은 글로벌 [UploadProgressChip]에 표시됨.
  void _save() {
    final scene = widget.scene;
    if (scene == null) {
      // scene 없이 picker가 열린 legacy 경로 — 그냥 선택만 반환.
      Navigator.of(context).pop(_selected);
      return;
    }
    if (_selected.isEmpty) return;

    ref.read(uploadQueueProvider.notifier).enqueuePhotos(
          sceneId: scene.id,
          sceneTitle: scene.title,
          assets: List.of(_selected),
          momentDate: widget.momentDate,
        );

    Navigator.of(context).pop();
    if (widget.landOnSceneDetail) {
      final viewportWidth = MediaQuery.sizeOf(context).width;
      Navigator.of(context).push(
        SceneDetailScreen.fadeRoute(
          scene: scene,
          canisterSize: viewportWidth * 0.5,
        ),
      );
    }
  }

  void _previewPhoto(AssetEntity asset) {
    final initialIndex = _assets.indexOf(asset);
    if (initialIndex < 0) return;
    Navigator.of(context).push(
      _PhotoPreviewScreen.route(
        assets: _assets,
        initialIndex: initialIndex,
        getSelected: () => _dragPreviewSelected ?? _selected,
        getMaxSelection: () => _maxSelection,
        onToggle: (asset) {
          _toggleSelect(asset);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final l10n = AppLocalizations.of(context);
    final hasSelection = _selected.isNotEmpty;

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              SizedBox(height: padding.top + DetailAppBar.barHeight),

              // 선택된 사진 미리보기 — 드래그 종료 후 확정된 _selected 기준.
              // 드래그 중엔 _selected를 안 건드려서 layout shift 안 일어남.
              if (hasSelection)
                SizedBox(
                  height: 88,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _selected.length,
                    itemBuilder: (context, index) {
                      final previewAsset = _selected[index];
                      return _PreviewTile(
                        asset: previewAsset,
                        thumbFuture: _getThumb(previewAsset, 200),
                        onRemove: () => _removeFromSelection(previewAsset),
                      );
                    },
                  ),
                ),

              if (hasSelection)
                Container(
                  height: 0.5,
                  color: context.colors.foreground.withValues(alpha: 0.06),
                ),

              // 그리드 갤러리
              Expanded(
                child: _loading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: context.colors.foreground,
                          strokeWidth: 1.5,
                        ),
                      )
                    : _assets.isEmpty
                        ? Center(
                            child: Text(
                              l10n.photoPickerEmpty,
                              style: AppTypography.body(14).copyWith(
                                color: context.colors.foregroundMuted,
                              ),
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              // 셀 크기를 LayoutBuilder가 알려주는 폭으로 산출.
                              // 드래그 hit-test가 같은 값을 사용하도록 캐싱.
                              final innerWidth = constraints.maxWidth -
                                  _kGridPadding * 2;
                              final cellSide = (innerWidth -
                                      _kGridSpacing *
                                          (_kGridCols - 1)) /
                                  _kGridCols;
                              if (cellSide != _gridCellSide) {
                                WidgetsBinding.instance.addPostFrameCallback(
                                    (_) {
                                  if (mounted) {
                                    setState(() => _gridCellSide = cellSide);
                                  }
                                });
                              }
                              return RawGestureDetector(
                                behavior: HitTestBehavior.deferToChild,
                                // 마키는 long-press로만 시작 — 일반 vertical
                                // swipe는 그리드 자체 스크롤로 가게 두고, 길게
                                // 눌렀을 때만 selection drag 모드 진입.
                                // GestureDetector는 long-press 시간을 못
                                // 바꿔서 RawGestureDetector로 직접 구성.
                                gestures: {
                                  LongPressGestureRecognizer:
                                      GestureRecognizerFactoryWithHandlers<
                                          LongPressGestureRecognizer>(
                                    () => LongPressGestureRecognizer(
                                      duration: _kMarqueeLongPressDelay,
                                    ),
                                    (recognizer) {
                                      recognizer.onLongPressStart =
                                          _onMarqueeStart;
                                      recognizer.onLongPressMoveUpdate =
                                          _onMarqueeUpdate;
                                      recognizer.onLongPressEnd =
                                          (_) => _onMarqueeEnd();
                                      recognizer.onLongPressCancel =
                                          _onMarqueeEnd;
                                    },
                                  ),
                                },
                                child: GridView.builder(
                                  key: _gridKey,
                                  controller: _gridController,
                                  padding:
                                      const EdgeInsets.all(_kGridPadding),
                                  // long-press 인식 전엔 일반 스와이프가 그리
                                  // 드 스크롤로 가야 하므로 기본 physics. 마
                                  // 키가 시작되면 long-press가 arena를 잡아
                                  // 스크롤은 자동으로 멈추고, 가장자리 auto-
                                  // scroll은 controller.jumpTo로 처리.
                                  physics: const BouncingScrollPhysics(),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: _kGridCols,
                                    mainAxisSpacing: _kGridSpacing,
                                    crossAxisSpacing: _kGridSpacing,
                                  ),
                                  itemCount: _assets.length,
                                  itemBuilder: (context, index) {
                                    // 드래그 중엔 preview 기준으로 그리고,
                                    // 평소엔 확정된 _selected 기준.
                                    final display = _dragPreviewSelected ??
                                        _selected;
                                    final asset = _assets[index];
                                    final selIdx = display.indexOf(asset);
                                    final isSelected = selIdx >= 0;
                                    return _GalleryTile(
                                      asset: asset,
                                      selected: isSelected,
                                      selectionOrder:
                                          isSelected ? selIdx + 1 : 0,
                                      thumbFuture: _getThumb(asset, 300),
                                      onSelect: () => _toggleSelect(asset),
                                      onTap: () => _previewPhoto(asset),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),

          // 앱바
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: DetailAppBar(
              topInset: padding.top,
              title: l10n.photoPickerScreenTitle,
              titleOpacity: 1.0,
              useGradient: false,
              onClose: () => Navigator.of(context).pop(),
              // Save 라벨 옆에 '(n/limit)' 카운터 — 한 번에 올릴 수 있는
              // 한도(min(20, scene 잔여 슬롯))가 분모. 한 라인에 같이 붙여서
              // 읽힘새가 'Save (3/20)' 형태가 되도록 RichText로 합침.
              trailing: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: hasSelection ? _save : null,
                child: AnimatedOpacity(
                  opacity: hasSelection ? 1.0 : 0.4,
                  duration: const Duration(milliseconds: 200),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    child: RichText(
                      text: TextSpan(
                        style: AppTypography.body(15, weight: FontWeight.w600)
                            .copyWith(color: context.colors.foreground),
                        children: [
                          TextSpan(text: l10n.actionSave),
                          TextSpan(
                            text:
                                ' (${(_dragPreviewSelected ?? _selected).length}/$_maxSelection)',
                            style: AppTypography.body(
                              13,
                              weight: FontWeight.w500,
                            ).copyWith(
                              color: context.colors.foregroundMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 하단 앨범 선택 버튼
          Positioned(
            bottom: padding.bottom + 16,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _albums.length > 1 ? _showAlbumPicker : null,
                child: ClipRRect(
                  borderRadius: AppRadii.xlBorder,
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.clickableArea
                            .withValues(alpha: 0.82),
                        borderRadius: AppRadii.xlBorder,
                        border: Border.all(
                          color: context.colors.foreground
                              .withValues(alpha: 0.08),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentAlbum?.name ?? l10n.photoPickerAllPhotos,
                            style: AppTypography.body(14,
                                    weight: FontWeight.w500)
                                .copyWith(
                                    color: context.colors.foreground),
                          ),
                          if (_albums.length > 1) ...[
                            const SizedBox(width: 6),
                            FaIcon(
                              FontAwesomeIcons.chevronDown,
                              size: 10,
                              color: context.colors.foregroundMuted,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

        ],
      ),
    );
  }
}

// ── 그리드 타일 ──────────────────────────────────────────────

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({
    required this.asset,
    required this.selected,
    required this.selectionOrder,
    required this.thumbFuture,
    required this.onSelect,
    required this.onTap,
  });

  final AssetEntity asset;
  final bool selected;
  final int selectionOrder;
  final Future<Uint8List?> thumbFuture;
  final VoidCallback onSelect;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: thumbFuture,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        return Stack(
          fit: StackFit.expand,
          children: [
            // 사진 본체 — 짧은 탭은 미리보기. 드래그는 부모 GestureDetector
            // 가 처리(마키 셀렉트).
            GestureDetector(
              onTap: onTap,
              child: bytes != null
                  ? Image.memory(bytes, fit: BoxFit.cover)
                  : ColoredBox(color: context.colors.nonClickableArea),
            ),

            // 선택 오버레이
            if (selected)
              IgnorePointer(
                child: Container(
                  color: context.colors.foreground.withValues(alpha: 0.1),
                ),
              ),

            // 선택 버튼 — 단일 토글만. 드래그-셀렉트는 사진 본체가 담당.
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: onSelect,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? context.colors.foreground
                          : Colors.black.withValues(alpha: 0.3),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.8),
                        width: 1.5,
                      ),
                    ),
                    child: selected
                        ? Center(
                            child: Text(
                              '$selectionOrder',
                              style: AppTypography.body(11,
                                      weight: FontWeight.w700)
                                  .copyWith(
                                      color: context.colors.background),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── 미리보기 타일 ────────────────────────────────────────────

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({
    required this.asset,
    required this.thumbFuture,
    required this.onRemove,
  });

  final AssetEntity asset;
  final Future<Uint8List?> thumbFuture;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        width: 72,
        height: 72,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              bottom: 0,
              child: ClipRRect(
                borderRadius: AppRadii.smBorder,
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: FutureBuilder<Uint8List?>(
                    future: thumbFuture,
                    builder: (context, snapshot) {
                      if (snapshot.data != null) {
                        return Image.memory(snapshot.data!,
                            fit: BoxFit.cover);
                      }
                      return ColoredBox(
                          color: context.colors.nonClickableArea);
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: onRemove,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.colors.foreground,
                  ),
                  child: Center(
                    child: FaIcon(
                      FontAwesomeIcons.xmark,
                      size: 10,
                      color: context.colors.background,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 사진 미리보기(라이트박스) 화면 ──────────────────────────
//
// 풀스크린 PageView로 좌우 스와이프하며 사진을 넘길 수 있고, 하단의 블러 pill
// 바에 X(close) + Select 버튼을 둠. Select 버튼은 현재 페이지 사진의 선택
// 상태에 따라 라벨이 'Select'/'Deselect'로 바뀌며 우측에 '(n/limit)' 카운터를
// 함께 표시. Play 화면의 _BlurPill 패턴과 동일.

class _PhotoPreviewScreen extends StatefulWidget {
  const _PhotoPreviewScreen({
    required this.assets,
    required this.initialIndex,
    required this.getSelected,
    required this.getMaxSelection,
    required this.onToggle,
  });

  final List<AssetEntity> assets;
  final int initialIndex;
  final List<AssetEntity> Function() getSelected;
  final int Function() getMaxSelection;
  final void Function(AssetEntity) onToggle;

  static Route<void> route({
    required List<AssetEntity> assets,
    required int initialIndex,
    required List<AssetEntity> Function() getSelected,
    required int Function() getMaxSelection,
    required void Function(AssetEntity) onToggle,
  }) {
    return PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, _, _) => _PhotoPreviewScreen(
        assets: assets,
        initialIndex: initialIndex,
        getSelected: getSelected,
        getMaxSelection: getMaxSelection,
        onToggle: onToggle,
      ),
      transitionsBuilder: (_, anim, _, child) {
        return FadeTransition(opacity: anim, child: child);
      },
    );
  }

  @override
  State<_PhotoPreviewScreen> createState() => _PhotoPreviewScreenState();
}

class _PhotoPreviewScreenState extends State<_PhotoPreviewScreen> {
  late final PageController _controller;
  late int _currentIndex;
  // asset.id → 동일 Future 재사용. 매 setState(예: select toggle)마다 itemBuilder
  // 가 호출되며 새 Future를 만들면 FutureBuilder가 connectionState=waiting으로
  // 떨어져 이미지가 깜빡임. 캐싱으로 방지.
  // 풀해상도 프리뷰 Future 캐시 — 스와이프하며 본 에셋이 무한 누적되지
  // 않도록 LRU 상한. PageView는 현재 ±몇 페이지만 살아있어 16이면 충분.
  final LruCache<String, Future<Uint8List?>> _futureCache =
      LruCache(maxSize: 16);

  Future<Uint8List?> _futureFor(AssetEntity asset) {
    final cached = _futureCache.get(asset.id);
    if (cached != null) return cached;
    final future =
        asset.thumbnailDataWithSize(const ThumbnailSize(1600, 1600));
    _futureCache.put(asset.id, future);
    return future;
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleToggle() {
    final asset = widget.assets[_currentIndex];
    widget.onToggle(asset);
    // parent state가 갱신되어도 이 route는 별도 stack이라 자체 setState로
    // 다시 그려야 selection 상태 표시 갱신됨.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final selected = widget.getSelected();
    final maxSelection = widget.getMaxSelection();
    final currentAsset = widget.assets[_currentIndex];
    final isSelected = selected.contains(currentAsset);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.assets.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) {
              final asset = widget.assets[index];
              return Center(
                child: FutureBuilder<Uint8List?>(
                  future: _futureFor(asset),
                  builder: (context, snapshot) {
                    if (snapshot.data != null) {
                      return Image.memory(
                        snapshot.data!,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      );
                    }
                    return const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        color: Colors.white70,
                        strokeWidth: 1.5,
                      ),
                    );
                  },
                ),
              );
            },
          ),
          // 하단 액션 바 — Play 화면 패턴(좌 원형 X + 가운데 expanded pill +
          // 우 원형 액션) 그대로. 가운데 pill엔 카운터(n/limit) 텍스트만.
          Positioned(
            left: 0,
            right: 0,
            bottom: padding.bottom + 16,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  // 좌: 원형 grid (close → 그리드로 복귀)
                  _PreviewBlurPill(
                    onTap: () => Navigator.of(context).pop(),
                    isCircle: true,
                    child: const _GridDotsIcon(
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 가운데: 카운터 pill (앱바 Save 포맷과 동일 = n/limit)
                  Expanded(
                    child: _PreviewBlurPill(
                      child: Text(
                        '${selected.length}/$maxSelection',
                        style:
                            AppTypography.body(14, weight: FontWeight.w500)
                                .copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 우: 원형 select 토글 (미선택=dimmed, 선택=full)
                  _PreviewBlurPill(
                    onTap: _handleToggle,
                    isCircle: true,
                    child: AnimatedOpacity(
                      opacity: isSelected ? 1.0 : 0.35,
                      duration: const Duration(milliseconds: 150),
                      child: const FaIcon(
                        FontAwesomeIcons.check,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 미리보기 화면 전용 블러 pill — Play 화면의 _BlurPill과 동일 톤 (검정 배경
// + 강한 블러). 라이트박스 위에 떠있는 액션바라 톤이 어둡고 텍스트는 흰색.
class _PreviewBlurPill extends StatelessWidget {
  const _PreviewBlurPill({
    required this.child,
    this.onTap,
    this.isCircle = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool isCircle;

  static const double _height = 48;

  @override
  Widget build(BuildContext context) {
    final container = Container(
      width: isCircle ? _height : null,
      height: _height,
      color: Colors.black.withValues(alpha: 0.35),
      alignment: Alignment.center,
      child: child,
    );
    final clipped = isCircle
        ? ClipOval(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: container,
            ),
          )
        : ClipRRect(
            borderRadius: AppRadii.xlBorder,
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: container,
            ),
          );
    if (onTap == null) return clipped;
    return GestureDetector(onTap: onTap, child: clipped);
  }
}

/// 3×3 둥근 사각형 그리드 아이콘. iOS Photos의 thumbnail-grid 토글 느낌으로
/// FontAwesome 표준 아이콘과는 다른 chunky 스타일.
class _GridDotsIcon extends StatelessWidget {
  const _GridDotsIcon({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GridDotsPainter(color: color)),
    );
  }
}

class _GridDotsPainter extends CustomPainter {
  _GridDotsPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    // 3 cells + 2 gaps에서 cell 폭이 gap의 약 3배가 되도록.
    // gap = side * 1 / (3*3 + 2*1) = side / 11
    final gap = size.width / 11.0;
    final cell = (size.width - gap * 2) / 3.0;
    final radius = Radius.circular(cell * 0.25);
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        final left = c * (cell + gap);
        final top = r * (cell + gap);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left, top, cell, cell),
            radius,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridDotsPainter old) => old.color != color;
}

// ── 앨범 선택 리스트 ─────────────────────────────────────────

class _AlbumList extends StatelessWidget {
  const _AlbumList({
    required this.albums,
    required this.currentId,
    required this.onSelect,
  });

  final List<AssetPathEntity> albums;
  final String? currentId;
  final ValueChanged<AssetPathEntity> onSelect;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 360),
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0.0, 0.06, 0.94, 1.0],
        ).createShader(bounds),
        blendMode: BlendMode.dstIn,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          shrinkWrap: true,
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final album = albums[index];
            final isCurrent = album.id == currentId;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(album),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        album.name,
                        style:
                            AppTypography.body(15, weight: FontWeight.w500)
                                .copyWith(
                                    color: context.colors.foreground),
                      ),
                    ),
                    if (isCurrent)
                      FaIcon(
                        FontAwesomeIcons.check,
                        size: 14,
                        color: context.colors.foreground,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
