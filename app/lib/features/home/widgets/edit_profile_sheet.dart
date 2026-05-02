import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/floating_bottom_sheet.dart';

/// 프로필 수정 바텀시트.
///
/// Scene 생성 시트와 동일한 구조: 원형 사진 + 이름 입력 + 저장 버튼.
class EditProfileSheet extends StatefulWidget {
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
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  final _nameController = TextEditingController();
  final _picker = ImagePicker();
  File? _pickedImage;
  bool _picking = false;
  bool _hasName = false;

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

  Future<void> _pickImage() async {
    if (_picking) return;
    _picking = true;
    try {
      final picked = await _picker.pickImage(
          source: ImageSource.gallery,
          requestFullMetadata: false,
      );
      if (picked == null) return;

      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
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
      _picking = false;
    }
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    // 프로필 저장 로직. UI는 추후.
    Navigator.of(context).pop();
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
          onTap: _pickImage,
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
            child: _pickedImage != null
                ? ClipOval(
                    child: Image.file(
                      _pickedImage!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  )
                : ClipOval(
                    child: Image.network(
                      widget.currentImageUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Center(
                        child: FaIcon(
                          FontAwesomeIcons.user,
                          size: 24,
                          color: context.colors.foregroundMuted,
                        ),
                      ),
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
              onTap: _hasName ? _save : null,
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
                  child: Text(
                    'Save',
                    style: AppTypography.body(16, weight: FontWeight.w600)
                        .copyWith(color: context.colors.background),
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
