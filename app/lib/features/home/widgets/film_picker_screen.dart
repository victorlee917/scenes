import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../l10n/app_localizations.dart';
import '../../upload/upload_queue_view_model.dart';
import '../film_picker_view_model.dart';
import '../models/scene.dart';
import '../models/tmdb_film.dart';
import 'scene_detail_screen.dart';
import 'search_picker_scaffold.dart';

/// 영화 검색·선택 화면.
///
/// 한 번에 하나의 영화만 선택 가능. 입력 → 디바운스 → TMDB 검색. 검색 폼·결과
/// 리스트·선택 상태는 [SearchPickerScaffold]가 담당하고, 이 위젯은 TMDB 특화
/// 부분(타일·출처 표기·저장)만 연결한다.
class FilmPickerScreen extends ConsumerWidget {
  const FilmPickerScreen({
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
      FilmPickerScreen(
        scene: scene,
        momentDate: momentDate,
        landOnSceneDetail: landOnSceneDetail,
      ),
    );
  }

  /// TMDB language 파라미터 결정.
  ///
  /// 앱 UI는 영어 고정이지만 영화 메타는 사용자 디바이스 locale을 따른다.
  /// 한국어 디바이스 → `ko-KR`, 그 외 → `en-US`. MaterialApp의 `locale`
  /// 오버라이드 영향을 받지 않도록 PlatformDispatcher 시스템 locale을 직접 읽음.
  String _tmdbLocale(BuildContext context) {
    final lang = View.of(context).platformDispatcher.locale.languageCode;
    return lang == 'ko' ? 'ko-KR' : 'en-US';
  }

  /// 선택된 영화를 큐에 enqueue 후 picker를 즉시 닫고 scene detail로 이동.
  /// 실제 업로드는 background에서 [UploadQueueNotifier]가 처리.
  void _save(BuildContext context, WidgetRef ref, TmdbFilm film) {
    final scene = this.scene;
    if (scene == null) return;

    ref.read(uploadQueueProvider.notifier).enqueueFilm(
          sceneId: scene.id,
          sceneTitle: scene.title,
          film: film,
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
        ref.watch(filmPickerViewModelProvider.select((s) => s.results));
    final isLoading =
        ref.watch(filmPickerViewModelProvider.select((s) => s.isLoading));

    // 검색 실패 시 앱 톤 toast로 안내. 결과 영역은 빈 상태 그대로 둠.
    ref.listen(
      filmPickerViewModelProvider.select((s) => s.error),
      (prev, next) {
        if (next != null && next.isNotEmpty) {
          AppToast.show(context, l10n.pickerSearchFailed);
        }
      },
    );

    return SearchPickerScaffold<TmdbFilm>(
      title: l10n.filmPickerScreenTitle,
      searchHint: l10n.filmPickerSearchHint,
      emptyMessage: l10n.filmPickerEmpty,
      results: results,
      isLoading: isLoading,
      onQueryChanged: (value) => ref
          .read(filmPickerViewModelProvider.notifier)
          .updateQuery(value, locale: _tmdbLocale(context)),
      attribution: const _TmdbAttribution(),
      idOf: (film) => film.tmdbId,
      itemBuilder: (context, film, selected, onTap) =>
          _FilmTile(film: film, selected: selected, onTap: onTap),
      onSave: (film) => _save(context, ref, film),
    );
  }
}

/// TMDB API 약관상 데이터 노출 화면에 attribution 표시 의무.
class _TmdbAttribution extends StatelessWidget {
  const _TmdbAttribution();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8, top: 8),
      child: GestureDetector(
        onTap: () => launchUrl(
          Uri.parse('https://www.themoviedb.org/'),
          mode: LaunchMode.externalApplication,
        ),
        child: Text(
          AppLocalizations.of(context).filmPickerTmdbAttribution,
          style: AppTypography.body(10).copyWith(
            color: context.colors.foregroundMuted.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

/// 영화 결과 타일 — 포스터(48×72) + 제목/감독/연도.
class _FilmTile extends StatelessWidget {
  const _FilmTile({
    required this.film,
    required this.selected,
    required this.onTap,
  });

  final TmdbFilm film;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: FaIcon(
        FontAwesomeIcons.film,
        size: 18,
        color: context.colors.foregroundMuted,
      ),
    );
    return PickerResultTile(
      thumbWidth: 48,
      thumbHeight: 72,
      thumbnail: film.posterUrl != null
          ? Image.network(
              film.posterUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            )
          : fallback,
      line1: film.title,
      line2: film.director,
      line3: film.year != null
          ? '${film.typeLabel} · ${film.year}'
          : film.typeLabel,
      selected: selected,
      onTap: onTap,
    );
  }
}
