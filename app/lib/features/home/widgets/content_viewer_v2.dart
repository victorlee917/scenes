import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/data/location_label_cache.dart';
import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/floating_action_sheet.dart';
import '../../../core/widgets/floating_bottom_sheet.dart';
import '../../content/contents_view_model.dart';
import '../../content/data/content_repository.dart';
import '../../content/models/reaction.dart';
import '../../content/reactions_view_model.dart';
import '../../content/widgets/reaction_bar.dart';
import '../../content/widgets/reaction_picker_sheet.dart';
import '../../content/models/content.dart';
import '../../content/widgets/moment_date_picker_sheet.dart';
import '../../content/widgets/source_badge.dart';
import '../../couple/couple_view_model.dart';
import '../../profile/profile_view_model.dart';
import '../../scene/scenes_view_model.dart';
import '../../../l10n/app_localizations.dart';
import 'scene_title_fallback.dart';

/// 콘텐츠 뷰어 v2.
///
/// 레이아웃: 앱바 → 콘텐츠 박스 → 정보+좋아요 → 가로 dial.
/// 모든 메타데이터는 [contents] 리스트의 각 Content.payload에서 직접 derive.
class ContentViewerV2 extends ConsumerStatefulWidget {
  const ContentViewerV2({
    super.key,
    required this.contents,
    required this.initialIndex,
    this.sceneImageUrl,
    this.sceneName,
    this.uploadedAt,
  });

  /// 표시할 contents — type/payload/signed URL 모두 여기서 읽음.
  final List<Content> contents;
  final int initialIndex;
  final String? sceneImageUrl;
  final String? sceneName;
  final DateTime? uploadedAt;

  static Future<void> show({
    required BuildContext context,
    required List<Content> contents,
    required int initialIndex,
    String? sceneImageUrl,
    String? sceneName,
    DateTime? uploadedAt,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) =>
            ContentViewerV2(
              contents: contents,
              initialIndex: initialIndex,
              sceneImageUrl: sceneImageUrl,
              sceneName: sceneName,
              uploadedAt: uploadedAt,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          );
        },
      ),
    );
  }

  @override
  ConsumerState<ContentViewerV2> createState() => _ContentViewerV2State();
}

class _ContentViewerV2State extends ConsumerState<ContentViewerV2> {
  late int _currentIndex;
  // 삭제 시 widget.contents가 아닌 local mutable 리스트를 갱신해 viewer가
  // 즉시 다음/이전 콘텐츠를 표시할 수 있게.
  late List<Content> _contents;
  bool _showInfo = false;
  // 드래그 시각 상태: (시각 오프셋, 드래그 중 여부). ValueNotifier로 들고
  // 있어 드래그 중엔 변환 래퍼만 rebuild되고 Scaffold 본문은 그대로 둔다.
  // 시각 오프셋은 _dragDeadband를 넘어 당겨야 0보다 커진다.
  final ValueNotifier<(double, bool)> _drag = ValueNotifier((0.0, false));
  // 누적 raw drag dy. 데드밴드 판정용 — 손가락 이동량 자체.
  double _dragRaw = 0;
  // 처음 이만큼은 시각적으로 반응하지 않음 — 의도되지 않은 미세 스크롤이
  // 화면을 흐리게 만드는 걸 방지.
  static const double _dragDeadband = 60;

  @override
  void initState() {
    super.initState();
    _contents = List.of(widget.contents);
    _currentIndex = widget.initialIndex;
  }

  @override
  void dispose() {
    _drag.dispose();
    super.dispose();
  }

  /// 현재 표시 중인 Content. payload에서 type별 메타를 derive할 때 시작점.
  Content get _current => _contents[_currentIndex];

  String get _currentMediaType => _current.type;

  /// likes provider key — 모든 contents가 같은 scene에 속한다는 가정 하에
  /// 현재 콘텐츠의 sceneId 사용.
  String get _sceneId => _current.sceneId;

  /// 현재 콘텐츠에 본인의 리액션 추가/수정/제거 시트 호출.
  Future<void> _openReactionPicker() async {
    HapticFeedback.selectionClick();
    final myId = ref.read(myProfileProvider).valueOrNull?.id;
    if (myId == null) return;
    final reactions =
        ref
            .read(reactionsForSceneProvider(_sceneId))
            .valueOrNull?[_current.id] ??
        const <Reaction>[];
    Reaction? mine;
    for (final r in reactions) {
      if (r.userId == myId) {
        mine = r;
        break;
      }
    }
    final contentId = _current.id;

    await FloatingBottomSheet.show<void>(
      context: context,
      builder: (_) => ReactionPickerSheet(
        initialEmoji: mine?.emoji,
        initialComment: mine?.comment,
        onSubmit: (emoji, comment) async {
          try {
            await ref
                .read(reactionsForSceneProvider(_sceneId).notifier)
                .setMyReaction(
                  userId: myId,
                  contentId: contentId,
                  emoji: emoji,
                  comment: comment,
                );
          } catch (_) {
            if (mounted) {
              AppToast.show(
                context,
                AppLocalizations.of(context).reactionSaveFailed,
              );
            }
          }
        },
        onRemove: () async {
          try {
            await ref
                .read(reactionsForSceneProvider(_sceneId).notifier)
                .removeMyReaction(userId: myId, contentId: contentId);
          } catch (_) {
            if (mounted) {
              AppToast.show(
                context,
                AppLocalizations.of(context).reactionRemoveFailed,
              );
            }
          }
        },
      ),
    );
  }

