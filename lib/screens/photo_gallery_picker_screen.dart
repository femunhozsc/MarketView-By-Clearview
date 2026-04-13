import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_manager/photo_manager.dart';

import '../theme/app_theme.dart';

class PhotoGalleryPickerScreen extends StatefulWidget {
  const PhotoGalleryPickerScreen({
    super.key,
    this.maxSelection = 1,
    this.title = 'Galeria',
  });

  final int maxSelection;
  final String title;

  static Future<List<File>> pick(
    BuildContext context, {
    int maxSelection = 1,
    String title = 'Galeria',
  }) async {
    final result = await Navigator.push<List<File>>(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoGalleryPickerScreen(
          maxSelection: maxSelection,
          title: title,
        ),
      ),
    );
    return result ?? const [];
  }

  @override
  State<PhotoGalleryPickerScreen> createState() =>
      _PhotoGalleryPickerScreenState();
}

class _PhotoGalleryPickerScreenState extends State<PhotoGalleryPickerScreen> {
  final List<AssetEntity> _assets = [];
  final List<AssetEntity> _selectedAssets = [];

  bool _loading = true;
  bool _loadingMore = false;
  bool _permissionDenied = false;
  bool _pluginUnavailable = false;
  int _currentPage = 0;
  int _lastFetchedCount = 0;

  bool get _singleSelection => widget.maxSelection <= 1;

  @override
  void initState() {
    super.initState();
    _requestPermissionAndLoad();
  }

  Future<void> _requestPermissionAndLoad() async {
    try {
      final permission = await PhotoManager.requestPermissionExtend();
      if (!mounted) return;

      if (!permission.isAuth) {
        setState(() {
          _loading = false;
          _permissionDenied = true;
        });
        return;
      }

      await _loadMoreAssets(initialLoad: true);
    } on MissingPluginException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _pluginUnavailable = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadMoreAssets({bool initialLoad = false}) async {
    if (_loadingMore) return;

    setState(() {
      if (initialLoad) {
        _loading = true;
      } else {
        _loadingMore = true;
      }
    });

    try {
      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
        filterOption: FilterOptionGroup(
          imageOption: const FilterOption(
            needTitle: false,
            sizeConstraint: SizeConstraint(ignoreSize: true),
          ),
          orders: [
            const OrderOption(
              type: OrderOptionType.createDate,
              asc: false,
            ),
          ],
        ),
      );

      if (paths.isEmpty) {
        if (!mounted) return;
        setState(() {
          _assets.clear();
          _lastFetchedCount = 0;
          _loading = false;
          _loadingMore = false;
        });
        return;
      }

      final album = paths.first;
      final fetched = await album.getAssetListPaged(
        page: _currentPage,
        size: 60,
      );

      if (!mounted) return;
      setState(() {
        _assets.addAll(fetched);
        _lastFetchedCount = fetched.length;
        _currentPage += 1;
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _openPermissionSettings() async {
    await PhotoManager.openSetting();
  }

  Future<void> _toggleSelection(AssetEntity asset) async {
    if (_singleSelection) {
      final file = await asset.file;
      if (!mounted || file == null) return;
      Navigator.pop(context, [file]);
      return;
    }

    setState(() {
      if (_selectedAssets.any((item) => item.id == asset.id)) {
        _selectedAssets.removeWhere((item) => item.id == asset.id);
        return;
      }

      if (_selectedAssets.length >= widget.maxSelection) {
        return;
      }
      _selectedAssets.add(asset);
    });
  }

  Future<void> _confirmSelection() async {
    if (_selectedAssets.isEmpty) return;

    final files = <File>[];
    for (final asset in _selectedAssets) {
      final file = await asset.file;
      if (file != null) {
        files.add(file);
      }
    }

    if (!mounted || files.isEmpty) return;
    Navigator.pop(context, files);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          widget.title,
          style: GoogleFonts.roboto(
            color: textColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
        ),
        actions: [
          if (!_singleSelection)
            TextButton(
              onPressed: _selectedAssets.isEmpty ? null : _confirmSelection,
              child: Text(
                _selectedAssets.isEmpty
                    ? 'Selecionar'
                    : 'Usar (${_selectedAssets.length})',
                style: GoogleFonts.roboto(
                  color: AppTheme.facebookBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.facebookBlue),
      );
    }

    if (_permissionDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.photo_library_outlined,
                color: Colors.grey.shade500,
                size: 44,
              ),
              const SizedBox(height: 12),
              Text(
                'Permita o acesso às fotos para abrir a galeria do aparelho.',
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Depois disso, toque em "Abrir ajustes" e volte para continuar.',
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(color: Colors.grey),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _openPermissionSettings,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.facebookBlue,
                ),
                child: const Text('Abrir ajustes'),
              ),
            ],
          ),
        ),
      );
    }

    if (_pluginUnavailable) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sync_problem_rounded,
                color: Colors.orange.shade400,
                size: 44,
              ),
              const SizedBox(height: 12),
              Text(
                'A galeria ainda não foi carregada pelo app.',
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Depois de adicionar este plugin nativo, o Android precisa de um reinício completo do app. Feche a execução atual e rode novamente para que a permissão da galeria funcione.',
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_assets.isEmpty) {
      return Center(
        child: Text(
          'Nenhuma foto encontrada na galeria.',
          style: GoogleFonts.roboto(color: Colors.grey),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (_lastFetchedCount < 60 || _loadingMore) return false;
        if (notification.metrics.pixels >=
            notification.metrics.maxScrollExtent - 500) {
          _loadMoreAssets();
        }
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(4),
        itemCount: _assets.length + (_loadingMore ? 1 : 0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemBuilder: (context, index) {
          if (index >= _assets.length) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppTheme.facebookBlue,
                strokeWidth: 2.2,
              ),
            );
          }

          final asset = _assets[index];
          final selectionIndex =
              _selectedAssets.indexWhere((item) => item.id == asset.id);

          return GestureDetector(
            onTap: () => _toggleSelection(asset),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _GalleryThumb(asset: asset),
                if (selectionIndex >= 0 || _singleSelection == false)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: selectionIndex >= 0
                            ? AppTheme.facebookBlue
                            : Colors.black26,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.4),
                      ),
                      alignment: Alignment.center,
                      child: selectionIndex >= 0
                          ? Text(
                              '${selectionIndex + 1}',
                              style: GoogleFonts.roboto(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GalleryThumb extends StatelessWidget {
  const _GalleryThumb({required this.asset});

  final AssetEntity asset;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: asset.thumbnailDataWithSize(
        const ThumbnailSize(500, 500),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            snapshot.data == null) {
          return Container(color: Colors.grey.shade200);
        }

        return Image.memory(
          snapshot.data!,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        );
      },
    );
  }
}
