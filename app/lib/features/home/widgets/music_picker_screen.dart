import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../l10n/app_localizations.dart';
import '../../upload/upload_queue_view_model.dart';
import '../models/scene.dart';
import '../models/spotify_hit.dart';
import '../music_picker_view_model.dart';
import 'scene_detail_screen.dart';
import 'search_picker_scaffold.dart';

/// 음악 검색·선택 화면.
///
/// 한 번에 하나의 항목(track 또는 album)만 선택 가능. 입력 → 디바운스 →
/// Spotify 검색. 검색 폼·결과 리스트·선택 상태는 [SearchPickerScaffold]가
/// 담당하고, 이 위젯은 Spotify 특화 부분만 연결한다.
class MusicPickerScreen extends ConsumerWidget {
  const MusicPickerScreen({
    super.key,
    this.scene,
    this.momentDate,
    this.landOnSceneDetail = true,
  });

  final Scene? scene;
  final DateTime? momentDate;
  final bool landOnSceneDetail;

  static Route<void> route({
    Scene? scene,
    DateTime? momentDate,
    bool landOnSceneDetail = true,
  }) {
    return searchPickerRoute(
      MusicPickerScreen(
        scene: scene,
        momentDate: momentDate,
        landOnSceneDetail: landOnSceneDetail,
      ),
    );
  }

  /// Spotify language/market 결정. 디바이스 시스템 locale을 직접 읽어
  /// MaterialApp.locale 오버라이드 영향을 받지 않도록.
  String _spotifyLocale(BuildContext context) {
    final lang = View.of(context).platformDispatcher.locale.languageCode;
    return lang == 'ko' ? 'ko' : 'en';
  }

  /// 선택된 항목을 큐에 enqueue 후 picker를 즉시 닫고 scene detail로 이동.
  /// 실제 업로드는 background에서 [UploadQueueNotifier]가 처리.
  void _save(BuildContext context, WidgetRef ref, SpotifyHit hit) {
    final scene = this.scene;
    if (scene == null) return;

    ref.read(uploadQueueProvider.notifier).enqueueMusic(
          sceneId: scene.id,
          sceneTitle: scene.title,
          hit: hit,
          momentDate: momentDate,
        );

    Navigator.of(context).pop();
    if (landOnSceneDetail) {
      final viewportWidth = MediaQuery.sizeOf(context).width;
      Navigator.of(context).push(
        SceneDetailScreen.fadeRoute(
          scene: scene,
          canisterSize: viewportWidth * 0.5,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final results =
        ref.watch(musicPickerViewModelProvider.select((s) => s.results));
    final isLoading =
        ref.watch(musicPickerViewModelProvider.select((s) => s.isLoading));

    ref.listen(
      musicPickerViewModelProvider.select((s) => s.error),
      (prev, next) {
        if (next != null && next.isNotEmpty) {
          AppToast.show(context, l10n.pickerSearchFailed);
        }
      },
    );

    return SearchPickerScaffold<SpotifyHit>(
      title: l10n.musicPickerScreenTitle,
      searchHint: l10n.musicPickerSearchHint,
      emptyMessage: l10n.musicPickerEmpty,
      results: results,
      isLoading: isLoading,
      onQueryChanged: (value) => ref
          .read(musicPickerViewModelProvider.notifier)
          .updateQuery(value, locale: _spotifyLocale(context)),
      attribution: const _SpotifyAttribution(),
      idOf: (hit) => '${hit.kind}:${hit.id}',
      itemBuilder: (context, hit, selected, onTap) =>
          _MusicTile(hit: hit, selected: selected, onTap: onTap),
      onSave: (hit) => _save(context, ref, hit),
    );
  }
}

/// Spotify TOS상 데이터 노출 화면에 attribution 표시 의무.
class _SpotifyAttribution extends StatelessWidget {
  const _SpotifyAttribution();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8, top: 8),
      child: GestureDetector(
        onTap: () => launchUrl(
          Uri.parse('https://www.spotify.com/'),
          mode: LaunchMode.externalApplication,
        ),
        child: Text(
          AppLocalizations.of(context).musicPickerSpotifyAttribution,
          style: AppTypography.body(10).copyWith(
            color: context.colors.foregroundMuted.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

/// 음악 결과 타일 — 앨범 커버(56×56) + 제목/아티스트/앨범·연도.
class _MusicTile extends StatelessWidget {
  const _MusicTile({
    required this.hit,
    required this.selected,
    required this.onTap,
  });

  final SpotifyHit hit;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // line 3 포맷
    // - track: "${album} · ${year}"
    // - album: "Album · ${year}"
    // year만 없으면 · 구분자 없이 좌측만 표시.
    final left = hit.isTrack
        ? (hit.album ?? '')
        : AppLocalizations.of(context).contentDetailMusicAlbum;
    final right = hit.year ?? '';
    final thirdLine = right.isEmpty
        ? left
        : (left.isEmpty ? right : '$left · $right');

    final fallback = Center(
      child: FaIcon(
        FontAwesomeIcons.music,
        size: 18,
        color: context.colors.foregroundMuted,
      ),
    );
    return PickerResultTile(
      thumbWidth: 56,
      thumbHeight: 56,
      thumbnail: hit.coverUrl != null
          ? Image.network(
              hit.coverUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            )
          : fallback,
      line1: hit.title,
      line2: hit.artist,
      line3: thirdLine.isEmpty ? null : thirdLine,
      selected: selected,
      onTap: onTap,
    );
  }
}
