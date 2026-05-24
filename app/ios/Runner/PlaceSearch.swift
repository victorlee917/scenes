import Flutter
import MapKit

/// Apple Maps native 장소 검색 플러그인.
///
/// Flutter 측에서 `MethodChannel('app.scenes/place_search')` 로 invoke.
/// MKLocalSearch를 사용해 자연어 질의를 수행하고 PlaceHit 호환 dict 배열을
/// 반환. iOS 자체 데이터(Apple Maps)라 외부 API 키 / 비용 0.
class PlaceSearch {
  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "app.scenes/place_search",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "search":
      guard let args = call.arguments as? [String: Any],
            let query = args["query"] as? String,
            !query.isEmpty else {
        result([])
        return
      }
      search(query: query, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func search(query: String, result: @escaping FlutterResult) {
    let request = MKLocalSearch.Request()
    request.naturalLanguageQuery = query
    // POI + 주소 모두 허용. 기본값이라 명시 불필요지만 의도 명확화.
    if #available(iOS 13.0, *) {
      request.resultTypes = [.pointOfInterest, .address]
    }

    let search = MKLocalSearch(request: request)
    search.start { response, error in
      if error != nil {
        // 네이티브 에러도 Flutter에선 빈 결과로 처리 — 사용자 흐름 안 막음.
        result([])
        return
      }
      guard let items = response?.mapItems else {
        result([])
        return
      }

      let mapped: [[String: Any]] = items.map { item in
        let placemark = item.placemark
        let coord = placemark.coordinate

        // 표시용 이름: POI는 item.name(상호), 주소는 placemark.thoroughfare
        // 등으로 보정. iOS가 자동으로 적절한 name 채워줌.
        let name = item.name ?? placemark.name ?? query

        // fullAddress: 가장 작은 단위부터 큰 단위로. 같은 값이 여러 필드에
        // 들어오는 경우(예: 광역시) 중복 제거.
        var parts: [String] = []
        let candidates: [String?] = [
          placemark.thoroughfare,
          placemark.subLocality,
          placemark.locality,
          placemark.administrativeArea,
          placemark.country,
        ]
        for c in candidates {
          guard let s = c, !s.isEmpty, !parts.contains(s) else { continue }
          parts.append(s)
        }
        // 첫 토큰이 name과 같으면 중복 — 한 번 더 정리.
        if let first = parts.first, first == name {
          parts.removeFirst()
        }
        let fullAddress = ([name] + parts)
          .filter { !$0.isEmpty }
          .joined(separator: ", ")

        // id는 좌표 + 이름 기반 — Mapbox feature id 같은 안정 id가 없어 임의
        // 합성. 같은 좌표에 같은 이름이면 같은 id가 나와 picker에서 중복 가능.
        let id = "apple|\(coord.latitude),\(coord.longitude)|\(name)"

        return [
          "id": id,
          "name": name,
          "region": placemark.administrativeArea ?? NSNull(),
          "country": placemark.country ?? NSNull(),
          "fullAddress": fullAddress,
          "lat": coord.latitude,
          "lng": coord.longitude,
        ]
      }
      result(mapped)
    }
  }
}
