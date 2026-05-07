/// 사진 한 장에 대해 저장할 메타데이터.
///
/// `photo_manager.AssetEntity`에서 일부(width/height/createDateTime/lat/lng)는
/// 직접 가져오고, 카메라/렌즈/노출 등 EXIF 디테일은 원본 바이트를 `exif`
/// 패키지로 파싱해서 채운다. 어떤 필드든 누락 가능 — 모두 nullable.
///
/// contents.payload (memory: external_media_caching_policy) 매핑:
/// ```
/// type='photo' {
///   "storage_path": "...",
///   "width": ..., "height": ...,
///   "taken_at": "...",
///   "lat": ..., "lng": ...,
///   "exif": {
///     "camera_make": "...", "camera_model": "...",
///     "lens_model": "...",
///     "focal_length": ..., "aperture": ...,
///     "exposure_time": "...", "iso": ...,
///     "orientation": ...
///   }
/// }
/// ```
class PhotoMetadata {
  const PhotoMetadata({
    this.width,
    this.height,
    this.takenAt,
    this.lat,
    this.lng,
    this.cameraMake,
    this.cameraModel,
    this.lensModel,
    this.focalLength,
    this.aperture,
    this.exposureTime,
    this.iso,
    this.orientation,
  });

  // ── 기본 정보 (대부분 AssetEntity 직접 제공) ─────────────────
  final int? width;
  final int? height;
  final DateTime? takenAt;
  final double? lat;
  final double? lng;

  // ── EXIF 디테일 (exif 패키지로 추출) ────────────────────────
  final String? cameraMake;
  final String? cameraModel;
  final String? lensModel;

  /// mm 단위 (예: 50.0).
  final double? focalLength;

  /// f-stop (예: 1.8).
  final double? aperture;

  /// 분수 표기 그대로 보관 (예: "1/250").
  final String? exposureTime;

  final int? iso;

  /// EXIF Orientation tag (1~8).
  final int? orientation;

  /// payload 직렬화. null 필드는 제외해 깔끔한 JSON.
  Map<String, dynamic> toPayloadJson() {
    final exif = <String, dynamic>{
      if (cameraMake != null) 'camera_make': cameraMake,
      if (cameraModel != null) 'camera_model': cameraModel,
      if (lensModel != null) 'lens_model': lensModel,
      if (focalLength != null) 'focal_length': focalLength,
      if (aperture != null) 'aperture': aperture,
      if (exposureTime != null) 'exposure_time': exposureTime,
      if (iso != null) 'iso': iso,
      if (orientation != null) 'orientation': orientation,
    };
    return <String, dynamic>{
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (takenAt != null) 'taken_at': takenAt!.toIso8601String(),
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (exif.isNotEmpty) 'exif': exif,
    };
  }
}