  /// active 페어 멤버는 누가 올렸든 ellipsis 메뉴 / 삭제 / moment date 수정
  /// 가능. RLS도 동일하게 페어 단위 권한.
  bool get _canDelete => true;

  String _mediaTypeLabel(AppLocalizations l10n, String type) {
    switch (type) {
      case 'photo':
        return l10n.mediaLabelPhoto;
      case 'film':
        return l10n.mediaLabelFilm;
      case 'music':
        return l10n.mediaLabelMusic;
      case 'place':
        return l10n.mediaLabelPlace;
    }
    return type;
  }

  /// 현재 콘텐츠의 작성자 표시 이름.
  ///
  /// `created_by` UUID를 본인/파트너 프로필로 매핑:
  /// - 본인 = `myProfileProvider`의 이름 그대로
  /// - 파트너 = `activeCouple.partner.name`. 파트너가 탈퇴 상태(deletedAt != null)
  ///   이면 l10n `profileDeletedUserName`으로 마스킹
  /// - 어느 쪽에도 매핑 안 되면 null (예: 옛 파트너의 콘텐츠인데 active couple
  ///   이 다른 사람이거나, 데이터가 stale한 경우 등) — UI에서 빈 행 처리.
  String? _resolveUploaderName(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final myProfile = ref.watch(myProfileProvider).valueOrNull;
    final activeCouple = ref.watch(activeCoupleProvider).valueOrNull;
    final createdBy = _current.createdBy;
    if (createdBy == null) return null;
    if (myProfile != null && myProfile.id == createdBy) {
      return myProfile.isDeleted ? l10n.profileDeletedUserName : myProfile.name;
    }
    final partner = activeCouple?.partner;
    if (partner != null && partner.id == createdBy) {
      return partner.isDeleted ? l10n.profileDeletedUserName : partner.name;
    }
    return null;
  }

  /// 작성자가 occurred_at(moment date) 사후 수정. 시트에서 confirm하면 repo
  /// update + local _contents + provider state 모두 갱신해 viewer/그리드가
  /// 즉시 반영. delete와 비슷한 흐름이지만 row를 보존한 채 필드만 교체.
  void _showMomentDatePicker() {
    if (!_canDelete) return;
    final initial = _current.occurredAt ?? _current.createdAt;
    final contentToEdit = _current;
    FloatingBottomSheet.show(
      context: context,
      builder: (_) => MomentDatePickerSheet(
        initialDate: initial,
        onConfirm: (date) async {
          Navigator.of(context).pop();
          try {
            await ref
                .read(contentRepositoryProvider)
                .updateOccurredAt(contentToEdit.id, date);
            if (!mounted) return;
            final updated = contentToEdit.copyWith(occurredAt: date);
            // 1) viewer local state.
            setState(() {
              _contents = _contents
                  .map((c) => c.id == updated.id ? updated : c)
                  .toList(growable: false);
            });
            // 2) scene detail 그리드 watch가 보는 provider 동기화.
            ref
                .read(contentsForSceneProvider(_sceneId).notifier)
                .replaceContent(updated);
          } catch (_) {
            if (!mounted) return;
            AppToast.show(
              context,
              AppLocalizations.of(context).contentDetailUpdateDateFailed,
            );
          }
        },
      ),
    );
  }

  void _handleMoreActions() {
    final l10n = AppLocalizations.of(context);
    FloatingActionSheet.show(
      context: context,
      items: [
        FloatingActionItem(
          label: l10n.actionDelete,
          isDestructive: true,
          onTap: () async {
            final removingIndex = _currentIndex;
            final content = _current;
            final sceneId = _sceneId;
            final confirmed = await ConfirmDialog.show(
              context: context,
              title: 'Delete this moment?',
              message: l10n.contentDetailDeleteMessage,
              confirmLabel: l10n.actionDelete,
              isDestructive: true,
            );
            if (!confirmed || !mounted) return;
            try {
              await ref
                  .read(contentRepositoryProvider)
                  .deleteContent(content);
              if (!mounted) return;
              // contents 리스트에서 즉시 제거 — scene detail 그리드 watch가
              // 이 변화를 받아 그리드 셀이 빠짐.
              ref
                  .read(contentsForSceneProvider(sceneId).notifier)
                  .removeContent(content.id);
              // scene_summary 뷰의 media count badge가 stale로 안 남게
              // scenesProvider도 동기 refresh — 다른 화면(홈/리스트) 모두
              // 즉시 반영.
              await ref.read(scenesProvider.notifier).softRefresh();
              if (!mounted) return;

              // viewer 자체는 유지 — 이전 인덱스로 이동(없으면 다음, 둘 다
              // 없으면 pop). _contents는 삭제된 row 빠진 새 list로 교체.
              final newList = List.of(_contents)..removeAt(removingIndex);
              if (newList.isEmpty) {
                Navigator.of(context).pop();
                return;
              }
              setState(() {
                _contents = newList;
                _currentIndex = removingIndex > 0 ? removingIndex - 1 : 0;
                _showInfo = false;
              });
            } catch (_) {
              if (!mounted) return;
              AppToast.show(
                context,
                AppLocalizations.of(context).contentDetailDeleteFailed,
              );
            }
          },
        ),
      ],
    );
  }

