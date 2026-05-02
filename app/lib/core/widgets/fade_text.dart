import 'package:flutter/material.dart';

/// 텍스트가 너비를 초과하면 우측 끝에서 fade-out되는 Text 위젯.
class FadeText extends StatelessWidget {
  const FadeText(
    this.text, {
    super.key,
    required this.style,
    this.maxLines = 1,
  });

  final String text;
  final TextStyle style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [Colors.white, Colors.white, Colors.transparent],
          stops: [0.0, 0.85, 1.0],
        ).createShader(bounds),
        blendMode: BlendMode.dstIn,
        child: Text(
          text,
          maxLines: maxLines,
          softWrap: false,
          overflow: TextOverflow.clip,
          style: style,
        ),
      ),
    );
  }
}
