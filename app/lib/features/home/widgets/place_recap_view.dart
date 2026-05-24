import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/floating_bottom_sheet.dart';
import '../../../core/widgets/glass_circle_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../content/contents_view_model.dart';
import '../../content/models/content.dart';
import '../../content/models/reaction.dart';
import '../../content/reactions_view_model.dart';
import '../../content/widgets/reaction_picker_sheet.dart';
import '../../profile/profile_view_model.dart';
import '../models/scene.dart';
import 'content_viewer_v2.dart';
import 'detail_app_bar.dart';
import 'rewind_pill_button.dart';

/// Place 매체 recap — 풀스크린 Mapbox + 캐니스터 핀 + 좌우 버튼/스와이프로
/// fly-to. 상·하단은 그라데이션으로 chips/액션바 영역과 자연스럽게 섞임.
/// 사용자 인터랙션(pan/zoom/rotate/pitch)은 잠그고, fly-to만 카메라를 옮긴다.
class PlaceRecapView extends ConsumerStatefulWidget {
  const PlaceRecapView({
    super.key,
    required this.scenes,
    required this.filterActive,
  });

  final List<Scene> scenes;
  // 사용자가 scene 필터를 걸어둔 상태인지 — 빈 상태일 때 메시지 분기.
  final bool filterActive;

  @override
  ConsumerState<PlaceRecapView> createState() => _PlaceRecapViewState();
}

