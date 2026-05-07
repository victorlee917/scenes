import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_typography.dart';

/// 공유 영상 frame의 logical 사이즈. 시트 미리보기와 off-screen 렌더러가
/// 동일 비율을 쓰도록 한 곳에서 관리. 9:16 비율 유지.
const double kShareFrameLogicalWidth = 220;
const double kShareFrameLogicalHeight = 391;

/// 실제 영상 output 가로 픽셀. 1080×1920 유지를 위해 렌더러는
/// pixelRatio = kShareFrameOutputWidth / kShareFrameLogicalWidth 로 캡처.
const double kShareFrameOutputWidth = 1080;

/// 공유 영상 frame의 데이터 모델. `url`은 시트 미리보기에서 NetworkImage로
/// 사용(클라 이미지 캐시 hit 가능), `renderUrl`은 off-screen 렌더러가 HTTP로
/// 다운로드해 frame을 굽는 데 사용. photo의 경우 thumb URL을 renderUrl로
/// 넘겨 storage egress를 60배 감소시킴.

/// 공유 영상의 한 frame을 구성하는 데이터.
///
/// `url` 은 NetworkImage 미리보기 시 사용하고, off-screen 렌더 단계에서는 미리
/// 다운로드한 bytes로 MemoryImage를 만들어 [ShareFrameView.image]에 주입한다.
class ShareFrame {
  const ShareFrame({
    required this.url,
    required String? renderUrl,
    required this.sceneName,
    required this.occurredAt,
    required this.mediaType,
  }) : renderUrl = renderUrl ?? url;

  /// 시트 미리보기에 NetworkImage로 사용. 클라 image cache hit이 가능해 추가
  /// egress 거의 없음. 보통 full-size signed URL.
  final String url;

  /// off-screen 렌더러가 frame을 굽기 위해 HTTP로 받아오는 URL. photo는 thumb
  /// signed URL(600px), 그 외 매체(film/music/place)는 이미 작은 cached 이미지
  /// 라 url과 동일하게 둠. null 입력 시 url로 fallback.
  final String renderUrl;

  final String sceneName;
  final DateTime occurredAt;

  /// 'photo' | 'film' | 'music' | 'place'.
  final String mediaType;
}

/// 공유 영상의 한 frame을 그리는 위젯.
///
/// 같은 위젯 트리를 두 곳에서 재사용:
/// - 공유 시트 안의 미리보기(180×320, NetworkImage)
/// - 영상 렌더러가 off-screen에서 캡처(180×320 + pixelRatio 6.0 → 1080×1920,
///   MemoryImage)
///
/// 부모가 SizedBox 등으로 사이즈를 정하는 것을 전제 — 이 위젯 자체는 부모를
/// 가득 채운다(StackFit.expand). 9:16 기준 디자인이라 부모도 그 비율로 줘야 함.
///
/// [colorFilter]는 사진 필터(`PhotoFilter`)를 그대로 적용 — 미디어 레이어 전체
/// (bg/blur backdrop/dim/card)에 한 번에 걸려 톤이 통일됨. 텍스트와 그라데이션
/// 오버레이는 필터 영향을 안 받게 바깥 Stack에 둠.
class ShareFrameView extends StatelessWidget {
  const ShareFrameView({
    super.key,
    required this.frame,
    required this.image,
    required this.colorFilter,
  });

  final ShareFrame frame;
  final ImageProvider image;
  final ColorFilter? colorFilter;

  String _typeLabel(String type) {
    switch (type) {
      case 'photo':
        return 'Photo';
      case 'film':
        return 'Film';
      case 'music':
        return 'Music';
      case 'place':
        return 'Place';
      default:
        return type;
    }
  }

  Widget _wrapFilter(Widget child) =>
      colorFilter == null ? child : ColorFiltered(colorFilter: colorFilter!, child: child);

  Widget _baseImage({required BoxFit fit, FilterQuality? quality}) {
    return Image(
      image: image,
      fit: fit,
      // gaplessPlayback: cycle/렌더 시 새 프레임 도착 전까지 이전 프레임 유지 →
      // 한 박자 검정 깜빡임 방지.
      gaplessPlayback: true,
      filterQuality: quality ?? FilterQuality.medium,
      errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF1C1C1E)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaLayer = Stack(
      fit: StackFit.expand,
      children: [
        // 베이스 bg — 로딩/빈 상태 가림용.
        const ColoredBox(color: Color(0xFF1C1C1E)),
        if (frame.mediaType == 'photo')
          _baseImage(fit: BoxFit.cover)
        else ...[
          // 매체별 대표 이미지를 강하게 blur한 배경 — 카드 주변 빈 영역을
          // 이미지의 대표 색감으로 채워줌.
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: _baseImage(
                fit: BoxFit.cover,
                quality: FilterQuality.low,
              ),
            ),
          ),
          // 가벼운 다크 dim — 카드와 backdrop 대비 보강.
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.25),
            ),
          ),
          // 카드는 텍스트 영역 위쪽 공간에서 중앙 정렬. 하단 padding 60은
          // 텍스트 영역만큼 비워놓아 그 위 영역의 가운데에 카드가 오게.
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 60),
            child: Center(
              child: AspectRatio(
                aspectRatio: frame.mediaType == 'film' ? 2 / 3 : 1.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _baseImage(fit: BoxFit.cover),
                ),
              ),
            ),
          ),
        ],
      ],
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // 미디어 레이어에만 필터 적용 — 그라데이션/텍스트는 영향 X.
        _wrapFilter(mediaLayer),

        // 하단 검정 그라데이션 — 약 40% 높이를 덮어 텍스트 가독성만 확보하고
        // 위쪽 콘텐츠는 살림.
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 130,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00000000),
                    Color(0xCC000000),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                frame.sceneName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTypography.display(11, text: frame.sceneName)
                    .copyWith(color: Colors.white),
              ),
              const SizedBox(height: 5),
              Text(
                '${DateFormat.yMMMd('en').format(frame.occurredAt)} · '
                '${_typeLabel(frame.mediaType)}',
                textAlign: TextAlign.center,
                style: AppTypography.body(7).copyWith(
                  color: Colors.white.withValues(alpha: 0.4),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