  /// 현재 콘텐츠의 메인 표시 URL. photo는 full size, film은 cached poster,
  /// music은 Spotify CDN, place는 cached static map. 모두 ContentRepository
  /// 가 fullSignedUrl 슬롯에 채워둠.
  String _contentImageUrl() => _current.fullSignedUrl ?? '';

  Widget _buildContent(BuildContext context) {
    final infoOverlay = _showInfo ? _ContentInfo(content: _current) : null;
    final url = _contentImageUrl();
    final payload = _current.payload;

    switch (_currentMediaType) {
      case 'film':
        return _FilmContentCard(
          posterUrl: url,
          title: payload['title'] as String?,
          director: payload['director'] as String?,
          imageOverlay: infoOverlay,
        );
      case 'music':
        return _MusicContentCard(
          albumArtUrl: url,
          title: payload['title'] as String?,
          artist: payload['artist'] as String?,
          imageOverlay: infoOverlay,
        );
      case 'place':
        return _PlaceContentCard(
          mapImageUrl: url,
          name: payload['name'] as String?,
          address: payload['address'] as String?,
          imageOverlay: infoOverlay,
        );
      default:
        return _ContentImage(
          url: url,
          index: _currentIndex,
          overlay: infoOverlay,
        );
    }
  }

  /// 이미지 위에 깔리는 dim + meta 컨테이너. 각 콘텐츠 위젯이 이미지 영역
  /// 안에서 공통 형태로 렌더하기 위해 사용.
  static Widget _imageInfoOverlay(BuildContext context, Widget meta) {
    return Container(
      color: context.colors.background.withValues(alpha: 0.8),
      padding: const EdgeInsets.all(24),
      child: Center(child: meta),
    );
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (details.delta.dy > 0 || _dragRaw > 0) {
      _dragRaw = (_dragRaw + details.delta.dy).clamp(
        0.0,
        _dragDeadband + 400.0,
      );
      final offset = (_dragRaw - _dragDeadband).clamp(0.0, 400.0);
      _drag.value = (offset, true);
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    // 빠른 flick은 데드밴드를 분명히 넘긴 경우에만 pop으로 인정 — 짧은
    // 우연의 plus-flick으로 화면이 닫히지 않도록.
    final offset = _drag.value.$1;
    final fastFlick = offset > 0 &&
        details.primaryVelocity != null &&
        details.primaryVelocity! > 800;
    if (offset > 120 || fastFlick) {
      Navigator.of(context).pop();
    } else {
      _dragRaw = 0;
      _drag.value = (0.0, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();

    // Scaffold 본문은 드래그와 무관 — _DragDismissTransform의 child로 한 번만
    // 빌드되어 드래그 중엔 rebuild되지 않는다. translate/scale/opacity/radius
    // 시각 효과만 _drag notifier에 반응해 갱신.
    return GestureDetector(
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onVerticalDragEnd: _onVerticalDragEnd,
      child: _DragDismissTransform(
        drag: _drag,
        child: Scaffold(
          body: Column(
            children: [
              // ── 앱바 영역 ──────────────────────────────────────
              SizedBox(height: padding.top + 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // 좌: 캐니스터 사진 + 제목 + 매체. 홈/picker와 동일하게
                    // cover URL 없거나 로드 실패 시 타이틀 첫 글자 fallback.
                    ClipOval(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: () {
                          final url = widget.sceneImageUrl;
                          final title = widget.sceneName ?? '';
                          if (url == null || url.isEmpty) {
                            return SceneTitleFallback(title: title);
                          }
                          return Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                SceneTitleFallback(title: title),
                          );
                        }(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // 좌측 텍스트 영역 — 길어지면 ellipsis. Expanded로 잡아야
                    // 우측 index/X pill을 밀어내지 않음.
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.sceneName != null)
                            Text(
                              widget.sceneName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.body(
                                13,
                                weight: FontWeight.w600,
                              ).copyWith(color: context.colors.foreground),
                            ),
                          Text(
                            _mediaTypeLabel(l10n, _currentMediaType),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body(
                              11,
                            ).copyWith(color: context.colors.foregroundMuted),
                          ),
                        ],
                      ),
                    ),
                    // 좌측 텍스트와 우측 pill 사이 여백.
                    const SizedBox(width: 12),
                    // 우: 인덱스 · X pill. 인덱스 영역은 비활성, X 아이콘 영역만
                    // 누르면 닫힘. (실수 탭으로 viewer가 사라지는 경우 방지)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: context.colors.foreground.withValues(
                              alpha: 0.06,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: Text(
                                  '${_currentIndex + 1}/${_contents.length}',
                                  style: AppTypography.body(11).copyWith(
                                    color: context.colors.foreground
                                        .withValues(alpha: 0.9),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Container(
                                  width: 3,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: context.colors.foreground
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                              ),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => Navigator.of(context).pop(),
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    left: 4,
                                    right: 12,
                                    top: 4,
                                    bottom: 4,
                                  ),
                                  child: FaIcon(
                                    FontAwesomeIcons.xmark,
                                    size: 11,
                                    color: context.colors.foreground
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── 콘텐츠 박스 ────────────────────────────────────
              // 콘텐츠/바깥 영역 모두 탭 좌/우 절반 기준으로 인덱스 이동.
              // 가로 스와이프도 처리. 메타 정보 토글은 하단 썸네일 dial에서
              // 현재 인덱스를 다시 탭했을 때만 동작.
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final halfWidth = constraints.maxWidth / 2;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) {
                        if (details.localPosition.dx < halfWidth) {
                          if (_currentIndex > 0) {
                            setState(() {
                              _currentIndex--;
                              _showInfo = false;
                            });
                            HapticFeedback.selectionClick();
                          }
                        } else {
                          if (_currentIndex < _contents.length - 1) {
                            setState(() {
                              _currentIndex++;
                              _showInfo = false;
                            });
                            HapticFeedback.selectionClick();
                          }
                        }
                      },
                      onHorizontalDragEnd: (details) {
                        final velocity = details.primaryVelocity ?? 0;
                        if (velocity < -300 &&
                            _currentIndex < _contents.length - 1) {
                          setState(() {
                            _currentIndex++;
                            _showInfo = false;
                          });
                          HapticFeedback.selectionClick();
                        } else if (velocity > 300 && _currentIndex > 0) {
                          setState(() {
                            _currentIndex--;
                            _showInfo = false;
                          });
                          HapticFeedback.selectionClick();
                        }
                      },
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxHeight: 500,
                            ),
                            child: _buildContent(context),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // ── 정보 + 좋아요 ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Builder(
                            builder: (ctx) {
                              // 현재 콘텐츠 작성자 이름. created_by를 본인/파트너
                              // 프로필로 매핑하고, 탈퇴된 파트너면 l10n 라벨로
                              // 마스킹. partner profile은 active couple에서만 로드
                              // 되므로 abandoned 케이스는 archive UI 도입 전엔 도달
                              // 불가지만 future-proof 마스킹 적용.
                              final name = _resolveUploaderName(ctx);
                              if (name == null || name.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return Text(
                                name,
                                style:
                                    AppTypography.body(
                                      14,
                                      weight: FontWeight.w500,
                                    ).copyWith(
                                      color: context.colors.foreground,
                                    ),
                              );
                            },
                          ),
                          const SizedBox(height: 2),
                          // occurredAt(촬영/방문 시점) 우선, 없으면 createdAt
                          // (콘텐츠가 scene에 추가된 시점)으로 fallback. photo는
                          // EXIF taken_at이 occurredAt에 들어가 있고, film/music/
                          // place는 occurredAt이 null이라 자동으로 게시된 날짜.
                          // 작성자 본인이면 탭으로 picker 열어서 수정 가능.
                          GestureDetector(
                            onTap: _canDelete
                                ? _showMomentDatePicker
                                : null,
                            behavior: HitTestBehavior.opaque,
                            child: Text(
                              DateFormat.yMMMMd(locale).format(
                                _current.occurredAt ?? _current.createdAt,
                              ),
                              style: AppTypography.body(12).copyWith(
                                color: context.colors.foregroundMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ReactionBar(
                      contentId: _current.id,
                      sceneId: _sceneId,
                      onTapMyReaction: _openReactionPicker,
                    ),
                    if (_canDelete) ...[
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: _handleMoreActions,
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: Center(
                            child: FaIcon(
                              FontAwesomeIcons.ellipsis,
                              size: 18,
                              color: context.colors.foregroundMuted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── 썸네일 dial ──────────────────────────────────────
              SizedBox(
                height: 64,
                child: _ThumbnailDial(
                  contents: _contents,
                  currentIndex: _currentIndex,
                  onIndexChanged: (i) {
                    setState(() {
                      if (i == _currentIndex) {
                        // 같은 인덱스 다시 탭 → 메타 정보 토글.
                        _showInfo = !_showInfo;
                      } else {
                        _currentIndex = i;
                        _showInfo = false;
                      }
                    });
                    HapticFeedback.selectionClick();
                  },
                ),
              ),

              // 썸네일 dial 가운데(=선택된 thumb) 아래에 고정 dot. dial이 항상 선택
              // 항목을 중앙으로 스냅하므로 dot은 움직일 필요 없이 정중앙에 고정.
              // 단일 콘텐츠면 표기 의미가 없어 숨김.
              if (_contents.length > 1) ...[
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.colors.foregroundMuted,
                    ),
                  ),
                ),
              ],

              SizedBox(height: padding.bottom + 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// 아래로 당겨 닫기 제스처의 시각 효과(translate/scale/opacity/radius)를
/// 적용하는 래퍼.
///
/// [drag] notifier만 듣고 [child](= viewer 본문)는 그대로 통과시키므로,
/// 드래그 중엔 이 래퍼만 rebuild되고 본문 트리는 rebuild되지 않는다.
class _DragDismissTransform extends StatelessWidget {
  const _DragDismissTransform({required this.drag, required this.child});

  /// (시각 오프셋, 드래그 중 여부).
  final ValueListenable<(double, bool)> drag;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<(double, bool)>(
      valueListenable: drag,
      child: child,
      builder: (context, value, child) {
        final (offset, dragging) = value;
        final progress = (offset / 300).clamp(0.0, 1.0);
        final scale = 1.0 - progress * 0.1;
        final radius = progress * AppRadii.lg;
        return AnimatedContainer(
          duration:
              dragging ? Duration.zero : const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          transformAlignment: Alignment.topCenter,
          transform: Matrix4.identity()
            // ignore: deprecated_member_use
            ..translate(0.0, offset)
            // ignore: deprecated_member_use
            ..scale(scale),
          child: Opacity(
            opacity: (1.0 - progress).clamp(0.0, 1.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: child,
            ),
          ),
        );
      },
    );
  }
}


// ── 콘텐츠 정보 오버레이 (dimmed 위 center) ──────────────────

class _ContentInfo extends StatelessWidget {
  const _ContentInfo({required this.content});

  final Content content;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final p = content.payload;
    final mutedStyle = AppTypography.body(
      13,
    ).copyWith(color: context.colors.foregroundMuted);

    Widget pill(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: context.colors.foreground.withValues(alpha: 0.1),
      ),
      child: Text(
        text,
        style: AppTypography.body(
          11,
        ).copyWith(color: context.colors.foreground),
      ),
    );

    Widget line(String text) =>
        Text(text, textAlign: TextAlign.center, style: mutedStyle);

    switch (content.type) {
      case 'film':
        final kind = (p['media_type'] as String?) ?? 'movie';
        final kindLabel = kind == 'tv'
            ? l10n.contentDetailFilmTvSeries
            : l10n.contentDetailFilmMovie;
        final genres =
            (p['genres'] as List?)?.whereType<String>().toList() ??
            const <String>[];
        final year = p['release_year'];
        final runtime = p['runtime'];
        final detailParts = <String>[
          if (year != null) year.toString(),
          if (runtime is int) l10n.runtimeMinutesValueSpaced(runtime),
        ];
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            pill(kindLabel),
            if (genres.isNotEmpty) ...[
              const SizedBox(height: 8),
              line(genres.join(' / ')),
            ],
            if (detailParts.isNotEmpty) ...[
              const SizedBox(height: 8),
              line(detailParts.join('  ·  ')),
            ],
          ],
        );
      case 'music':
        final kind = (p['kind'] as String?) ?? 'track';
        final isTrack = kind == 'track';
        final album = p['album'] as String?;
        final year = p['year'] as String?;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            pill(isTrack
                ? l10n.contentDetailMusicTrack
                : l10n.contentDetailMusicAlbum),
            if (isTrack && album != null && album.isNotEmpty) ...[
              const SizedBox(height: 8),
              line(album),
            ],
            if (year != null && year.isNotEmpty) ...[
              const SizedBox(height: 8),
              line(year),
            ],
          ],
        );
      case 'place':
        final region = p['region'] as String?;
        final country = p['country'] as String?;
        final regionLine = [
          region,
          country,
        ].whereType<String>().where((s) => s.isNotEmpty).join(', ');
        final lat = p['lat'];
        final lng = p['lng'];
        final address = p['address'] as String?;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (regionLine.isNotEmpty) ...[
              pill(regionLine),
              const SizedBox(height: 8),
            ],
            if (address != null && address.isNotEmpty) line(address),
            if (lat is num && lng is num) ...[
              const SizedBox(height: 8),
              line(
                '${lat.toDouble().toStringAsFixed(4)}°, '
                '${lng.toDouble().toStringAsFixed(4)}°',
              ),
            ],
          ],
        );
      default:
        // photo — EXIF 기반 메타 (촬영 시간, 위치, 크기). 없는 필드는 omit.
        final width = (p['width'] as num?)?.toInt();
        final height = (p['height'] as num?)?.toInt();
        final takenAtRaw = p['taken_at'] as String?;
        final taken = takenAtRaw != null ? DateTime.tryParse(takenAtRaw) : null;
        final lat = p['lat'];
        final lng = p['lng'];
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (lat is num && lng is num) ...[
              _PhotoLocationLine(
                lat: lat.toDouble(),
                lng: lng.toDouble(),
                style: mutedStyle,
              ),
              const SizedBox(height: 8),
            ],
            if (taken != null) ...[
              line(DateFormat.yMMMd(locale).add_jm().format(taken)),
              const SizedBox(height: 8),
            ],
            if (width != null && height != null) line('$width × $height'),
          ],
        );
    }
  }
}

/// EXIF 좌표를 OS native reverse geocoder(iOS CLGeocoder / Android Geocoder)
/// 로 사람이 읽는 주소로 변환해 표시. 캐시 hit이면 첫 frame부터 주소,
/// miss이면 좌표 보였다가 async resolve 후 주소로 swap. 한 번 resolve된
/// 라벨은 state에 들고 있어 parent rebuild 시에도 재해석 없이 표시.
class _PhotoLocationLine extends ConsumerStatefulWidget {
  const _PhotoLocationLine({
    required this.lat,
    required this.lng,
    required this.style,
  });

