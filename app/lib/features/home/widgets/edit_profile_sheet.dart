import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/floating_bottom_sheet.dart';
import '../../profile/profile_view_model.dart';

/// 프로필 수정 바텀시트.
///
/// Scene 생성 시트와 동일한 구조: 원형 사진 + 이름 입력 + 저장 버튼.
class EditProfileSheet extends ConsumerStatefulWidget {
  const EditProfileSheet({
    super.key,
    required this.currentName,
    required this.currentImageUrl,
  });

  final String currentName;
  final String currentImageUrl;

  static Future<void> show({
    required BuildContext context,
    required String currentName,
    required String currentImageUrl,
  }) {
    return FloatingBottomSheet.show(
      context: context,
      builder: (_) => EditProfileSheet(
        currentName: currentName,
        currentImageUrl: currentImageUrl,
      ),
    );
  }

  @override
  ConsumerState<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<EditProfileSheet> {
  final _nameController = TextEditingController();
  final _picker = ImagePicker();
  File? _pickedImage;
  bool _picking = false;
  bool _hasName = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.currentName;
    _hasName = widget.currentName.isNotEmpty;
    _nameController.addListener(() {
      final has = _nameController.text.trim().isNotEmpty;
      if (has != _hasName) setState(() => _hasName = has);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// 아바타 내부 콘텐츠. 우선순위:
  ///   1. 새로 고른 이미지 (_pickedImage)
  ///   2. 기존 currentImageUrl
  ///   3. 이름 첫 글자 fallback
  Widget _avatarContent() {
    if (_pickedImage != null) {
      return Image.file(
        _pickedImage!,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
      );
    }
    if (widget.currentImageUrl.isEmpty) {
      return _initialFallback();
    }
    return Image.network(
      widget.currentImageUrl,
      width: 80,
      height: 80,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _initialFallback(),
    );
  }

  /// 사진이 없거나 로드 실패 시 표시할 이니셜. 80x80 컨테이너에 비율 맞춤.
  Widget _initialFallback() {
    final trimmed = widget.currentName.trim();
    final initial = trimmed.isEmpty
        ? ''
        : String.fromCharCodes(trimmed.runes.take(1)).toUpperCase();
    return ColoredBox(
      color: context.colors.nonClickableArea,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 100,
          height: 100,
          // 시각적 중심을 위해 글자를 살짝 위로.
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Center(
              child: Text(
                initial,
                textAlign: TextAlign.center,
                textHeightBehavior: const TextHeightBehavior(
                  applyHeightToFirstAscent: false,
                  applyHeightToLastDescent: false,
                ),
                style: AppTypography.display(42).copyWith(
                  color: context.colors.foregroundMuted,
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
      if (picked == null) return;

      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        // iOS picker가 HEIC를 줄 수 있어 JPEG로 강제 변환.
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 85,
        // 아바타 표시는 80~100 logical px → 3x retina 기준 ~300px이면 충분.
        // 256으로도 시각 차이 거의 없고 download/decode가 훨씬 빨라짐.
        maxWidth: 256,
        maxHeight: 256,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          IOSUiSettings(
            title: 'Crop',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
          AndroidUiSettings(
            toolbarTitle: 'Crop',
            lockAspectRatio: true,
            hideBottomControls: true,
          ),
        ],
      );
      if (cropped != null && mounted) {
        setState(() => _pickedImage = File(cropped.path));
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final nameChanged = name != widget.currentName;
    final avatarChanged = _pickedImage != null;
    if (!nameChanged && !avatarChanged) {
      // 변경 없음 → 그냥 닫기.
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = true);
    try {
      // 1) 네트워크 저장만 — state는 안 건드림.
      final updated =
          await ref.read(myProfileProvider.notifier).updateProfileRemote(
                name: nameChanged ? name : null,
                avatarFile: _pickedImage,
              );
      if (!mounted) return;

      // 2) 즉시 pop. unfocus를 미리 호출하면 키보드 dismiss로 viewInsets가 변하면서
      //    시트가 자연 위치로 "settle"하는 모션이 먼저 발생 → pop 슬라이드와 분리돼
      //    두 번 움직이는 듯한 덜컹임. unfocus 없이 pop하면 route teardown으로
      //    키보드도 자동으로 dismiss되며 pop 슬라이드와 한 번에 자연스럽게 흘러내림.
      final notifier = ref.read(myProfileProvider.notifier);
      Navigator.of(context).pop();
      // 3) 시트 닫힘 끝난 뒤 state 반영 — ProfileScreen이 부드럽게 갱신.
      Future<void>.delayed(const Duration(milliseconds: 320), () {
        notifier.applyProfile(updated);
      });
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        // 디버그용: 실제 에러 메시지 노출. 운영 시 generic message로 변경.
        AppToast.show(context, 'Save failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),

        Text(
          'Edit Profile',
          style: AppTypography.display(20).copyWith(
            color: context.colors.foreground,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 28),

        // 프로필 사진
        GestureDetector(
          onTap: _picking ? null : _pickImage,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.colors.nonClickableArea,
              border: Border.all(
                color: context.colors.foreground.withValues(alpha: 0.08),
                width: 0.5,
              ),
            ),
            child: ClipOval(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _avatarContent(),
                  // picker/cropper 모듈 로딩 중에 dim + 흰색 spinner.
                  // dim이 테마 차이를 흡수하므로 spinner는 항상 white가 자연.
                  if (_picking)
                    const ColoredBox(
                      color: Color(0x99000000), // 60% black dim
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // 이름 입력
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: context.colors.nonClickableArea,
              borderRadius: AppRadii.sheetInnerBorder,
              border: Border.all(
                color: context.colors.foreground.withValues(alpha: 0.06),
                width: 0.5,
              ),
            ),
            child: TextField(
              controller: _nameController,
              textAlign: TextAlign.center,
              autocorrect: false,
              enableSuggestions: false,
              style: AppTypography.body(15).copyWith(
                color: context.colors.foreground,
              ),
              decoration: InputDecoration(
                hintText: 'Name',
                hintStyle: AppTypography.body(15).copyWith(
                  color: context.colors.foregroundMuted.withValues(alpha: 0.5),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // 저장 버튼
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: (_hasName && !_saving) ? _save : null,
              child: AnimatedOpacity(
                opacity: _hasName ? 1.0 : 0.4,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: AppRadii.sheetInnerBorder,
                    color: context.colors.foreground,
                  ),
                  alignment: Alignment.center,
                  // 고정 높이로 감싸서 spinner ↔ 'Save' 전환 시 버튼 높이가
                  // 변하지 않도록. (그 변화가 시트 전체 layout을 한 번 덜컹이게 함.)
                  child: SizedBox(
                    height: 22,
                    child: Center(
                      child: _saving
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: context.colors.background,
                              ),
                            )
                          : Text(
                              'Save',
                              style:
                                  AppTypography.body(16, weight: FontWeight.w600)
                                      .copyWith(
                                color: context.colors.background,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }
}
