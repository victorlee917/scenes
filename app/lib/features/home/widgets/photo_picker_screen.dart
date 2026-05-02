import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/floating_bottom_sheet.dart';
import '../models/scene.dart';
import 'detail_app_bar.dart';
import 'scene_detail_screen.dart';

/// 사진 선택 화면.
class PhotoPickerScreen extends StatefulWidget {
  const PhotoPickerScreen({super.key, this.scene});

  final Scene? scene;

  static Route<List<AssetEntity>?> route({Scene? scene}) {
    return PageRouteBuilder<List<AssetEntity>?>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 340),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) =>
          PhotoPickerScreen(scene: scene),
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

  @override
  State<PhotoPickerScreen> createState() => _PhotoPickerScreenState();
}

class _PhotoPickerScreenState extends State<PhotoPickerScreen> {
  static const int _maxSelection = 20;

  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _currentAlbum;
  List<AssetEntity> _assets = [];
  final List<AssetEntity> _selected = [];
  final Map<String, Uint8List> _thumbCache = {};
  bool _loading = true;
  bool _saving = false;
  double _saveProgress = 0;

  Future<Uint8List?> _getThumb(AssetEntity asset, int size) async {
    final key = '${asset.id}_$size';
    if (_thumbCache.containsKey(key)) return _thumbCache[key];
    final data = await asset.thumbnailDataWithSize(ThumbnailSize(size, size));
    if (data != null) _thumbCache[key] = data;
    return data;
  }

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      filterOption: FilterOptionGroup(
        orders: [
          const OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      ),
    );
    if (albums.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted) setState(() => _albums = albums);
    await _selectAlbum(albums.first);
  }

  Future<void> _selectAlbum(AssetPathEntity album) async {
    setState(() {
      _currentAlbum = album;
      _loading = true;
    });
    final assets = await album.getAssetListRange(start: 0, end: 200);
    if (mounted) {
      setState(() {
        _assets = assets;
        _loading = false;
      });
    }
  }

  void _showAlbumPicker() {
    FloatingBottomSheet.show(
      context: context,
      builder: (_) => _AlbumList(
        albums: _albums,
        currentId: _currentAlbum?.id,
        onSelect: (album) {
          Navigator.of(context).pop();
          _selectAlbum(album);
        },
      ),
    );
  }

  void _toggleSelect(AssetEntity asset) {
    setState(() {
      if (_selected.contains(asset)) {
        _selected.remove(asset);
      } else if (_selected.length < _maxSelection) {
        _selected.add(asset);
      }
    });
  }

  void _removeFromSelection(AssetEntity asset) {
    setState(() => _selected.remove(asset));
  }

  Future<void> _save() async {
    if (_selected.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _saveProgress = 0;
    });
    for (int i = 0; i < _selected.length; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() => _saveProgress = (i + 1) / _selected.length);
    }
    if (mounted) {
      Navigator.of(context).pop(_selected);
      if (widget.scene != null) {
        final viewportWidth = MediaQuery.sizeOf(context).width;
        Navigator.of(context).push(
          SceneDetailScreen.fadeRoute(
            scene: widget.scene!,
            canisterSize: viewportWidth * 0.5,
          ),
        );
      }
    }
  }

  void _previewPhoto(AssetEntity asset) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => _PhotoPreviewDialog(asset: asset),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final hasSelection = _selected.isNotEmpty;

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              SizedBox(height: padding.top + DetailAppBar.barHeight),

              // 선택된 사진 미리보기
              if (hasSelection)
                SizedBox(
                  height: 88,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _selected.length,
                    itemBuilder: (context, index) {
                      final previewAsset = _selected[index];
                      return _PreviewTile(
                        asset: previewAsset,
                        thumbFuture: _getThumb(previewAsset, 200),
                        onRemove: () => _removeFromSelection(previewAsset),
                      );
                    },
                  ),
                ),

              if (hasSelection)
                Container(
                  height: 0.5,
                  color: context.colors.foreground.withValues(alpha: 0.06),
                ),

              // 그리드 갤러리
              Expanded(
                child: _loading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: context.colors.foreground,
                          strokeWidth: 1.5,
                        ),
                      )
                    : _assets.isEmpty
                        ? Center(
                            child: Text(
                              'No photos found',
                              style: AppTypography.body(14).copyWith(
                                color: context.colors.foregroundMuted,
                              ),
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(2),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 2,
                              crossAxisSpacing: 2,
                            ),
                            itemCount: _assets.length,
                            itemBuilder: (context, index) {
                              final asset = _assets[index];
                              final selIdx = _selected.indexOf(asset);
                              final isSelected = selIdx >= 0;
                              return _GalleryTile(
                                asset: asset,
                                selected: isSelected,
                                selectionOrder: isSelected ? selIdx + 1 : 0,
                                thumbFuture: _getThumb(asset, 300),
                                onSelect: () => _toggleSelect(asset),
                                onTap: () => _previewPhoto(asset),
                              );
                            },
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
              title: 'Add Photos',
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
                      'Save${hasSelection ? ' (${_selected.length})' : ''}',
                      style: AppTypography.body(15, weight: FontWeight.w600)
                          .copyWith(color: context.colors.foreground),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 하단 앨범 선택 버튼
          Positioned(
            bottom: padding.bottom + 16,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _albums.length > 1 ? _showAlbumPicker : null,
                child: ClipRRect(
                  borderRadius: AppRadii.xlBorder,
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.clickableArea
                            .withValues(alpha: 0.82),
                        borderRadius: AppRadii.xlBorder,
                        border: Border.all(
                          color: context.colors.foreground
                              .withValues(alpha: 0.08),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentAlbum?.name ?? 'All Photos',
                            style: AppTypography.body(14,
                                    weight: FontWeight.w500)
                                .copyWith(
                                    color: context.colors.foreground),
                          ),
                          if (_albums.length > 1) ...[
                            const SizedBox(width: 6),
                            FaIcon(
                              FontAwesomeIcons.chevronDown,
                              size: 10,
                              color: context.colors.foregroundMuted,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 저장 중 로딩 오버레이
          if (_saving)
            Positioned.fill(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    color: context.colors.background.withValues(alpha: 0.5),
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal:
                              (MediaQuery.sizeOf(context).width - 120) / 2,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: AppRadii.xsBorder,
                              child: TweenAnimationBuilder<double>(
                                tween:
                                    Tween(begin: 0, end: _saveProgress),
                                duration:
                                    const Duration(milliseconds: 280),
                                curve: Curves.linear,
                                builder: (context, value, _) {
                                  return LinearProgressIndicator(
                                    value: value,
                                    minHeight: 4,
                                    backgroundColor: context
                                        .colors.foreground
                                        .withValues(alpha: 0.1),
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                      context.colors.foreground,
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Uploading...',
                              style: AppTypography.body(14).copyWith(
                                color: context.colors.foreground,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${(_saveProgress * _selected.length).ceil()}/${_selected.length}',
                              style: AppTypography.body(12).copyWith(
                                color: context.colors.foregroundMuted,
                              ),
                            ),
                          ],
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

// ── 그리드 타일 ──────────────────────────────────────────────

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({
    required this.asset,
    required this.selected,
    required this.selectionOrder,
    required this.thumbFuture,
    required this.onSelect,
    required this.onTap,
  });

  final AssetEntity asset;
  final bool selected;
  final int selectionOrder;
  final Future<Uint8List?> thumbFuture;
  final VoidCallback onSelect;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: thumbFuture,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: onTap,
              child: bytes != null
                  ? Image.memory(bytes, fit: BoxFit.cover)
                  : ColoredBox(color: context.colors.nonClickableArea),
            ),

            // 선택 오버레이
            if (selected)
              IgnorePointer(
                child: Container(
                  color: context.colors.foreground.withValues(alpha: 0.1),
                ),
              ),

            // 선택 버튼
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: onSelect,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? context.colors.foreground
                          : Colors.black.withValues(alpha: 0.3),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.8),
                        width: 1.5,
                      ),
                    ),
                    child: selected
                        ? Center(
                            child: Text(
                              '$selectionOrder',
                              style: AppTypography.body(11,
                                      weight: FontWeight.w700)
                                  .copyWith(
                                      color: context.colors.background),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── 미리보기 타일 ────────────────────────────────────────────

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({
    required this.asset,
    required this.thumbFuture,
    required this.onRemove,
  });

  final AssetEntity asset;
  final Future<Uint8List?> thumbFuture;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        width: 72,
        height: 72,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              bottom: 0,
              child: ClipRRect(
                borderRadius: AppRadii.smBorder,
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: FutureBuilder<Uint8List?>(
                    future: thumbFuture,
                    builder: (context, snapshot) {
                      if (snapshot.data != null) {
                        return Image.memory(snapshot.data!,
                            fit: BoxFit.cover);
                      }
                      return ColoredBox(
                          color: context.colors.nonClickableArea);
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: onRemove,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.colors.foreground,
                  ),
                  child: Center(
                    child: FaIcon(
                      FontAwesomeIcons.xmark,
                      size: 10,
                      color: context.colors.background,
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

// ── 사진 미리보기 다이얼로그 ─────────────────────────────────

class _PhotoPreviewDialog extends StatelessWidget {
  const _PhotoPreviewDialog({required this.asset});

  final AssetEntity asset;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        color: Colors.transparent,
        child: Center(
          child: FutureBuilder<Uint8List?>(
            future:
                asset.thumbnailDataWithSize(const ThumbnailSize(800, 800)),
            builder: (context, snapshot) {
              if (snapshot.data != null) {
                return Image.memory(snapshot.data!, fit: BoxFit.contain);
              }
              return CircularProgressIndicator(
                color: context.colors.foreground,
                strokeWidth: 1.5,
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── 앨범 선택 리스트 ─────────────────────────────────────────

class _AlbumList extends StatelessWidget {
  const _AlbumList({
    required this.albums,
    required this.currentId,
    required this.onSelect,
  });

  final List<AssetPathEntity> albums;
  final String? currentId;
  final ValueChanged<AssetPathEntity> onSelect;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 360),
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0.0, 0.06, 0.94, 1.0],
        ).createShader(bounds),
        blendMode: BlendMode.dstIn,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          shrinkWrap: true,
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final album = albums[index];
            final isCurrent = album.id == currentId;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(album),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        album.name,
                        style:
                            AppTypography.body(15, weight: FontWeight.w500)
                                .copyWith(
                                    color: context.colors.foreground),
                      ),
                    ),
                    if (isCurrent)
                      FaIcon(
                        FontAwesomeIcons.check,
                        size: 14,
                        color: context.colors.foreground,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
