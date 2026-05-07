/// Mapbox 검색 결과 단일 항목 (장소).
///
/// `mapbox-geocode` Edge Function이 정규화해 반환. 정적지도 캐싱은 별도
/// `mapbox-static-cache` Edge Function에서 처리(픽 이후).
class PlaceHit {
  const PlaceHit({
    required this.id,
    required this.name,
    required this.region,
    required this.country,
    required this.fullAddress,
    required this.lat,
    required this.lng,
  });

  /// Mapbox feature id (예: `poi.123`, `place.456`).
  final String id;

  /// 장소명. POI 이름(Tokyo Tower) 또는 도시명(Tokyo).
  final String name;

  /// 시·도 등 중간 단계 위치. 없으면 null.
  final String? region;

  /// 국가. 없으면 null.
  final String? country;

  /// Mapbox `place_name` — 풀 주소. 디테일 화면 등에서 사용 가능.
  final String fullAddress;

  final double lat;
  final double lng;

  factory PlaceHit.fromJson(Map<String, dynamic> json) {
    return PlaceHit(
      id: json['id'] as String,
      name: json['name'] as String,
      region: json['region'] as String?,
      country: json['country'] as String?,
      fullAddress: json['full_address'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }
}
