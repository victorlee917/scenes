/// 삽입/접근 순서를 추적하는 단순 LRU 캐시.
///
/// [maxSize]를 초과하면 가장 오래 전에 사용된 항목부터 제거한다. Dart `Map`이
/// 삽입 순서를 보존하는 점을 이용 — get/put 시 키를 맨 뒤로 재배치한다.
///
/// 값 타입을 non-nullable로 강제(`V extends Object`)해 [get]이 null을 반환하면
/// 곧 "캐시 미스"를 의미하도록 보장한다.
class LruCache<K, V extends Object> {
  LruCache({this.maxSize = 32}) : assert(maxSize > 0);

  final int maxSize;
  final Map<K, V> _entries = {};

  /// 캐시된 값을 반환하고 최근 사용으로 표시. 없으면 null.
  V? get(K key) {
    final value = _entries.remove(key);
    if (value == null) return null;
    _entries[key] = value;
    return value;
  }

  /// 값을 저장하고 최근 사용으로 표시. 용량 초과 시 LRU 항목 제거.
  void put(K key, V value) {
    _entries.remove(key);
    _entries[key] = value;
    if (_entries.length > maxSize) {
      _entries.remove(_entries.keys.first);
    }
  }

  void clear() => _entries.clear();
}
