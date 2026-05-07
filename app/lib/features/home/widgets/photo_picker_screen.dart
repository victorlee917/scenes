import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/floating_bottom_sheet.dart';
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
  static const int _kDefaultMaxSelection = 20;

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
  final Map<String, Uint8List> _thumbCache = {};
  bool _loading = true;

  Future<Uint8List?> _getThumb(AssetEntity asset, int size) async {
    final key = '${asset.id}_$size';
    if (_thumbCache.containsKey(key)) return _thumbCache[key];
    final data = await asset.thumbnailDataWithSize(ThumbnailSize(size, size));
    if (data != null) _thumbCache[key] = data;
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
    final assets = await album.getAssetListRange(start: 0, end: 200);
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
    setState(() {
      if (_selected.contains(asset)) {
        _selected.remove(asset);
      } else if (_selected.length < _maxSelection) {
        _selected.add(asset);
      }
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
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => _PhotoPreviewDialog(asset: asset),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final hasSelection = _selected.isNotEmpty;

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              SizedBox(height: padding.top + DetailAppBar.barHeight),

              // 선택된 사진 미리보기
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
                              'No photos found',
                              style: AppTypography.body(14).copyWith(
                                color: context.colors.foregroundMuted,
                              ),
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(2),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 2,
                              crossAxisSpacing: 2,
                            ),
                            itemCount: _assets.length,
                            itemBuilder: (context, index) {
                              final asset = _assets[index];
                              final selIdx = _selected.indexOf(asset);
                              final isSelected = selIdx >= 0;
                              return _GalleryTile(
                                asset: asset,
                                selected: isSelected,
                                selectionOrder: isSelected ? selIdx + 1 : 0,
                                thumbFuture: _getThumb(asset, 300),
                                onSelect: () => _toggleSelect(asset),
                                onTap: () => _previewPhoto(asset),
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
              title: 'Add Photos',
              titleOpacity: 1.0,
              useGradient: false,
              onClose: () => Navigator.of(context).pop(),
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
                    child: Text(
                      'Save',
                      style: AppTypography.body(15, weight: FontWeight.w600)
                          .copyWith(color: context.colors.foreground),
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
                            _currentAlbum?.name ?? 'All Photos',
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

            // 선택 버튼
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

// ── 사진 미리보기 다이얼로그 ─────────────────────────────────

class _PhotoPreviewDialog extends StatelessWidget {
  const _PhotoPreviewDialog({required this.asset});

  final AssetEntity asset;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        color: Colors.transparent,
        child: Center(
          child: FutureBuilder<Uint8List?>(
            future:
                asset.thumbnailDataWithSize(const ThumbnailSize(800, 800)),
            builder: (context, snapshot) {
              if (snapshot.data != null) {
                return Image.memory(snapshot.data!, fit: BoxFit.contain);
              }
              return CircularProgressIndicator(
                color: context.colors.foreground,
                strokeWidth: 1.5,
              );
            },
          ),
        ),
      ),
    );
  }
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
