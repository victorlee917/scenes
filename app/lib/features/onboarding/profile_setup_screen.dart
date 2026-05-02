import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors_ext.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../home/home_view_model.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _picker = ImagePicker();
  File? _pickedImage;
  bool _picking = false;
  bool _hasName = false;

  @override
  void initState() {
    super.initState();
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

  void _continue() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    // TODO: Supabase에 프로필 저장
    ref.read(homeViewModelProvider.notifier).setProfileComplete(true);
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);

    return Scaffold(
      body: Padding(
        padding: EdgeInsets.only(
          top: padding.top + 60,
          left: 32,
          right: 32,
          bottom: padding.bottom + 32,
        ),
        child: Column(
          children: [
            const Spacer(flex: 2),

            Text(
              'Set up\nyour profile',
              textAlign: TextAlign.center,
              style: AppTypography.display(34).copyWith(
                color: context.colors.foreground,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Add a photo and your name\nso your person can recognize you.',
              textAlign: TextAlign.center,
              style: AppTypography.body(15).copyWith(
                color: context.colors.foregroundMuted,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 40),

            // 프로필 사진
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 100,
                height: 100,
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
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
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

            const SizedBox(height: 28),

            // 이름 입력
            Container(
              decoration: BoxDecoration(
                color: context.colors.nonClickableArea,
                borderRadius: AppRadii.lgBorder,
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
                maxLength: 12,
                style: AppTypography.body(15).copyWith(
                  color: context.colors.foreground,
                ),
                buildCounter: (_, {required currentLength, required isFocused, required maxLength}) => null,
                decoration: InputDecoration(
                  hintText: 'Your name (max 12)',
                  hintStyle: AppTypography.body(15).copyWith(
                    color: context.colors.foregroundMuted.withValues(alpha: 0.4),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
              ),
            ),

            const Spacer(flex: 3),

            // 계속 버튼
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _hasName ? _continue : null,
                child: AnimatedOpacity(
                  opacity: _hasName ? 1.0 : 0.4,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      borderRadius: AppRadii.lgBorder,
                      color: context.colors.foreground,
                    ),
                    child: Center(
                      child: Text(
                        'Continue',
                        style: AppTypography.body(15, weight: FontWeight.w600)
                            .copyWith(color: context.colors.background),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
