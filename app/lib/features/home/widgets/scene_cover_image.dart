import 'package:flutter/material.dart';

import '../models/scene.dart';
import 'scene_title_fallback.dart';

/// Scene 커버 이미지 — URL이 없거나 로드 실패 시 타이틀 첫 글자 fallback.
///
/// 헤더 아바타·scene picker row 등 커버를 보여주는 모든 곳이 공유한다.
class SceneCoverImage extends StatelessWidget {
  const SceneCoverImage({super.key, required this.scene});

  final Scene scene;

  @override
  Widget build(BuildContext context) {
    final url = scene.coverImageUrl;
    final fallback = SceneTitleFallback(title: scene.title);
    if (url.isEmpty) return fallback;
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