  final double lat;
  final double lng;
  final TextStyle style;

  @override
  ConsumerState<_PhotoLocationLine> createState() => _PhotoLocationLineState();
}

class _PhotoLocationLineState extends ConsumerState<_PhotoLocationLine> {
  String? _label;

  @override
  void initState() {
    super.initState();
    _resolveLabel();
  }

  @override
  void didUpdateWidget(_PhotoLocationLine old) {
    super.didUpdateWidget(old);
    if (old.lat != widget.lat || old.lng != widget.lng) {
      // 다른 사진의 좌표로 위젯 재사용된 케이스 — 라벨 다시 풀기.
      _label = null;
      _resolveLabel();
    }
  }

  Future<void> _resolveLabel() async {
    final cache = ref.read(locationLabelCacheProvider);
    // 동기 hit이면 즉시 set — FutureBuilder 같은 한 frame 좌표 깜빡임 없음.
    final hit = cache.peek(widget.lat, widget.lng);
    if (hit != null) {
      setState(() => _label = hit);
      return;
    }
    // miss — async resolve. 결과 도착 사이 widget이 unmount되거나 lat/lng가
    // 다른 좌표로 바뀌었으면 무시.
    final lat = widget.lat;
    final lng = widget.lng;
    final result = await cache.labelFor(lat, lng);
    if (!mounted) return;
    if (widget.lat != lat || widget.lng != lng) return;
    setState(() => _label = result);
  }

