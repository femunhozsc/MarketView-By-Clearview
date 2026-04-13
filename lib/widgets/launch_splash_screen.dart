import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const launchSplashSingleLoopDuration = Duration(milliseconds: 1770);

class BrandSplashScreen extends StatelessWidget {
  const BrandSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: _BrandSplashBody(),
        ),
      ),
    );
  }
}

class _BrandSplashBody extends StatelessWidget {
  const _BrandSplashBody();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final baseWidth = width.clamp(280.0, 520.0).toDouble();
        final logoWidth = (baseWidth * 0.44).clamp(120.0, 190.0);

        return Stack(
          children: [
            Align(
              alignment: const Alignment(0, -0.20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Desenvolvido por',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Image.asset(
                      'assets/images/clearview_logo.png',
                      width: logoWidth,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                    const SizedBox(height: 20),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: Text(
                        'Visão clara pra quem constroi o futuro',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 11.2,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 18,
              child: Text(
                'Feito sob o céu azul de Campo Mourão PR',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.46),
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class LaunchSplashScreen extends StatelessWidget {
  const LaunchSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final baseWidth = width.clamp(240.0, 520.0).toDouble();
            final iconWidth = baseWidth * 0.123;
            final wordmarkWidth = baseWidth * 0.39;
            final spacing = baseWidth * 0.022;

            return Align(
              alignment: const Alignment(0, -0.10),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.94, end: 1),
                duration: const Duration(milliseconds: 1400),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value.clamp(0, 1),
                    child: Transform.scale(
                      scale: value,
                      child: child,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, -4),
                        child: _SpeedControlledGif(
                          assetPath: 'assets/images/logo_animado.gif',
                          width: iconWidth,
                          fit: BoxFit.contain,
                          speedMultiplier: 2.0,
                        ),
                      ),
                      SizedBox(width: spacing),
                      Image.asset(
                        'assets/images/logo_mv_cv.png',
                        width: wordmarkWidth,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SpeedControlledGif extends StatefulWidget {
  const _SpeedControlledGif({
    required this.assetPath,
    required this.width,
    required this.fit,
    required this.speedMultiplier,
  });

  final String assetPath;
  final double width;
  final BoxFit fit;
  final double speedMultiplier;

  @override
  State<_SpeedControlledGif> createState() => _SpeedControlledGifState();
}

class _SpeedControlledGifState extends State<_SpeedControlledGif> {
  ui.Codec? _codec;
  ui.FrameInfo? _frameInfo;
  Timer? _nextFrameTimer;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _loadCodec();
  }

  Future<void> _loadCodec() async {
    try {
      final data = await rootBundle.load(widget.assetPath);
      final codec = await ui.instantiateImageCodec(
        Uint8List.sublistView(data.buffer.asUint8List()),
      );

      if (!mounted) {
        codec.dispose();
        return;
      }

      _codec = codec;
      await _showNextFrame();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error);
    }
  }

  Future<void> _showNextFrame() async {
    final codec = _codec;
    if (!mounted || codec == null) return;

    final nextFrame = await codec.getNextFrame();
    if (!mounted) {
      nextFrame.image.dispose();
      return;
    }

    final previousFrame = _frameInfo;
    setState(() => _frameInfo = nextFrame);
    previousFrame?.image.dispose();

    final frameDuration = nextFrame.duration;
    final scaledMilliseconds =
        (frameDuration.inMilliseconds / widget.speedMultiplier).round();
    final nextDelay = Duration(
      milliseconds: scaledMilliseconds <= 0 ? 16 : scaledMilliseconds,
    );

    _nextFrameTimer?.cancel();
    _nextFrameTimer = Timer(nextDelay, _showNextFrame);
  }

  @override
  void dispose() {
    _nextFrameTimer?.cancel();
    _frameInfo?.image.dispose();
    _codec?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null || _frameInfo == null) {
      return Image.asset(
        widget.assetPath,
        width: widget.width,
        fit: widget.fit,
        gaplessPlayback: true,
      );
    }

    return RawImage(
      image: _frameInfo!.image,
      width: widget.width,
      fit: widget.fit,
      filterQuality: FilterQuality.high,
    );
  }
}
