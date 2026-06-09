import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_urls.dart';
import '../../core/theme/app_colors_ext.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_toast.dart';
import '../../l10n/app_localizations.dart';
import '../content/contents_view_model.dart';
import '../content/models/content.dart';
import '../home/home_view_model.dart';
import '../home/models/scene.dart';
import '../home/widgets/detail_app_bar.dart';
import '../home/widgets/moment_selection_screen.dart';
import '../home/widgets/scene_row_tile.dart';
import 'data/share_repository.dart';
import 'share_view_model.dart';
import 'widgets/set_share_slug_sheet.dart';

/// 공유 관리(상세) 화면.
///
/// 최소 정보만 표시한다:
///   1. 공유 주소 카드 — "your address" 라벨 + URL 복사(id 없으면 "id 설정 필요"),
///      그리고 같은 카드 안에 id 변경 진입(id 있을 때만).
///   2. 안내 — 공유 노출은 각 Scene에서 개별 설정.
class ShareSettingsScreen extends ConsumerStatefulWidget {
  const ShareSettingsScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(
      builder: (_) => const ShareSettingsScreen(),
    );
  }

  @override
  ConsumerState<ShareSettingsScreen> createState() =>
      _ShareSettingsScreenState();
}

class _ShareSettingsScreenState extends ConsumerState<ShareSettingsScreen> {
  double _borderOpacity = 0.0;

  bool _onScroll(ScrollNotification n) {
    final border = (n.metrics.pixels / 20).clamp(0.0, 1.0);
    if ((border - _borderOpacity).abs() > 0.01) {
      setState(() => _borderOpacity = border);
    }
    return false;
  }

  void _openSheet({String? currentSlug}) {
    SetShareSlugSheet.show(context: context, currentSlug: currentSlug);
  }

  Future<void> _copy(String slug) async {
    await Clipboard.setData(
      ClipboardData(text: AppUrls.shareFullUrl(slug)),
    );
    if (mounted) {
      AppToast.show(context, AppLocalizations.of(context).shareLinkCopied);
    }
  }

