import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/floating_bottom_sheet.dart';
import '../../scene/scenes_view_model.dart';
import '../models/scene.dart';
import 'scene_detail_screen.dart';

/// Scene 생성/수정 바텀시트.
///
/// [editScene]이 null이면 새 Scene 생성, 아니면 기존 Scene 수정.
class CreateSceneSheet extends ConsumerStatefulWidget {
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
  ConsumerState<CreateSceneSheet> createState() => _CreateSceneSheetState();
}

class _CreateSceneSheetState extends ConsumerState<CreateSceneSheet> {
  final _titleController = TextEditingController();
  final _picker = ImagePicker();
  File? _coverImage;
  bool _picking = false;
  bool _hasTitle = false;
  bool _saving = false;

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
    setState(() => _picking = true);
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
      if (picked == null) return;

      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 85,
        // 캐니스터 표시 ~200 logical px → 3x retina 기준 600 정도가 한계.
        // 큰 폰에서도 시각 차이 없고 download/decode가 가벼워 첫 로드가 즉각.
        maxWidth: 600,
        maxHeight: 600,
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
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);
    try {
      Scene? createdScene;
      if (widget.isEditing) {
        final scene = widget.editScene!;
        final titleChanged = title != scene.title;
        final coverChanged = _coverImage != null;
        if (titleChanged || coverChanged) {
          await ref.read(scenesProvider.notifier).editScene(
                id: scene.id,
                title: titleChanged ? title : null,
                coverFile: _coverImage,
              );
        }
      } else {
        // 신규 생성. 일단 today만 dates에 넣음 — 추후 sheet에 date picker 추가.
        createdScene = await ref.read(scenesProvider.notifier).create(
              title: title,
              dates: [DateTime.now()],
              coverFile: _coverImage,
            );
      }
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pop();
        // 신규 생성이면 만든 scene의 detail로 바로 이동. edit이면 그대로 close.
        if (createdScene != null) {
          final viewportWidth = MediaQuery.sizeOf(context).width;
          Navigator.of(context).push(
            SceneDetailScreen.fadeRoute(
              scene: createdScene,
              canisterSize: viewportWidth * 0.5,
            ),
          );
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppToast.show(context, 'Failed to save scene.');
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
          widget.isEditing ? 'Edit Scene' : 'New Scene',
          style: AppTypography.display(20).copyWith(
            color: context.colors.foreground,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 28),

        // 커버 사진 선택
        GestureDetector(
          onTap: _picking ? null : _pickCoverImage,
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
                  if (_coverImage != null)
                    Image.file(
                      _coverImage!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    )
                  else if (widget.editScene != null &&
                      widget.editScene!.coverImageUrl.isNotEmpty)
                    Image.network(
                      widget.editScene!.coverImageUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          ColoredBox(color: context.colors.nonClickableArea),
                    )
                  else
                    Center(
                      child: FaIcon(
                        FontAwesomeIcons.camera,
                        size: 24,
                        color: context.colors.foregroundMuted,
                      ),
                    ),
                  // picker/cropper 모듈 로딩 중 dim + 흰색 spinner.
                  // 프로필 아바타와 동일 패턴.
                  if (_picking)
                    const ColoredBox(
                      color: Color(0x99000000),
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
              onTap: (_hasTitle && !_saving) ? _submit : null,
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
                  // 고정 높이로 spinner ↔ text 전환 시 layout 흔들림 방지.
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
                              widget.isEditing ? 'Save' : 'Create',
                              style: AppTypography.body(16,
                                      weight: FontWeight.w600)
                                  .copyWith(color: context.colors.background),
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