  String get _coordsFallback =>
      '${widget.lat.toStringAsFixed(4)}°, ${widget.lng.toStringAsFixed(4)}°';

  @override
  Widget build(BuildContext context) {
    final text = (_label != null && _label!.isNotEmpty)
        ? _label!
        : _coordsFallback;
    return Text(text, textAlign: TextAlign.center, style: widget.style);
  }
}

// ── 영화 콘텐츠 카드 (포스터 + 제목 + 감독, 단순 레이아웃) ─────

class _FilmContentCard extends StatelessWidget {
  const _FilmContentCard({
    required this.posterUrl,
    this.title,
    this.director,
    this.imageOverlay,
  });

  final String posterUrl;
  final String? title;
  final String? director;

  /// 포스터 위에만 덮이는 dim + 메타 오버레이. null이면 미적용.
  final Widget? imageOverlay;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: AppRadii.smBorder,
          child: SizedBox(
            width: 280,
            height: 420,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  posterUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: context.colors.nonClickableArea,
                    child: Center(
                      child: FaIcon(
                        FontAwesomeIcons.film,
                        size: 40,
                        color: context.colors.foregroundMuted,
                      ),
                    ),
                  ),
                ),
                if (imageOverlay != null) ...[
                  _ContentViewerV2State._imageInfoOverlay(
                    context,
                    imageOverlay!,
                  ),
                  const Positioned(top: 10, right: 10, child: TmdbBadge()),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (title != null && title!.isNotEmpty)
          Text(
            title!,
            textAlign: TextAlign.center,
            style: AppTypography.body(
              17,
              weight: FontWeight.w600,
            ).copyWith(color: context.colors.foreground),
          ),
        if (director != null && director!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            director!,
            textAlign: TextAlign.center,
            style: AppTypography.body(
              13,
            ).copyWith(color: context.colors.foregroundMuted),
          ),
        ],
      ],
    );
  }
}

