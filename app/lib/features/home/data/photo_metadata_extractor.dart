import 'dart:typed_data';

import 'package:exif/exif.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/photo_metadata.dart';

/// `AssetEntity`에서 [PhotoMetadata]를 추출.
///
/// 원본 바이트를 한 번만 읽어 EXIF 파싱. 각 EXIF tag는 누락될 수 있어
/// 모든 추출은 try/null로 안전하게.
///
/// **호출 비용**: 원본 바이트(수MB) 디코드. Save 시점에 한 번만 호출.
/// 검색·preview 단계에서 호출하지 말 것.
class PhotoMetadataExtractor {
  Future<PhotoMetadata> extract(AssetEntity asset) async {
    final basic = await _basicFromAsset(asset);

    Uint8List? bytes;
    try {
      bytes = await asset.originBytes;
    } catch (_) {
      // 원본 접근 실패 시(권한·대용량 등) 기본 정보만으로 반환.
      return basic;
    }
    if (bytes == null) return basic;

    Map<String, IfdTag> tags;
    try {
      tags = await readExifFromBytes(bytes);
    } catch (_) {
      return basic;
    }
    if (tags.isEmpty) return basic;

    return PhotoMetadata(
      width: basic.width,
      height: basic.height,
      takenAt: basic.takenAt,
      lat: basic.lat,
      lng: basic.lng,
      cameraMake: _readString(tags['Image Make']),
      cameraModel: _readString(tags['Image Model']),
      lensModel: _readString(tags['EXIF LensModel']) ??
          _readString(tags['EXIF LensSpecification']),
      focalLength: _readRational(tags['EXIF FocalLength']),
      aperture: _readRational(tags['EXIF FNumber']),
      exposureTime: _readShutter(tags['EXIF ExposureTime']),
      iso: _readInt(tags['EXIF ISOSpeedRatings']),
      orientation: _readInt(tags['Image Orientation']),
    );
  }

  Future<PhotoMetadata> _basicFromAsset(AssetEntity asset) async {
    double? lat;
    double? lng;
    try {
      final latlng = await asset.latlngAsync();
      // photo_manager은 GPS 없으면 LatLng(0,0) 또는 null. 의미 있는 값만 채택.
      if (latlng != null &&
          !(latlng.latitude == 0 && latlng.longitude == 0)) {
        lat = latlng.latitude.toDouble();
        lng = latlng.longitude.toDouble();
      }
    } catch (_) {
      // GPS 추출 실패 시 무시.
    }
    return PhotoMetadata(
      width: asset.width,
      height: asset.height,
      takenAt: asset.createDateTime,
      lat: lat,
      lng: lng,
    );
  }

  String? _readString(IfdTag? tag) {
    if (tag == null) return null;
    final s = tag.printable.trim();
    if (s.isEmpty) return null;
    return s;
  }

  int? _readInt(IfdTag? tag) {
    if (tag == null) return null;
    final values = tag.values.toList();
    if (values.isEmpty) return null;
    final v = values.first;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(tag.printable);
  }

  /// EXIF rational 값을 double로. 없으면 printable 파싱 시도.
  double? _readRational(IfdTag? tag) {
    if (tag == null) return null;
    final values = tag.values.toList();
    if (values.isNotEmpty) {
      final v = values.first;
      if (v is Ratio) {
        if (v.denominator == 0) return null;
        return v.numerator / v.denominator;
      }
      if (v is num) return v.toDouble();
    }
    return double.tryParse(tag.printable);
  }

  /// 셔터스피드는 보통 `1/250` 같은 분수 표기를 그대로 보존.
  String? _readShutter(IfdTag? tag) {
    if (tag == null) return null;
    final p = tag.printable.trim();
    return p.isEmpty ? null : p;
  }
}