class _PlaceRecapViewState extends ConsumerState<PlaceRecapView> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointManager;
  // 핀 → 인덱스 매핑. fly-to 트리거 후 active 핀 강조에 사용.
  final List<PointAnnotation> _annotations = [];
  List<_PlaceItem>? _items;
  int _currentIndex = 0;
  int _loadToken = 0;
  // 카메라 center lat을 핀 lat보다 살짝 북쪽으로 offset해서 핀이 화면에서
  // 시각적으로 아래로 내려와 보이게. zoom 12에서 ~1px ≒ 0.000343°. 30px ≒
  // 0.0103. padding 옵션을 쓰면 flyTo 도중 들썩이므로 lat offset이 더 안정.
  static const double _camLatOffset = 0.0103;

  // 캐니스터 raw bytes 캐시 — url → 다운로드된 원본.
  final Map<String, Uint8List> _imageCache = {};
  // 렌더링된 핀 PNG 캐시 — sceneId+brightness 키. 테마 변경 시 invalidate.
  final Map<String, Uint8List> _pinPngCache = {};
  // 마지막으로 핀 동기화에 사용한 items 시그니처. 같은 set이면 재구성 X.
  String? _pinSignature;

  @override
  void initState() {
    super.initState();
    _loadContents();
  }

  @override
  void didUpdateWidget(covariant PlaceRecapView old) {
    super.didUpdateWidget(old);
    if (!_sameSceneIds(old.scenes, widget.scenes)) {
      _loadContents();
    }
  }

  bool _sameSceneIds(List<Scene> a, List<Scene> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  Future<void> _loadContents() async {
    final token = ++_loadToken;
    final items = <_PlaceItem>[];
    for (final scene in widget.scenes) {
      try {
        final contents = await ref.read(
          contentsForSceneProvider(scene.id).future,
        );
        if (token != _loadToken) return;
        // 리액션은 sticker 렌더에 필요 — 첫 _syncPins에서 valueOrNull이 null
        // 이면 sticker 없는 PNG가 캐시되어 영원히 안 보일 수 있다. 미리 한
        // 번 future로 강제 fetch해서 valueOrNull을 valid 상태로 만든다.
        try {
          await ref.read(reactionsForSceneProvider(scene.id).future);
        } catch (_) {}
        if (token != _loadToken) return;
        for (final c in contents) {
          if (c.type != 'place') continue;
          final lat = c.payload['lat'];
          final lng = c.payload['lng'];
          if (lat is! num || lng is! num) continue;
          items.add(
            _PlaceItem(
              content: c,
              scene: scene,
              lat: lat.toDouble(),
              lng: lng.toDouble(),
            ),
          );
        }
      } catch (_) {}
    }
    // 다른 매체와 동일하게 매체별 카테고리 안에서 랜덤 순서로 보이도록 셔플.
    items.shuffle();
    if (!mounted || token != _loadToken) return;
    setState(() {
      _items = items;
      _currentIndex = 0;
    });
    // 지도가 이미 만들어졌으면 핀 재구성.
    unawaited(_syncPins());
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    developer.log('onMapCreated', name: 'place_recap');
    _mapboxMap = map;
    // 테마 변경 등으로 MapWidget이 새 인스턴스로 만들어진 경우 이전 manager
    // /annotation 참조는 무효 — reset 후 _syncPins에서 다시 구성하게 한다.
    _pointManager = null;
    _annotations.clear();
    _pinSignature = null;
    // 테마 색에 맞춘 PNG라 brightness가 바뀌면 무효. 항상 새로 그림.
    _pinPngCache.clear();
    // 인터랙션 전면 잠금 — 사용자는 fly-to로만 카메라 이동.
    await map.gestures.updateSettings(
      GesturesSettings(
        rotateEnabled: false,
        pinchToZoomEnabled: false,
        scrollEnabled: false,
        simultaneousRotateAndPinchToZoomEnabled: false,
        pitchEnabled: false,
        doubleTapToZoomInEnabled: false,
        doubleTouchToZoomOutEnabled: false,
        quickZoomEnabled: false,
        pinchPanEnabled: false,
        focalPoint: null,
      ),
    );
    // Mapbox 로고/저작권은 시각상 거슬리는 위치로 가지 않도록 코너만 살짝.
    await map.attribution.updateSettings(
      AttributionSettings(
        position: OrnamentPosition.BOTTOM_LEFT,
        marginLeft: 8,
        marginBottom: 8,
        iconColor: Colors.white54.toARGB32(),
      ),
    );
    await map.logo.updateSettings(
      LogoSettings(
        position: OrnamentPosition.BOTTOM_LEFT,
        marginLeft: 8,
        marginBottom: 8,
      ),
    );
    await map.compass.updateSettings(CompassSettings(enabled: false));
    await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    // 다른 매체로 갔다가 돌아오면 Mapbox SDK가 cached style을 쓰면서
    // onStyleLoadedListener가 발화하지 않는 케이스가 있다. _syncPins를 여러
    // 경로에서 fallback으로 호출 — _pinSignature 체크로 실제 작업은 한 번만
    // 일어남.
    await _syncPins();
    // style이 아직 ready 아닐 가능성을 한 번 더 보정.
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _syncPins();
    });
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    developer.log('onStyleLoaded', name: 'place_recap');
    await _syncPins();
  }

  Future<void> _syncPins() async {
    final map = _mapboxMap;
    final items = _items;
    developer.log(
      '_syncPins enter map=${map != null} items=${items?.length}',
      name: 'place_recap',
    );
    if (map == null || items == null || items.isEmpty) {
      developer.log('_syncPins early-return', name: 'place_recap');
      return;
    }
    // Theme.of은 await 이전에 캡처 — 이후 build context 사용 lint 차단.
    final brightness = Theme.of(context).brightness;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final sig = items.map((i) => i.content.id).join('|');
    if (sig == _pinSignature) {
      // 같은 set — 강조만 갱신하고 종료.
      _flyToIndex(_currentIndex);
      return;
    }
    _pinSignature = sig;
    if (_pointManager == null) {
      _pointManager = await map.annotations.createPointAnnotationManager();
      developer.log(
        'pointManager created=${_pointManager != null}',
        name: 'place_recap',
      );
      // 기본값에선 핀이 서로 겹치거나 라벨과 겹치면 placement 알고리즘이
      // 일부를 숨긴다. 작은 카드 안에서 핀이 다 보여야 하므로 overlap +
      // ignorePlacement를 켠다.
      await _pointManager!.setIconAllowOverlap(true);
      await _pointManager!.setIconIgnorePlacement(true);
    }
    final manager = _pointManager;
    if (manager == null) return;
    await manager.deleteAll();
    _annotations.clear();
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final cacheKey = item.scene.id;
      Uint8List? bytes = _pinPngCache[cacheKey];
      if (bytes == null) {
        Uint8List? coverRaw;
        if (item.scene.coverImageUrl.isNotEmpty) {
          coverRaw = await _loadCanisterRaw(item.scene.coverImageUrl);
        }
        bytes = await _renderPinLabel(
          coverBytes: coverRaw,
          sceneTitle: item.scene.title,
          sceneNumber: item.scene.number,
          brightness: brightness,
          devicePixelRatio: dpr,
        );
        if (bytes != null) _pinPngCache[cacheKey] = bytes;
      }
      developer.log('pin[$i] bytes=${bytes?.length}', name: 'place_recap');
      if (bytes == null) continue;
      final ann = await manager.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(item.lng, item.lat)),
          image: bytes,
          // tip 삼각형이 정확히 lat/lng를 가리키도록 BOTTOM 앵커.
          iconAnchor: IconAnchor.BOTTOM,
          // PNG가 dpr 배 픽셀로 그려졌으므로 iconSize는 그만큼 작게 보정
          // 해서 시각 logical 크기를 유지. pill 형태는 가로로 길어서
          // 세로 캐니스터 핀보다 multiplier를 낮춰 화면 폭을 안 잡아먹게.
          iconSize: (i == _currentIndex ? 2.0 : 1.8) / dpr,
        ),
      );
      _annotations.add(ann);
    }
    _flyToIndex(_currentIndex);
  }

  Future<Uint8List?> _loadCanisterRaw(String? url) async {
    if (url == null || url.isEmpty) return null;
    final cached = _imageCache[url];
    if (cached != null) return cached;
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) return null;
      _imageCache[url] = res.bodyBytes;
      return res.bodyBytes;
    } catch (_) {}
    return null;
  }

  /// horizontal pill 핀 PNG 렌더링. 좌측에 원형 cover 이미지, 그 우측 두 줄
  /// (위: #N caption / 아래: scene title). 아래에 작은 삼각형 tip이 좌표를
  /// 가리킨다. iconAnchor: BOTTOM과 함께 사용.
  Future<Uint8List?> _renderPinLabel({
    required Uint8List? coverBytes,
    required String sceneTitle,
    required int sceneNumber,
    required Brightness brightness,
    required double devicePixelRatio,
  }) async {
    // 색상 톤.
    final isDark = brightness == Brightness.dark;
    final bodyFill = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111113);
    final captionColor = isDark
        ? const Color(0xFFB5B5B7)
        : const Color(0xFF55555A);
    final fallbackBg = isDark
        ? const Color(0xFF2A2A2C)
        : const Color(0xFFD9D9DC);

    // 사이즈 — 좌측 원형 cover, 우측 두 줄 텍스트 (#N + title).
    const shadowPad = 14.0; // 외곽 그림자용 여백
    const bodyPadL = 8.0; // 좌측 — 원형 cover가 rounded end에 밀착
    const bodyPadR = 20.0; // 우측 — 텍스트가 rounded end 안쪽에서 떨어지도록
    const bodyPadV = 8.0; // 상하 padding
    const coverSize = 64.0;
    const coverToText = 12.0; // cover ↔ text 사이 gap
    const lineGap = 3.0; // caption ↔ title
    const captionSize = 13.0;
    const titleSize = 17.0;
    const tipHeight = 14.0;
    const tipWidth = 20.0;
    const maxTextWidth = 200.0;

    // text painter — 각 줄의 실제 폭으로 pill 전체 너비를 결정한다.
    final captionTp = TextPainter(
      text: TextSpan(
        text: '#$sceneNumber',
        style: TextStyle(
          color: captionColor,
          fontSize: captionSize,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          height: 1.0,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxTextWidth);
    final titleTp = TextPainter(
      text: TextSpan(
        text: sceneTitle,
        style: TextStyle(
          color: textColor,
          fontSize: titleSize,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxTextWidth);

    // body 영역 — height는 cover 기준 고정, width는 텍스트 길이에 맞춰 유동.
    final textBlockW = captionTp.width > titleTp.width
        ? captionTp.width
        : titleTp.width;
    final bodyW = bodyPadL + coverSize + coverToText + textBlockW + bodyPadR;
    final bodyH = coverSize + bodyPadV * 2;
    final bodyRadius = bodyH / 2; // 양 끝이 fully rounded — pill.
    final canvasW = bodyW + shadowPad * 2;
    final canvasH = bodyH + tipHeight + shadowPad * 2;

    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      // device pixel ratio만큼 scale 적용 — PNG가 retina에 맞는 픽셀 밀도로
      // 그려져 mapbox가 SDK상 1x로 표시해도 화면에서 흐릿하지 않다.
      canvas.scale(devicePixelRatio);
      final bodyRect = Rect.fromLTWH(shadowPad, shadowPad, bodyW, bodyH);
      final bodyRRect = RRect.fromRectAndRadius(
        bodyRect,
        Radius.circular(bodyRadius),
      );

      // 1) drop shadow — body + tip 합쳐서.
      final shadowPath = Path()
        ..addRRect(bodyRRect)
        ..moveTo(bodyRect.center.dx - tipWidth / 2, bodyRect.bottom - 1)
        ..lineTo(bodyRect.center.dx + tipWidth / 2, bodyRect.bottom - 1)
        ..lineTo(bodyRect.center.dx, bodyRect.bottom + tipHeight)
        ..close();
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawPath(shadowPath.shift(const Offset(0, 3)), shadowPaint);

      // 2) body + 아래 tip 삼각형.
      final fillPaint = Paint()..color = bodyFill;
      canvas.drawRRect(bodyRRect, fillPaint);
      final tipPath = Path()
        ..moveTo(bodyRect.center.dx - tipWidth / 2, bodyRect.bottom - 0.5)
        ..lineTo(bodyRect.center.dx + tipWidth / 2, bodyRect.bottom - 0.5)
        ..lineTo(bodyRect.center.dx, bodyRect.bottom + tipHeight)
        ..close();
      canvas.drawPath(tipPath, fillPaint);

      // 3) 좌측 원형 cover — pill의 rounded end 안에 밀착. cover 있으면 center
      // crop, 없으면 회색 disc + 이니셜.
      final coverRect = Rect.fromLTWH(
        bodyRect.left + bodyPadL,
        bodyRect.top + bodyPadV,
        coverSize,
        coverSize,
      );
      final coverPath = Path()..addOval(coverRect);
      if (coverBytes != null) {
        try {
          final codec = await ui.instantiateImageCodec(coverBytes);
          final frame = await codec.getNextFrame();
          final src = frame.image;
          final srcW = src.width.toDouble();
          final srcH = src.height.toDouble();
          final cropSize = srcW < srcH ? srcW : srcH;
          final srcRect = Rect.fromLTWH(
            (srcW - cropSize) / 2,
            (srcH - cropSize) / 2,
            cropSize,
            cropSize,
          );
          canvas.save();
          canvas.clipPath(coverPath);
          canvas.drawImageRect(src, srcRect, coverRect, Paint());
          canvas.restore();
          src.dispose();
        } catch (_) {
          canvas.drawPath(coverPath, Paint()..color = fallbackBg);
        }
      } else {
        canvas.drawPath(coverPath, Paint()..color = fallbackBg);
        final initial = sceneTitle.trim().isEmpty
            ? ''
            : String.fromCharCodes(
                sceneTitle.trim().runes.take(1),
              ).toUpperCase();
        if (initial.isNotEmpty) {
          // 디스플레이 폰트 — SceneTitleFallback과 동일 톤. AppTypography.
          // display(text:)가 한/영에 맞춰 Hahmlet/PlayfairDisplay 자동 선택.
          final initTp = TextPainter(
            text: TextSpan(
              text: initial,
              style: AppTypography.display(28, text: initial).copyWith(
                color: textColor,
                fontWeight: FontWeight.w500,
                height: 1.0,
              ),
            ),
            textDirection: ui.TextDirection.ltr,
          )..layout();
          initTp.paint(
            canvas,
            Offset(
              coverRect.center.dx - initTp.width / 2,
              coverRect.center.dy - initTp.height / 2,
            ),
          );
        }
      }

      // 4) 우측 텍스트 두 줄 — cover 우측, 세로 가운데 정렬, 좌측 정렬.
      final textBlockH = captionTp.height + lineGap + titleTp.height;
      final textLeft = coverRect.right + coverToText;
      final textTop = bodyRect.center.dy - textBlockH / 2;
      captionTp.paint(canvas, Offset(textLeft, textTop));
      titleTp.paint(
        canvas,
        Offset(textLeft, textTop + captionTp.height + lineGap),
      );

      // 파트너 reaction은 메타 strip(_PlaceMetaStrip)에 통합 표시 — 핀
      // PNG에는 더 이상 그리지 않는다.

      final picture = recorder.endRecording();
      final image = await picture.toImage(
        (canvasW * devicePixelRatio).ceil(),
        (canvasH * devicePixelRatio).ceil(),
      );
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      captionTp.dispose();
      titleTp.dispose();
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _flyToIndex(int index) async {
    final map = _mapboxMap;
    final items = _items;
    developer.log(
      '_flyToIndex index=$index map=${map != null} items=${items?.length}',
      name: 'place_recap',
    );
    if (map == null ||
        items == null ||
        items.isEmpty ||
        index < 0 ||
        index >= items.length) {
      return;
    }
    final item = items[index];
    developer.log(
      'flyTo start lat=${item.lat} lng=${item.lng}',
      name: 'place_recap',
    );
    unawaited(
      map
          .flyTo(
            CameraOptions(
              center: Point(
                coordinates: Position(item.lng, item.lat + _camLatOffset),
              ),
              zoom: 12,
              pitch: 0,
              bearing: 0,
            ),
            MapAnimationOptions(duration: 1400, startDelay: 0),
          )
          .then((_) {
            developer.log('flyTo done', name: 'place_recap');
          })
          .catchError((Object e) {
            developer.log('flyTo error: $e', name: 'place_recap');
          }),
    );
    // 핀 크기 재적용 — current 핀만 크게. 카메라 이동과 병렬로 진행.
    // (PNG가 dpr 배라 iconSize도 dpr로 나눠 보정.)
    final dpr = MediaQuery.devicePixelRatioOf(context);
    for (var i = 0; i < _annotations.length && i < items.length; i++) {
      final ann = _annotations[i];
      ann.iconSize = (i == index ? 2.0 : 1.8) / dpr;
      await _pointManager?.update(ann);
    }
  }

  void _advance(int delta) {
    final items = _items;
    if (items == null || items.length < 2) return;
    // wrap-around 안 함 — recap의 다른 매체와 동일하게 양 끝에서 정지.
    final next = (_currentIndex + delta).clamp(0, items.length - 1);
    if (next == _currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = next);
    unawaited(_flyToIndex(next));
  }

  _PlaceItem? get _currentItem {
    final items = _items;
    if (items == null || items.isEmpty) return null;
    return items[_currentIndex.clamp(0, items.length - 1)];
  }

  void _openContentDetail() {
    final item = _currentItem;
    if (item == null) return;
    final contents = ref
        .read(contentsForSceneProvider(item.scene.id))
        .valueOrNull;
    if (contents == null || contents.isEmpty) return;
    final idx = contents.indexWhere((c) => c.id == item.content.id);
    if (idx < 0) return;
    HapticFeedback.selectionClick();
    ContentViewerV2.show(
      context: context,
      contents: contents,
      initialIndex: idx,
      sceneImageUrl: item.scene.coverImageUrl,
      sceneName: item.scene.title,
    );
  }

  Future<void> _openReactionPicker() async {
    final item = _currentItem;
    if (item == null) return;
    HapticFeedback.selectionClick();
    final myId = ref.read(myProfileProvider).valueOrNull?.id;
    if (myId == null) return;
    final sceneId = item.scene.id;
    final contentId = item.content.id;
    final reactions =
        ref.read(reactionsForSceneProvider(sceneId)).valueOrNull?[contentId] ??
        const <Reaction>[];
    Reaction? mine;
    for (final r in reactions) {
      if (r.userId == myId) {
        mine = r;
        break;
      }
    }
    if (!mounted) return;
    await FloatingBottomSheet.show<void>(
      context: context,
      builder: (_) => ReactionPickerSheet(
        initialEmoji: mine?.emoji,
        initialComment: mine?.comment,
        onSubmit: (emoji, comment) async {
          try {
            await ref
                .read(reactionsForSceneProvider(sceneId).notifier)
                .setMyReaction(
                  userId: myId,
                  contentId: contentId,
                  emoji: emoji,
                  comment: comment,
                );
          } catch (_) {
            if (mounted) {
              AppToast.show(
                context,
                AppLocalizations.of(context).reactionSaveFailed,
              );
            }
          }
        },
        onRemove: () async {
          try {
            await ref
                .read(reactionsForSceneProvider(sceneId).notifier)
                .removeMyReaction(userId: myId, contentId: contentId);
          } catch (_) {
            if (mounted) {
              AppToast.show(
                context,
                AppLocalizations.of(context).reactionRemoveFailed,
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items == null) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ),
      );
    }
    if (items.isEmpty) {
      final l10n = AppLocalizations.of(context);
      final msg = widget.filterActive
          ? l10n.recapFilteredEmptyPlaces
          : l10n.recapEmptyPlaces;
      // PlaceRecapView는 풀스크린(Positioned.fill)이라 그냥 Center를 쓰면
      // 화면 정중앙에 메시지가 놓여 다른 매체(_RecapSwiper, chips 아래
      // Expanded 안의 Center)와 위치가 어긋난다. 상단 inset을 다른 매체와
      // 동일하게 맞춰 메시지의 vertical center가 일치하도록.
      // chip 실제 높이 = padding(10×2) + icon(14) + gap(5) + label(11) ≒ 53.
      final topInset =
          MediaQuery.paddingOf(context).top +
          DetailAppBar.barHeight +
          10 // chips row 위 spacing (RecapScreen build)
          +
          53 // _MediaToggleChip 실제 높이
          +
          16; // chips 아래 spacing (RecapScreen build)
      return Padding(
        padding: EdgeInsets.only(top: topInset),
        child: Center(
          child: Text(
            msg,
            style: AppTypography.body(
              13,
            ).copyWith(color: context.colors.foregroundMuted),
          ),
        ),
      );
    }
    final initial = items[0];
    final screenWidth = MediaQuery.sizeOf(context).width;
    final buttonSize = screenWidth >= 420 ? 54.0 : 48.0;
    final iconSize = buttonSize * 0.36;
    final iconColor = context.colors.foreground.withValues(alpha: 0.9);
    final bg = context.colors.background;

    return Stack(
      children: [
        // 풀스크린 지도 — 테마(다크/라이트)에 맞춰 2D Mapbox 스타일 토글. key
        // 에 brightness를 박아두면 사용자가 시스템 모드를 바꿀 때 widget이
        // 새 인스턴스로 재생성되어 핀도 onMapCreated에서 다시 동기화된다.
        //
        // 초기 카메라는 첫 핀 좌표(item[0])에서 핀 시청 zoom으로 시작 —
        // globe → fly-to 전환이 너무 급작스럽다는 피드백 반영. 다음 핀
        // 으로 이동할 때만 fly-to.
        Positioned.fill(
          child: MapWidget(
            key: ValueKey(
              'place_recap_mapbox_${Theme.of(context).brightness.name}',
            ),
            cameraOptions: CameraOptions(
              center: Point(
                coordinates: Position(initial.lng, initial.lat + _camLatOffset),
              ),
              zoom: 12,
              pitch: 0,
              bearing: 0,
            ),
            styleUri: Theme.of(context).brightness == Brightness.dark
                ? MapboxStyles.DARK
                : MapboxStyles.LIGHT,
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: _onStyleLoaded,
          ),
        ),
        // 좌우 스와이프 hit area — 지도 전면 위에 투명 GestureDetector. tap은
        // 핀 콘텐츠 detail로, swipe는 _advance로.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _openContentDetail,
            onHorizontalDragEnd: (details) {
              final v = details.primaryVelocity ?? 0;
              if (v < -200) {
                _advance(1);
              } else if (v > 200) {
                _advance(-1);
              }
            },
          ),
        ),
        // 하단 그라데이션 + 메타 + 액션바.
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: false,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    bg.withValues(alpha: 0.0),
                    bg.withValues(alpha: 0.85),
                    bg,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
              padding: EdgeInsets.only(
                top: 80,
                left: 20,
                right: 20,
                bottom: MediaQuery.paddingOf(context).bottom + 18,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 하단 액션 바 — [이전] [pill] [다음]. pill에 캐니스터 +
                  // scene title + 날짜 + 파트너/내 reaction 모두 통합.
                  // 첫/마지막 페이지에서는 해당 방향 버튼을 같은 크기 빈 슬롯
                  // 으로 대체해 pill 위치가 흔들리지 않도록.
                  if (_currentItem != null)
                    Builder(builder: (_) {
                      final total = _items?.length ?? 0;
                      return Row(
                        children: [
                          if (_currentIndex > 0)
                            GlassCircleButton(
                              size: buttonSize,
                              onTap: () => _advance(-1),
                              semanticLabel:
                                  AppLocalizations.of(context).recapNavPreviousPlace,
                              child: FaIcon(
                                FontAwesomeIcons.backwardStep,
                                size: iconSize,
                                color: iconColor,
                              ),
                            )
                          else
                            SizedBox(width: buttonSize, height: buttonSize),
                          const SizedBox(width: 10),
                          Expanded(
                            child: RewindPillButton(
                              content: _currentItem!.content,
                              scene: _currentItem!.scene,
                              height: buttonSize,
                              onTapInfo: _openContentDetail,
                              onTapMyReaction: _openReactionPicker,
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (_currentIndex < total - 1)
                            GlassCircleButton(
                              size: buttonSize,
                              onTap: () => _advance(1),
                              semanticLabel:
                                  AppLocalizations.of(context).recapNavNextPlace,
                              child: FaIcon(
                                FontAwesomeIcons.forwardStep,
                                size: iconSize,
                                color: iconColor,
                              ),
                            )
                          else
                            SizedBox(width: buttonSize, height: buttonSize),
                        ],
                      );
                    }),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlaceItem {
  const _PlaceItem({
    required this.content,
    required this.scene,
    required this.lat,
    required this.lng,
  });
  final Content content;
  final Scene scene;
  final double lat;
  final double lng;
}

/// 다른 매체의 _PhotoInfoStrip과 톤 통일한 메타 strip. 가운데 정렬 column —
