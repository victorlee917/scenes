import 'package:flutter/material.dart';

/// 외부 매체 출처 배지의 공통 셸. 흰색·light 로고가 어떤 콘텐츠 색상 위에서도
/// dim되지 않게 항상 dark backdrop circle을 깐다. scene detail 그리드, content
/// viewer 메타 모드 등 여러 화면에서 재사용.
class SourceBadge extends StatelessWidget {
  const SourceBadge({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// Spotify 출처 배지. assets/logo/spotify.png — 공식 로고 자산.
class SpotifyBadge extends StatelessWidget {
  const SpotifyBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const SourceBadge(
      child: Padding(
        padding: EdgeInsets.all(2),
        child: Image(
          image: AssetImage('assets/logo/spotify.png'),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

/// TMDB 출처 배지. assets/logo/tmdb.png — 공식 로고 자산.
class TmdbBadge extends StatelessWidget {
  const TmdbBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const SourceBadge(
      child: Padding(
        padding: EdgeInsets.all(2),
        child: Image(
          image: AssetImage('assets/logo/tmdb.png'),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

/// MapBox 출처 배지. 배지의 backdrop circle이 테마와 무관하게 항상 dark이라
/// (밝은 콘텐츠 위에서 가독성 확보용) 양 테마에서 동일하게 light-colored
/// 로고인 `mapbox_dark.png`(다크 모드 variant)를 사용.
class MapboxBadge extends StatelessWidget {
  const MapboxBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const SourceBadge(
      child: Padding(
        padding: EdgeInsets.all(2),
        child: Image(
          image: AssetImage('assets/logo/mapbox_dark.png'),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
