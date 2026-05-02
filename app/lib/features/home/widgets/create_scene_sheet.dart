import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/floating_bottom_sheet.dart';
import '../models/scene.dart';

/// Scene 생성/수정 바텀시트.
///
/// [editScene]이 null이면 새 Scene 생성, 아니면 기존 Scene 수정.
class CreateSceneSheet extends StatefulWidget {
  const CreateSceneSheet({super.key, this.editScene});

  final Scene? editScene;

  bool get isEditing => editScene != null;

  static Future<void> show({
    required BuildContext context,
    Scene? editScene,
  }) {
    return FloatingBottomSheet.show(
      context: context,
      builder: (_) => CreateSceneSheet(editScene: editScene),
    );
  }

  @override
  State<CreateSceneSheet> createState() => _CreateSceneSheetState();
}

class _CreateSceneSheetState extends State<CreateSceneSheet> {
  final _titleController = TextEditingController();
  final _picker = ImagePicker();
  File? _coverImage;
  bool _picking = false;
  bool _hasTitle = false;

  @override
  void initState() {
    super.initState();
    if (widget.editScene != null) {
      _titleController.text = widget.editScene!.title;
      _hasTitle = true;
    }
    _titleController.addListener(() {
      final has = _titleController.text.trim().isNotEmpty;
      if (has != _hasTitle) setState(() => _hasTitle = has);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
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
      setState(() => _coverImage = File(cropped.path));
    }
    } finally {
      _picking = false;
    }
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    if (widget.isEditing) {
      // Scene 수정 로직. UI는 추후.
    } else {
      // Scene 생성 로직. UI는 추후.
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),

        Text(
          widget.isEditing ? 'Edit Scene' : 'New Scene',
          style: AppTypography.display(20).copyWith(
            color: context.colors.foreground,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 28),

        // 커버 사진 선택
        GestureDetector(
          onTap: _pickCoverImage,
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
            child: _coverImage != null
                ? ClipOval(
                    child: Image.file(
                      _coverImage!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  )
                : widget.editScene != null
                    ? ClipOval(
                        child: Image.network(
                          widget.editScene!.coverImageUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: context.colors.nonClickableArea,
                          ),
                        ),
                      )
                    : Center(
                    child: FaIcon(
                      FontAwesomeIcons.camera,
                      size: 24,
                      color: context.colors.foregroundMuted,
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 24),

        // 타이틀 입력
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
              controller: _titleController,
              textAlign: TextAlign.center,
              autocorrect: false,
              enableSuggestions: false,
              style: AppTypography.body(15).copyWith(
                color: context.colors.foreground,
              ),
              decoration: InputDecoration(
                hintText: 'Scene title',
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

        // 생성 버튼
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _hasTitle ? _submit : null,
              child: AnimatedOpacity(
                opacity: _hasTitle ? 1.0 : 0.4,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: AppRadii.sheetInnerBorder,
                    color: context.colors.foreground,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    widget.isEditing ? 'Save' : 'Create',
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
