import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/edge_swipe_back.dart';

class ImageGalleryViewerScreen extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const ImageGalleryViewerScreen({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  @override
  State<ImageGalleryViewerScreen> createState() =>
      _ImageGalleryViewerScreenState();
}

class _ImageGalleryViewerScreenState extends State<ImageGalleryViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: EdgeSwipeBack(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.images.length,
              onPageChanged: (value) => setState(() => _currentIndex = value),
              itemBuilder: (context, index) {
                return SafeArea(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Center(
                      child: Image.network(
                        widget.images[index],
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image_rounded,
                          color: Colors.white54,
                          size: 54,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white10,
                      ),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const Spacer(),
                    if (widget.images.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          '${_currentIndex + 1}/${widget.images.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 28,
              child: IgnorePointer(
                child: Center(
                  child: Text(
                    'Arraste a foto ou deslize para trocar',
                    style: TextStyle(
                      color: AppTheme.whiteSecondary,
                      fontSize: 12,
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
