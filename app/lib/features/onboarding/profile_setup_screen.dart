import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors_ext.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_toast.dart';
import '../profile/profile_view_model.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _picker = ImagePicker();
  File? _pickedImage;
  bool _picking = false;
  bool _hasName = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() {
      final has = _nameController.text.trim().isNotEmpty;
      if (has != _hasName) setState(() => _hasName = has);
    });
    // 첫 프레임 그려진 직후 키보드 올림. initState에서 직접 requestFocus 하면
    // 라우트 전환 애니메이션과 충돌해서 키보드가 안 뜨거나 끊겨 보임.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
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
        // iOS picker HEIC 대응: JPEG로 강제 변환해 storage Content-Type과 일치시킴.
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 85,
        // 아바타 표시는 80~100 logical px → 256이면 retina에도 충분.
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

  Future<void> _continue() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(myProfileProvider.notifier).completeOnboarding(
            name: name,
            avatarFile: _pickedImage,
          );
      // 성공 시 onboarding_completed_at가 채워져 router가 자동 redirect.
    } catch (e) {
      if (mounted) AppToast.show(context, 'Failed to save profile.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);

    // 레이아웃 분리:
    //   - 위: Expanded + SingleChildScrollView 본문 (타이틀/사진/입력란).
    //     Spacer 대신 SizedBox로 고정 간격 — 스크롤이라 unbounded 컨테이너에서
    //     Spacer 못 씀.
    //   - 아래: Padding으로 감싼 고정 Continue 버튼. Scaffold가 키보드 위로
    //     body를 줄여(resizeToAvoidBottomInset=true) 버튼이 항상 키보드 바로
    //     위에 붙어 보임.
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                top: padding.top + 80,
                left: 32,
                right: 32,
                // 키보드 올라오면 Flutter가 focus된 TextField를 viewport 하단에
                // 맞춰 auto-scroll 시킴. 이 padding이 그때 TextField와 sticky
                // 버튼 사이 여백 역할을 함.
                bottom: 40,
              ),
              child: Column(
                children: [
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
                    onTap: _picking ? null : _pickImage,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.colors.nonClickableArea,
                        border: Border.all(
                          color: context.colors.foreground
                              .withValues(alpha: 0.08),
                          width: 0.5,
                        ),
                      ),
                      child: ClipOval(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (_pickedImage != null)
                              Image.file(
                                _pickedImage!,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
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
                            if (_picking)
                              const ColoredBox(
                                color: Color(0x99000000),
                                child: Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
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
                  const SizedBox(height: 28),

                  // 이름 입력
                  Container(
                    decoration: BoxDecoration(
                      color: context.colors.nonClickableArea,
                      borderRadius: AppRadii.lgBorder,
                      border: Border.all(
                        color: context.colors.foreground
                            .withValues(alpha: 0.06),
                        width: 0.5,
                      ),
                    ),
                    child: TextField(
                      controller: _nameController,
                      focusNode: _nameFocusNode,
                      textAlign: TextAlign.center,
                      autocorrect: false,
                      enableSuggestions: false,
                      maxLength: 12,
                      // 키보드 올라올 때 Flutter가 TextField를 viewport에 맞춰
                      // auto-scroll하는데 기본은 TF 바닥을 viewport 바닥에 정확히
                      // 붙임 → 그 아래 sticky 버튼과 거의 닿음. scrollPadding으로
                      // TF 주변 visible buffer 확보.
                      scrollPadding: const EdgeInsets.only(bottom: 80),
                      style: AppTypography.body(15).copyWith(
                        color: context.colors.foreground,
                      ),
                      buildCounter: (_,
                              {required currentLength,
                              required isFocused,
                              required maxLength}) =>
                          null,
                      decoration: InputDecoration(
                        hintText: 'Your name (max 12)',
                        hintStyle: AppTypography.body(15).copyWith(
                          color: context.colors.foregroundMuted
                              .withValues(alpha: 0.4),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 고정 Continue 버튼 — body의 마지막 child라 키보드 위에 항상 보임.
          Padding(
            padding: EdgeInsets.fromLTRB(
              32,
              0,
              32,
              padding.bottom + 16,
            ),
            child: SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: (_hasName && !_saving) ? _continue : null,
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
                              'Continue',
                              style: AppTypography.body(15,
                                      weight: FontWeight.w600)
                                  .copyWith(
                                      color: context.colors.background),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