// ── 음악 콘텐츠 카드 (앨범아트 + 제목 + 아티스트, 단순 레이아웃) ─

class _MusicContentCard extends StatelessWidget {
  const _MusicContentCard({
    required this.albumArtUrl,
    this.title,
    this.artist,
    this.imageOverlay,
  });

  final String albumArtUrl;
  final String? title;
  final String? artist;

  /// 앨범아트 위에만 덮이는 dim + 메타 오버레이. null이면 미적용.
  final Widget? imageOverlay;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: AppRadii.smBorder,
          child: SizedBox(
            width: 300,
            height: 300,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  albumArtUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: context.colors.nonClickableArea,
                    child: Center(
                      child: FaIcon(
                        FontAwesomeIcons.music,
                        size: 40,
                        color: context.colors.foregroundMuted,
                      ),
                    ),
                  ),
                ),
                if (imageOverlay != null) ...[
                  _ContentViewerV2State._imageInfoOverlay(
                    context,
                    imageOverlay!,
                  ),
                  const Positioned(top: 10, right: 10, child: SpotifyBadge()),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (title != null && title!.isNotEmpty)
          Text(
            title!,
            textAlign: TextAlign.center,
            style: AppTypography.body(
              17,
              weight: FontWeight.w600,
            ).copyWith(color: context.colors.foreground),
          ),
        if (artist != null && artist!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            artist!,
            textAlign: TextAlign.center,
            style: AppTypography.body(
              13,
            ).copyWith(color: context.colors.foregroundMuted),
          ),
        ],
      ],
    );
  }
}

