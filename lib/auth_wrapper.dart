import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'models/ad_model.dart';
import 'models/store_model.dart';
import 'providers/user_provider.dart';
import 'screens/home_screen.dart';
import 'services/firestore_service.dart';
import 'widgets/launch_splash_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  StreamSubscription<User?>? _authSubscription;
  late UserProvider _userProvider;
  User? _firebaseUser;
  bool _authResolved = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userProvider = context.read<UserProvider>();
  }

  @override
  void initState() {
    super.initState();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      (user) {
        _firebaseUser = user;
        _authResolved = true;

        if (user != null) {
          unawaited(_userProvider.loadUser(user.uid));
        } else {
          _userProvider.clear();
        }

        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _LaunchFlow(
      firebaseUser: _firebaseUser,
      authResolved: _authResolved,
    );
  }
}

enum _LaunchStage { splash, home }

class _LaunchFlow extends StatefulWidget {
  const _LaunchFlow({
    required this.firebaseUser,
    required this.authResolved,
  });

  final User? firebaseUser;
  final bool authResolved;

  @override
  State<_LaunchFlow> createState() => _LaunchFlowState();
}

class _LaunchFlowState extends State<_LaunchFlow> {
  static const _minimumSplashTime = launchSplashSingleLoopDuration;
  static const _pollInterval = Duration(milliseconds: 120);
  static const List<String> _defaultCategoryOrder = categories;
  final FirestoreService _firestore = FirestoreService();

  _LaunchStage _stage = _LaunchStage.splash;
  List<AdModel> _preloadedAds = const [];
  List<StoreModel> _preloadedStores = const [];
  List<AdModel> _preloadedForYouRecommendedAds = const [];
  Map<String, List<AdModel>> _preloadedForYouCategoryAds = const {};
  List<String> _preloadedForYouCategories = const [];
  int _preloadedForYouLoadedCategoryIndex = 0;
  bool _marketplaceResolved = false;
  bool _forYouResolved = false;
  bool _forYouLoading = false;
  bool _forYouPersonalized = false;

  List<String> _mergeCategoryOrder(List<String> priorityCategories) {
    final ordered = <String>[];

    for (final category in priorityCategories) {
      if (category.isEmpty || ordered.contains(category)) continue;
      ordered.add(category);
    }

    for (final category in _defaultCategoryOrder) {
      if (!ordered.contains(category)) {
        ordered.add(category);
      }
    }

    return ordered;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_preloadMarketplace());
    unawaited(_preloadForYouData(useUserPreferences: false));
    _runLaunchSequence();
  }

  Future<void> _preloadMarketplace() async {
    try {
      GoogleFonts.montserrat();
      GoogleFonts.manrope();
      GoogleFonts.sora();
      GoogleFonts.roboto();

      final results = await Future.wait([
        _firestore.getAds(limit: 60),
        _firestore.getStores(limit: 60),
        GoogleFonts.pendingFonts(),
      ]);

      if (!mounted) return;
      setState(() {
        _preloadedAds = List<AdModel>.from(results[0] as List<AdModel>);
        _preloadedStores =
            List<StoreModel>.from(results[1] as List<StoreModel>);
        _marketplaceResolved = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _marketplaceResolved = true);
    }
  }

  Future<void> _preloadForYouData({
    required bool useUserPreferences,
    bool force = false,
  }) async {
    if (_forYouLoading) return;
    if (_forYouResolved && !force) return;
    _forYouLoading = true;

    try {
      final userProvider = context.read<UserProvider>();
      final hasInterestData =
          useUserPreferences && userProvider.hasPersonalizedTasteProfile;
      final priorityCategories = hasInterestData
          ? userProvider.topCategoryPreferences
          : await _firestore.getTrendingCategories(
              limit: _defaultCategoryOrder.length,
              intent: AdModel.intentSell,
            );
      final orderedCategories = _mergeCategoryOrder(priorityCategories);

      List<AdModel> recommended = [];
      if (hasInterestData) {
        for (final category in orderedCategories.take(3)) {
          final ads = await _firestore.getAdsByCategory(
            category,
            limit: 4,
            intent: AdModel.intentSell,
          );
          recommended.addAll(ads);
        }
        if (recommended.length < 6) {
          final popular = await _firestore.getPopularAds(
            limit: 12,
            intent: AdModel.intentSell,
          );
          final existingIds = recommended.map((ad) => ad.id).toSet();
          recommended.addAll(
            popular.where((ad) => !existingIds.contains(ad.id)),
          );
        }
      } else {
        final popular = await _firestore.getPopularAds(
          limit: 30,
          intent: AdModel.intentSell,
        );
        final recent = await _firestore.getAds(
          limit: 30,
          intent: AdModel.intentSell,
        );
        final existingIds = popular.map((ad) => ad.id).toSet();
        recommended = [...popular];
        recommended.addAll(
          recent.where((ad) => !existingIds.contains(ad.id)),
        );
      }

      final firstCategory =
          orderedCategories.isNotEmpty ? orderedCategories[0] : null;
      final firstCategoryAds = firstCategory == null
          ? const <AdModel>[]
          : await _firestore.getAdsByCategory(
              firstCategory,
              limit: 12,
              intent: AdModel.intentSell,
            );

      if (!mounted) return;
      setState(() {
        _preloadedForYouCategories = orderedCategories;
        _preloadedForYouRecommendedAds = recommended.take(12).toList();
        _preloadedForYouCategoryAds =
            firstCategory == null || firstCategoryAds.isEmpty
                ? const {}
                : {
                    firstCategory: firstCategoryAds,
                  };
        _preloadedForYouLoadedCategoryIndex =
            _preloadedForYouCategoryAds.isEmpty ? 0 : 1;
        _forYouResolved = true;
        _forYouPersonalized = hasInterestData;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _forYouResolved = true);
    } finally {
      _forYouLoading = false;
    }
  }

  Future<void> _runLaunchSequence() async {
    final minimumSplashDeadline = DateTime.now().add(_minimumSplashTime);

    while (mounted) {
      if (_canStartForYouPreload && !_forYouPersonalized) {
        unawaited(
          _preloadForYouData(useUserPreferences: true, force: true),
        );
      }

      final minimumTimeReached =
          !DateTime.now().isBefore(minimumSplashDeadline);
      if (minimumTimeReached && _canShowHome) {
        break;
      }

      await Future<void>.delayed(_pollInterval);
    }

    if (!mounted) return;
    setState(() => _stage = _LaunchStage.home);
  }

  bool get _canShowHome {
    if (!widget.authResolved) return false;
    if (!_marketplaceResolved) return false;
    return _forYouResolved;
  }

  bool get _canStartForYouPreload {
    final userProvider = context.read<UserProvider>();

    if (!widget.authResolved) return false;
    if (!_marketplaceResolved) return false;
    if (widget.firebaseUser == null) return true;

    return userProvider.hasResolvedCurrentUser && !userProvider.loading;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 360),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: switch (_stage) {
        _LaunchStage.splash => const LaunchSplashScreen(
            key: ValueKey('splash'),
          ),
        _LaunchStage.home => KeyedSubtree(
            key: const ValueKey('home'),
            child: HomeScreen(
              initialAds: _preloadedAds,
              initialStores: _preloadedStores,
              initialForYouRecommendedAds: _preloadedForYouRecommendedAds,
              initialForYouCategoryAds: _preloadedForYouCategoryAds,
              initialForYouCategories: _preloadedForYouCategories,
              initialForYouLoadedCategoryIndex:
                  _preloadedForYouLoadedCategoryIndex,
            ),
          ),
      },
    );
  }
}
