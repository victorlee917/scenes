import 'dart:async';

import 'package:flutter/material.dart';

import 'device_tilt_controller.dart';

/// 자식 위젯에 **3D 틸트 효과**를 입힌다.
///
/// 두 가지 소스를 합성:
/// 1. [deviceTilt] — 기기 가속도계 기반 글로벌 기울기 (모든 TiltContainer가
///    동일 값 구독, 느린 smoothing).
/// 2. 내부 터치 상태 — 사용자가 이 위젯을 누른 위치 기반. 누른 지점을 기준
///    으로 카드가 그쪽으로 "눌리는" 것처럼 회전하고, 손을 떼면 0으로 복귀.
///
/// [onTap] 콜백은 탭이 인식되면 호출된다. 기존 자식 위젯의 GestureDetector는
/// 제거해야 중복되지 않는다.
class TiltContainer extends StatefulWidget {
  const TiltContainer({
    super.key,
    required this.child,
    required this.deviceTilt,
    this.onTap,
    this.maxDeviceAngle = 0.1,
    this.maxTouchAngle = 0.14,
    this.perspective = 0.0016,
  });

  final Widget child;
  final DeviceTiltController deviceTilt;
  final VoidCallback? onTap;

  /// 기기 기울기로 인한 최대 회전각(rad).
  final double maxDeviceAngle;

  /// 터치로 인한 최대 회전각(rad).
  final double maxTouchAngle;

  /// 3D 원근 강도.
  final double perspective;

  @override
  State<TiltContainer> createState() => _TiltContainerState();
}

class _TiltContainerState extends State<TiltContainer> {
  static const double _touchSmoothing = 0.22;
  static const double _deadZone = 0.0005;

  Offset _touchTilt = Offset.zero;
  Offset _touchTarget = Offset.zero;
  Timer? _timer;
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 16), _onTick);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onTick(Timer timer) {
    if ((_touchTarget - _touchTilt).distance > _deadZone) {
      setState(() {
        _touchTilt = Offset(
          _touchTilt.dx +
              (_touchTarget.dx - _touchTilt.dx) * _touchSmoothing,
          _touchTilt.dy +
              (_touchTarget.dy - _touchTilt.dy) * _touchSmoothing,
        );
      });
    }
  }

  void _onTapDown(TapDownDetails details) {
    if (_size.isEmpty) return;
    final normX =
        (details.localPosition.dx - _size.width / 2) / (_size.width / 2);
    final normY =
        (details.localPosition.dy - _size.height / 2) / (_size.height / 2);
    _touchTarget = Offset(
      -normX.clamp(-1.0, 1.0) * widget.maxTouchAngle,
      normY.clamp(-1.0, 1.0) * widget.maxTouchAngle,
    );
  }

  void _release() {
    _touchTarget = Offset.zero;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = Size(constraints.maxWidth, constraints.maxHeight);
        return AnimatedBuilder(
          animation: widget.deviceTilt,
          builder: (context, _) {
            final device = widget.deviceTilt.value;
            // Y축 회전 = 좌우 기울기 (device.dx) + 좌우 터치 (_touchTilt.dx)
            // X축 회전 = 앞뒤 기울기 (device.dy) + 상하 터치 (_touchTilt.dy)
            final rotY = device.dx * widget.maxDeviceAngle + _touchTilt.dx;
            final rotX = device.dy * widget.maxDeviceAngle + _touchTilt.dy;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: _onTapDown,
              onTapUp: (_) => _release(),
              onTapCancel: _release,
              onTap: widget.onTap,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, widget.perspective)
                  ..rotateX(rotX)
                  ..rotateY(rotY),
                child: widget.child,
              ),
            );
          },
        );
      },
    );
  }
}