// ── 장소 콘텐츠 카드 (지도 + 장소명 + 주소, 단순 레이아웃) ─────

class _PlaceContentCard extends StatelessWidget {
  const _PlaceContentCard({
    required this.mapImageUrl,
    this.name,
    this.address,
    this.imageOverlay,
  });

  final String mapImageUrl;
  final String? name;
  final String? address;

  /// 지도 이미지 위에만 덮이는 dim + 메타 오버레이.
  final Widget? imageOverlay;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: AppRadii.smBorder,
          child: SizedBox(
            width: 320,
            height: 320,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  mapImageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: context.colors.nonClickableArea,
                    child: Center(
                      child: FaIcon(
                        FontAwesomeIcons.locationDot,
                        size: 40,
                        color: context.colors.foregroundMuted,
                      ),
                    ),
                  ),
                ),
                if (imageOverlay != null) ...[
                  _ContentViewerV2State._imageInfoOverlay(
                    context,
                    imageOverlay!,
                  ),
                  const Positioned(top: 10, right: 10, child: MapboxBadge()),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (name != null && name!.isNotEmpty)
          Text(
            name!,
            textAlign: TextAlign.center,
            style: AppTypography.body(
              17,
              weight: FontWeight.w600,
            ).copyWith(color: context.colors.foreground),
          ),
        if (address != null && address!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            address!,
            textAlign: TextAlign.center,
            style: AppTypography.body(
              13,
            ).copyWith(color: context.colors.foregroundMuted),
          ),
        ],
      ],
    );
  }
}

// ── 콘텐츠 이미지 (비율 유지 + radius) ────────────────────────

class _ContentImage extends StatefulWidget {
  const _ContentImage({required this.url, required this.index, this.overlay});

  final String url;
  final int index;

  /// 이미지 위에 덮이는 dim + 메타. null이면 미적용.
  final Widget? overlay;

  @override
  State<_ContentImage> createState() => _ContentImageState();
}

class _ContentImageState extends State<_ContentImage> {
  double? _aspectRatio;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(_ContentImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _aspectRatio = null;
      _failed = false;
      _resolve();
    }
  }

  void _resolve() {
    final provider = NetworkImage(widget.url);
    final stream = provider.resolve(ImageConfiguration.empty);
    stream.addListener(
      ImageStreamListener(
        (info, _) {
          if (mounted) {
            setState(() {
              _aspectRatio =
                  info.image.width.toDouble() / info.image.height.toDouble();
            });
          }
        },
        onError: (_, __) {
          if (mounted) setState(() => _failed = true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Center(
        child: Text(
          'Content #${widget.index + 1}',
          style: AppTypography.display(
            24,
          ).copyWith(color: context.colors.foregroundMuted),
        ),
      );
    }
    if (_aspectRatio == null) {
      return Center(
        child: CircularProgressIndicator(
          color: context.colors.foreground,
          strokeWidth: 1.5,
        ),
      );
    }
    return AspectRatio(
      aspectRatio: _aspectRatio!,
      child: ClipRRect(
        borderRadius: AppRadii.mdBorder,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              widget.url,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
            if (widget.overlay != null)
              _ContentViewerV2State._imageInfoOverlay(context, widget.overlay!),
          ],
        ),
      ),
    );
  }
}

// ── 썸네일 dial (원통형 곡률 + 좌우 그라데이션) ──────────────

/// dial 썸네일 한 칸. URL이 있으면 Image.network, 없거나 실패 시 type별
/// 아이콘 fallback.
class _ThumbBox extends StatelessWidget {
  const _ThumbBox({required this.url, required this.type});

  final String? url;
  final String type;

  FaIconData _fallbackIcon() {
    switch (type) {
      case 'film':
        return FontAwesomeIcons.film;
      case 'music':
        return FontAwesomeIcons.music;
      case 'place':
        return FontAwesomeIcons.locationDot;
      default:
        return FontAwesomeIcons.solidImage;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: context.colors.nonClickableArea,
      child: Center(
        child: FaIcon(
          _fallbackIcon(),
          size: 16,
          color: context.colors.foregroundMuted,
        ),
      ),
    );
    final u = url;
    if (u == null || u.isEmpty) return fallback;
    return Image.network(
      u,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => fallback,
      // 디코드되기 전에도 슬롯 크기와 동일한 단색 컨테이너가 깔리도록.
      // 사용자가 dial을 처음 펼치거나 캐시 미스 시 아무것도 안 보이는 빈
      // 공간이 한 프레임 떴다가 이미지로 바뀌는 깜빡임을 방지.
      frameBuilder: (context, child, frame, wasSync) {
        if (wasSync || frame != null) return child;
        return ColoredBox(color: context.colors.nonClickableArea);
      },
    );
  }
}

