import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/fade_text.dart';
import '../../../l10n/app_localizations.dart';
import 'detail_app_bar.dart';

/// 영화·음악·장소 픽커가 공유하는 슬라이드-업 라우트.
Route<void> searchPickerRoute(Widget page) {
  return PageRouteBuilder<void>(
    opaque: true,
    transitionDuration: const Duration(milliseconds: 340),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}

/// 영화·음악·장소 검색 화면이 공유하는 스캐폴드.
///
/// 검색 폼 + 결과 리스트 + 앱바(저장 버튼)를 담당하고, 한 번에 하나의 항목만
/// 고를 수 있는 선택 상태를 관리한다. 타입별 차이(타이틀, 결과 타일, 출처
/// 표기 등)는 모두 파라미터로 주입한다.
///
/// 입력 중 위젯 트리가 통째로 rebuild되지 않도록:
/// - 부모는 `query`가 아니라 `results`/`isLoading`만 watch한다.
/// - clear 버튼 노출은 [TextEditingController]를 듣는 [ValueListenableBuilder]로
///   국소 갱신한다.
class SearchPickerScaffold<T> extends StatefulWidget {
  const SearchPickerScaffold({
    super.key,
    required this.title,
    required this.searchHint,
    required this.emptyMessage,
    required this.results,
    required this.isLoading,
    required this.onQueryChanged,
    required this.attribution,
    required this.idOf,
    required this.itemBuilder,
    required this.onSave,
    this.modeSelector,
  });

  /// 앱바 타이틀.
  final String title;

  /// 검색 필드 placeholder.
  final String searchHint;

  /// 입력이 비어있을 때(검색 전) 결과 영역에 표시할 안내 문구.
  final String emptyMessage;

  /// 현재 검색 결과.
  final List<T> results;

  /// 검색이 진행 중인지.
  final bool isLoading;

  /// 검색어 변경 콜백 — ViewModel의 디바운스 검색으로 위임.
  final ValueChanged<String> onQueryChanged;

  /// 결과 리스트 최상단(index 0)에 끼우는 출처 표기 위젯.
  final Widget attribution;

  /// 선택 동일성 비교용 키 추출자.
  final Object Function(T item) idOf;

  /// 결과 한 줄을 그리는 빌더. `selected`는 현재 선택 여부, `onTap`은 선택
  /// 토글 콜백.
  final Widget Function(
    BuildContext context,
    T item,
    bool selected,
    VoidCallback onTap,
  ) itemBuilder;

  /// 저장 버튼 탭 시 선택된 항목과 함께 호출.
  final ValueChanged<T> onSave;

  /// 검색창과 결과 리스트 사이에 끼우는 옵셔널 위젯(예: 장소 picker의
  /// 국내/해외 토글). null이면 영화·음악 picker처럼 아무것도 렌더하지 않는다.
  final Widget? modeSelector;

  @override
  State<SearchPickerScaffold<T>> createState() =>
      _SearchPickerScaffoldState<T>();
}

class _SearchPickerScaffoldState<T> extends State<SearchPickerScaffold<T>> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  T? _selected;

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _select(T item) {
    final id = widget.idOf(item);
    setState(() {
      final current = _selected;
      _selected =
          (current != null && widget.idOf(current) == id) ? null : item;
    });
  }

  void _save() {
    final selected = _selected;
    if (selected == null) return;
    widget.onSave(selected);
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final l10n = AppLocalizations.of(context);
    final hasSelection = _selected != null;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Column(
            children: [
              SizedBox(height: padding.top + DetailAppBar.barHeight),

              // 검색 폼
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: context.colors.nonClickableArea,
                    borderRadius: AppRadii.smBorder,
                    border: Border.all(
                      color:
                          context.colors.foreground.withValues(alpha: 0.06),
                      width: 0.5,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.search,
                    style: AppTypography.body(15).copyWith(
                      color: context.colors.foreground,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.searchHint,
                      hintStyle: AppTypography.body(15).copyWith(
                        color: context.colors.foregroundMuted
                            .withValues(alpha: 0.5),
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 14, right: 10),
                        child: FaIcon(
                          FontAwesomeIcons.magnifyingGlass,
                          size: 16,
                          color: context.colors.foregroundMuted,
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 0,
                        minHeight: 0,
                      ),
                      suffixIcon: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _searchController,
                        builder: (context, value, _) {
                          if (value.text.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              widget.onQueryChanged('');
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(right: 14),
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: context.colors.foregroundMuted
                                      .withValues(alpha: 0.3),
                                ),
                                child: Center(
                                  child: FaIcon(
                                    FontAwesomeIcons.xmark,
                                    size: 9,
                                    color: context.colors.background,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 0,
                        minHeight: 0,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    onChanged: widget.onQueryChanged,
                  ),
                ),
              ),

              // 국내/해외 등 검색 모드 토글(주입된 경우에만).
              if (widget.modeSelector != null) widget.modeSelector!,

              // 검색 결과
              Expanded(
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.white,
                      Colors.white,
                    ],
                    stops: [0.0, 0.015, 1.0],
                  ).createShader(bounds),
                  blendMode: BlendMode.dstIn,
                  child: _buildResultsBody(padding),
                ),
              ),
            ],
          ),

          // 앱바
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: DetailAppBar(
              topInset: padding.top,
              title: widget.title,
              titleOpacity: 1.0,
              useGradient: false,
              onClose: () => Navigator.of(context).pop(),
              trailing: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: hasSelection ? _save : null,
                child: AnimatedOpacity(
                  opacity: hasSelection ? 1.0 : 0.4,
                  duration: const Duration(milliseconds: 200),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    child: Text(
                      l10n.actionSave,
                      style: AppTypography.body(
                        15,
                        weight: FontWeight.w600,
                      ).copyWith(
                        color: context.colors.foreground,
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

  Widget _buildResultsBody(EdgeInsets padding) {
    // 이미 결과가 있는 상태의 재검색(모드 전환·추가 타이핑 등)에서는 리스트를
    // 스피너로 비우지 않고 그대로 유지한다 — 새 결과가 도착하면 교체. 매번
    // 깜빡이는 것을 막는다. 첫 검색(결과 없음)일 때만 스피너를 보여준다.
    if (widget.isLoading && widget.results.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          color: context.colors.foreground,
          strokeWidth: 1.5,
        ),
      );
    }

    if (widget.results.isEmpty) {
      // 입력이 비었으면 안내 문구, 입력이 있는데 결과 0이면 "검색 결과 없음".
      // 입력값에만 의존하므로 controller를 듣는 ValueListenableBuilder로
      // 국소 갱신 — 결과 리스트 영역까지 rebuild하지 않는다.
      return ValueListenableBuilder<TextEditingValue>(
        valueListenable: _searchController,
        builder: (context, value, _) => Center(
          child: Text(
            value.text.trim().isEmpty
                ? widget.emptyMessage
                : AppLocalizations.of(context).pickerNoResults,
            style: AppTypography.body(14).copyWith(
              color: context.colors.foregroundMuted,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(bottom: padding.bottom + 24),
      itemCount: widget.results.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return widget.attribution;
        final item = widget.results[index - 1];
        final current = _selected;
        final selected = current != null &&
            widget.idOf(current) == widget.idOf(item);
        return widget.itemBuilder(
          context,
          item,
          selected,
          () => _select(item),
        );
      },
    );
  }
}

/// 픽커 결과 한 줄의 공통 레이아웃.
///
/// 썸네일 + 최대 3줄 텍스트 + 선택 체크 아이콘. 영화/음악/장소 타일이 모두
/// 이 구조를 공유하며, 썸네일 크기·내용과 줄 텍스트만 다르다.
class PickerResultTile extends StatelessWidget {
  const PickerResultTile({
    super.key,
    required this.thumbnail,
    required this.thumbWidth,
    required this.thumbHeight,
    required this.line1,
    this.line2,
    this.line3,
    required this.selected,
    required this.onTap,
  });

  /// 썸네일 박스(고정 크기 + 배경) 안에 들어갈 내용.
  final Widget thumbnail;
  final double thumbWidth;
  final double thumbHeight;

  /// 1줄: 제목(필수). 2/3줄은 null이면 생략.
  final String line1;
  final String? line2;
  final String? line3;

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        color: selected
            ? colors.foreground.withValues(alpha: 0.04)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: AppRadii.xsBorder,
              child: Container(
                width: thumbWidth,
                height: thumbHeight,
                color: colors.nonClickableArea,
                child: thumbnail,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeText(
                    line1,
                    style: AppTypography.body(15, weight: FontWeight.w500)
                        .copyWith(color: colors.foreground),
                  ),
                  if (line2 != null) ...[
                    const SizedBox(height: 3),
                    FadeText(
                      line2!,
                      style: AppTypography.body(13).copyWith(
                        color: colors.foregroundMuted,
                      ),
                    ),
                  ],
                  if (line3 != null) ...[
                    const SizedBox(height: 2),
                    FadeText(
                      line3!,
                      style: AppTypography.body(12).copyWith(
                        color: colors.foregroundMuted.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (selected)
              FaIcon(
                FontAwesomeIcons.check,
                size: 16,
                color: colors.foreground,
              ),
          ],
        ),
      ),
    );
  }
}
