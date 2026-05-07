import 'dart:typed_data';

import 'package:exif/exif.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../home/models/photo_metadata.dart';

/// `AssetEntity` + 원본 바이트 → `PhotoMetadata` 변환.
///
/// 기본 정보(width/height/createDateTime/lat/lng)는 AssetEntity가 직접 제공.
/// 카메라/렌즈/노출 등 EXIF 디테일은 원본 바이트를 `exif` 패키지로 파싱.
/// EXIF 자체가 없으면 (스크린샷, 일부 편집된 이미지 등) 그 부분만 빠지고
/// 기본 정보는 그대로 유지.
class PhotoMetadataExtractor {
  PhotoMetadataExtractor._();

  static Future<PhotoMetadata> extract({
    required AssetEntity asset,
    required Uint8List originBytes,
  }) async {
    final basicW = asset.width;
    final basicH = asset.height;
    final taken = asset.createDateTime;
    // photo_manager는 lat/lng가 모를 때 0,0을 채워 보내는 경우가 있어
    // 둘 다 0이면 무의미한 좌표로 간주하고 버림.
    double? lat = asset.latitude;
    double? lng = asset.longitude;
    if ((lat == 0 && lng == 0) || lat == null || lng == null) {
      lat = null;
      lng = null;
    }

    Map<String, IfdTag> tags = const {};
    try {
      tags = await readExifFromBytes(originBytes);
    } catch (_) {
      // EXIF 없거나 파싱 실패 — 기본 정보만 유지하고 진행.
    }

    String? str(String key) {
      final v = tags[key]?.printable;
      if (v == null) return null;
      final trimmed = v.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    int? toInt(String? raw) {
      if (raw == null) return null;
      final cleaned = raw.replaceAll(RegExp(r'[\[\]\s]'), '');
      return int.tryParse(cleaned);
    }

    double? toDouble(String? raw) {
      if (raw == null) return null;
      final cleaned = raw.replaceAll(RegExp(r'[\[\]\s]'), '');
      // "50/1" 같은 rational 표기 처리.
      if (cleaned.contains('/')) {
        final parts = cleaned.split('/');
        if (parts.length == 2) {
          final num = double.tryParse(parts[0]);
          final den = double.tryParse(parts[1]);
          if (num != null && den != null && den != 0) return num / den;
        }
        return null;
      }
      return double.tryParse(cleaned);
    }

    return PhotoMetadata(
      width: basicW == 0 ? null : basicW,
      height: basicH == 0 ? null : basicH,
      takenAt: taken,
      lat: lat,
      lng: lng,
      cameraMake: str('Image Make'),
      cameraModel: str('Image Model'),
      lensModel: str('EXIF LensModel'),
      focalLength: toDouble(str('EXIF FocalLength')),
      aperture: toDouble(str('EXIF FNumber')),
      // 1/250 같은 분수 표기는 그대로 보관 (PhotoMetadata.exposureTime이 String).
      exposureTime: str('EXIF ExposureTime'),
      iso: toInt(str('EXIF ISOSpeedRatings')),
      orientation: toInt(str('Image Orientation')),
    );
  }
}