class _ThumbnailDial extends StatefulWidget {
  const _ThumbnailDial({
    required this.contents,
    required this.currentIndex,
    required this.onIndexChanged,
  });

  final List<Content> contents;
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;

  /// 썸네일에 사용할 작은 이미지 URL — 어떤 type이든 thumbSignedUrl 슬롯에
  /// 들어있도록 ContentRepository에서 hydrate해둠. 빈 문자열이면 fallback
  /// (locationDot/film/music 아이콘 박스).
  String? _thumbUrl(int index) => contents[index].thumbSignedUrl;

  String _typeAt(int index) => contents[index].type;

  @override
  State<_ThumbnailDial> createState() => _ThumbnailDialState();
}

class _ThumbnailDialState extends State<_ThumbnailDial> {
  late final ScrollController _scrollController;
  static const double _itemSize = 48;
  static const double _spacing = 8;
  static const double _itemExtent = _itemSize + _spacing;
  int _lastReportedIndex = -1;
  bool _programmaticScroll = false;
  bool _userScrolling = false;

  @override
  void initState() {
    super.initState();
    _lastReportedIndex = widget.currentIndex;
    _scrollController = ScrollController(
      initialScrollOffset: widget.currentIndex * _itemExtent,
    );
    _scrollController.addListener(_onScroll);
    // 최초 레이아웃 후엔 ScrollController.position.haveDimensions가 true가
    // 되지만 컨트롤러는 그 사실을 따로 notify하지 않는다. 초기 곡률
    // transform이 계산되도록 첫 프레임 후 한 번 강제로 rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _onScroll() {
    // user 드래그가 아니면 무조건 무시. 빠른 연타로 animateTo가 새로 시작되면
    // 이전 animateTo의 then()이 _programmaticScroll을 false로 풀어버려 새
    // animation 중간 frame에서 rounded index가 직전 값으로 잡힐 수 있다 →
    // parent에 stale index를 통보해 인덱스가 되돌아가는 race. _userScrolling
    // 가드는 NotificationListener가 드래그 시작/종료에만 set하므로 정확.
    if (!_scrollController.hasClients ||
        _programmaticScroll ||
        !_userScrolling) {
      return;
    }
    final index = (_scrollController.offset / _itemExtent).round().clamp(
      0,
      widget.contents.length - 1,
    );
    if (index != _lastReportedIndex) {
      _lastReportedIndex = index;
      widget.onIndexChanged(index);
    }
  }

  @override
  void didUpdateWidget(_ThumbnailDial old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex && !_userScrolling) {
      _lastReportedIndex = widget.currentIndex;
      _programmaticScroll = true;
      _scrollController
          .animateTo(
            widget.currentIndex * _itemExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          )
          .then((_) => _programmaticScroll = false);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final halfWidth = constraints.maxWidth / 2;
        final sidePadding = halfWidth - _itemSize / 2;

        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: [0.0, 0.25, 0.75, 1.0],
          ).createShader(bounds),
          blendMode: BlendMode.dstIn,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is ScrollStartNotification && n.dragDetails != null) {
                _userScrolling = true;
              } else if (n is ScrollEndNotification) {
                _userScrolling = false;
              }
              return false;
            },
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: sidePadding),
              itemCount: widget.contents.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.only(
                    right: index < widget.contents.length - 1 ? _spacing : 0,
                  ),
                  child: GestureDetector(
                    onTap: () => widget.onIndexChanged(index),
                    child: AnimatedBuilder(
                      animation: _scrollController,
                      builder: (context, child) {
                        double scale = 1.0;
                        double rotateY = 0.0;
                        if (_scrollController.hasClients &&
                            _scrollController.position.haveDimensions) {
                          final itemCenter =
                              index * _itemExtent + _itemSize / 2;
                          final viewCenter =
                              _scrollController.offset + halfWidth;
                          final distance =
                              (itemCenter - viewCenter) / halfWidth;
                          scale = (1.0 - distance.abs() * 0.15).clamp(0.7, 1.0);
                          rotateY = distance * 0.4;
                        }
                        return Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.002)
                            ..rotateY(rotateY)
                            // ignore: deprecated_member_use
                            ..scale(scale),
                          child: child,
                        );
                      },
                      child: ClipRRect(
                        borderRadius: AppRadii.xsBorder,
                        child: SizedBox(
                          width: _itemSize,
                          height: _itemSize,
                          child: _ThumbBox(
                            url: widget._thumbUrl(index),
                            type: widget._typeAt(index),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