  /// 주소 탭 → 인앱 브라우저(SFSafariViewController / Custom Tabs)로 공유
  /// 페이지 열기.
  Future<void> _open(String slug) async {
    await launchUrl(
      Uri.parse(AppUrls.shareFullUrl(slug)),
      mode: LaunchMode.inAppBrowserView,
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final slugAsync = ref.watch(shareSlugProvider);
    final slug = slugAsync.valueOrNull;
    // 커플/slug 로딩 중인지 — "ID 설정 필요"가 잘못 뜨는 깜빡임 방지용.
    final resolving = slugAsync.isLoading && !slugAsync.hasValue;
    // 최신 Scene이 위로 오도록 역순.
    final scenes =
        ref.watch(homeViewModelProvider.select((s) => s.scenes)).reversed.toList();

    return Scaffold(
      // backgroundColor handled by theme
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: ListView(
              padding: EdgeInsets.only(
                top: padding.top + DetailAppBar.barHeight + 24,
                bottom: padding.bottom + 40,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 공유 주소 카드 (라벨 + 복사 + id 변경)
                      _AddressCard(
                        slug: slug,
                        resolving: resolving,
                        onCopy: slug != null ? () => _copy(slug) : () {},
                        onOpen: slug != null ? () => _open(slug) : () {},
                        onSet: () => _openSheet(),
                        onChange: () => _openSheet(currentSlug: slug),
                      ),
                    ],
                  ),
                ),

                // 3) Scene 목록 — 탭하면 해당 Scene의 공유 대상 콘텐츠 선택
                //    화면(재생 선택과 동일 디자인)으로 이동.
                const SizedBox(height: 24),
                for (final scene in scenes) _ShareSceneRow(scene: scene),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: DetailAppBar(
              topInset: padding.top,
              title: 'Share our Scenes',
              titleOpacity: 1.0,
              borderOpacity: _borderOpacity,
              onClose: () => Navigator.of(context).pop(),
              trailing: const SizedBox.shrink(),
              leading: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: FaIcon(FontAwesomeIcons.chevronLeft,
                        size: 18,
                        color: context.colors.foreground
                            .withValues(alpha: 0.9)),
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

/// 공유 화면의 Scene 한 행. 해당 scene의 콘텐츠를 읽어 `{공유}/{전체}`를 왼쪽에
/// 표시하고, 탭하면 공유 대상 선택 화면([MomentSelectionScreen])으로 이동한 뒤
/// 돌아온 선택을 RPC로 저장한다.
class _ShareSceneRow extends ConsumerWidget {
  const _ShareSceneRow({required this.scene});

  final Scene scene;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contents =
        ref.watch(contentsForSceneProvider(scene.id)).valueOrNull ??
            const <Content>[];
    final sharedIds =
        contents.where((c) => c.shared).map((c) => c.id).toSet();
    final total = scene.media.total;

    return SceneRowTile(
      scene: scene,
      horizontalPadding: 24,
      trailingLabel: '${sharedIds.length}/$total',
      onTap: () async {
        final result = await Navigator.of(context).push(
          MomentSelectionScreen.route(
            sceneIdFilter: {scene.id},
            initiallySelected: sharedIds,
            // 공유는 옵트인 — 빈 선택은 "아무것도 공유 안 함".
            selectAllWhenEmpty: false,
          ),
        );
        if (result == null) return;
        await ref.read(shareRepositoryProvider).setSceneSharedContents(
              sceneId: scene.id,
              sharedIds: result,
            );
        // 카운트 갱신을 위해 해당 scene 콘텐츠 refetch.
        ref.invalidate(contentsForSceneProvider(scene.id));
      },
    );
  }
}

/// 카드 안에서 URL/프롬프트를 감싸는 둥근 inner 컨테이너(chip). 프로필 카드의
/// URL chip과 동일한 스타일을 공유해 앱 전반과 일관성을 유지.
class _AddressChip extends StatelessWidget {
  const _AddressChip({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: AppRadii.smBorder,
        color: context.colors.foreground.withValues(alpha: 0.04),
        border: Border.all(
          color: context.colors.foreground.withValues(alpha: 0.06),
          width: 0.5,
        ),
      ),
      child: child,
    );
  }
}

/// 공유 주소 카드. "your address" 라벨 아래에 복사 영역, 그리고 같은 카드 안에
/// id 변경 진입까지 묶는다.
///   * id 있음 → URL + 복사 아이콘, 하단에 divider + "change id" 행.
///   * id 없음 → "id 설정 필요" + chevron(탭하면 설정 시트).
class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.slug,
    required this.resolving,
    required this.onCopy,
    required this.onOpen,
    required this.onSet,
    required this.onChange,
  });

  /// 현재 닉네임(id). null이면 미설정.
  final String? slug;

  /// 커플/slug를 아직 불러오는 중. true면 "ID 설정 필요" 대신 로딩 표시.
  final bool resolving;
  final VoidCallback onCopy;
  final VoidCallback onOpen;
  final VoidCallback onSet;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final slug = this.slug;
    final hasSlug = slug != null && slug.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: context.colors.clickableArea,
        borderRadius: AppRadii.mdBorder,
        border: Border.all(
          color: context.colors.foreground.withValues(alpha: 0.06),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.shareAddressLabel,
            style: AppTypography.body(12).copyWith(
              color: context.colors.foregroundMuted,
            ),
          ),
          const SizedBox(height: 10),

          // 복사 영역 (or 설정 필요) — 카드 안 둥근 inner 컨테이너(chip)로 감쌈.
          // 프로필 카드의 URL chip과 동일 스타일(sm radius, foreground 0.04).
          if (hasSlug)
            _AddressChip(
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onOpen,
                      child: Text(
                        AppUrls.shareDisplayUrl(slug),
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body(15).copyWith(
                          color: context.colors.foreground,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onCopy,
                    child: FaIcon(
                      FontAwesomeIcons.solidCopy,
                      size: 15,
                      color: context.colors.foreground.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            )
          else if (resolving)
            // 로딩 중 — "ID 설정 필요" 대신 작은 스피너만(잘못된 미설정 표시 방지).
            _AddressChip(
              child: SizedBox(
                height: 20,
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.colors.foregroundMuted,
                    ),
                  ),
                ),
              ),
            )
          else
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onSet,
              child: _AddressChip(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.shareIdSetNeeded,
                        style: AppTypography.body(15).copyWith(
                          color: context.colors.foregroundMuted,
                        ),
                      ),
                    ),
                    FaIcon(
                      FontAwesomeIcons.chevronRight,
                      size: 14,
                      color: context.colors.foreground.withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ),
            ),

          // id 변경 — 같은 카드 안, divider로 구분 (id 있을 때만)
          if (hasSlug) ...[
            const SizedBox(height: 14),
            Container(
              height: 0.5,
              color: context.colors.foreground.withValues(alpha: 0.06),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onChange,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.shareIdChange,
                        style: AppTypography.body(14, weight: FontWeight.w500)
                            .copyWith(color: context.colors.foreground),
                      ),
                    ),
                    FaIcon(
                      FontAwesomeIcons.chevronRight,
                      size: 13,
                      color: context.colors.foreground.withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
