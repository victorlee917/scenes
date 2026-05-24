/// 장소 검색 결과 단일 항목. 검색 소스(Apple Maps MKLocalSearch / Mapbox
/// geocoding)와 무관하게 동일 모델로 정규화 — picker UI는 출처를 모르고 다룸.
///
/// 정적지도 캐싱은 픽 이후 `mapbox-static-cache` Edge Function이 처리한다
/// (platform 무관).
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

  /// 검색 소스별 안정 id. iOS는 `apple|lat,lng|name` 합성, Mapbox는 feature
  /// id(`poi.123` 등). 같은 소스 안에서 unique 보장.
  final String id;

  /// 장소명. POI 이름(Tokyo Tower) 또는 도시명(Tokyo).
  final String name;

  /// 시·도 등 중간 단계 위치. 없으면 null.
  final String? region;

  /// 국가. 없으면 null.
  final String? country;

  /// 풀 주소. 디테일 화면 등에서 사용 가능.
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
