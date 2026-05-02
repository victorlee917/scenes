import 'dart:async';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// 가속도계 데이터를 정규화(-1..1)하고 low-pass smoothing해서 ValueListenable
/// 로 노출. 여러 [TiltContainer]가 동일 인스턴스를 구독해 기기 기울기에
/// 일관되게 반응한다.
///
/// 노출 값의 의미:
/// - `dx`: 좌우 기울기. 장치를 오른쪽으로 기울이면 양수.
/// - `dy`: 앞뒤 기울기. 장치 상단이 사용자 쪽으로 기울면 양수.
///
/// 각 축은 중력 9.8로 나눠 -1..1 범위로 clamp.
class DeviceTiltController extends ChangeNotifier
    implements ValueListenable<Offset> {
  DeviceTiltController() {
    _subscribe();
    _smoothTimer =
        Timer.periodic(const Duration(milliseconds: 16), _onSmoothTick);
  }

  void _subscribe() {
    // 플러그인이 아직 등록되지 않았거나(hot reload 직후) 센서가 없는
    // 환경(desktop, web)에서는 MissingPluginException 등이 던져질 수 있음.
    // 실패해도 앱이 죽지 않게 조용히 무시하고 정적 0 값 유지.
    try {
      _subscription = accelerometerEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(
        _onAccel,
        onError: (Object _) {},
        cancelOnError: true,
      );
    } catch (_) {
      _subscription = null;
    }
  }

  static const double _smoothing = 0.12;
  static const double _deadZone = 0.0005;

  Offset _value = Offset.zero;
  Offset _target = Offset.zero;
  StreamSubscription<AccelerometerEvent>? _subscription;
  Timer? _smoothTimer;

  @override
  Offset get value => _value;

  void _onAccel(AccelerometerEvent event) {
    final nx = (-event.x / 9.8).clamp(-1.0, 1.0);
    final ny = (event.y / 9.8).clamp(-1.0, 1.0);
    _target = Offset(nx, ny);
  }

  void _onSmoothTick(Timer timer) {
    final next = Offset(
      _value.dx + (_target.dx - _value.dx) * _smoothing,
      _value.dy + (_target.dy - _value.dy) * _smoothing,
    );
    if ((next - _value).distance > _deadZone) {
      _value = next;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _smoothTimer?.cancel();
    super.dispose();
  }
}
