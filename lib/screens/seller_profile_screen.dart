import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/ad_model.dart';
import '../models/store_model.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ad_card.dart';
import 'ad_detail_screen.dart';
import 'chat_detail_screen.dart';
import 'edit_profile_screen.dart';
import 'profile_screen.dart';
import 'reviews_screen.dart';

class SellerProfileScreen extends StatefulWidget {
  const SellerProfileScreen({
    super.key,
    required this.sellerId,
    required this.sellerName,
    this.storeId,
    this.showAppBar = true,
  });

  final String sellerId;
  final String sellerName;
  final String? storeId;
  final bool showAppBar;

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  final _firestore = FirestoreService();

  UserModel? _user;
  StoreModel? _store;
  List<AdModel> _ads = [];
  List<Map<String, dynamic>> _reviews = [];
  bool _loading = true;
  int _selectedTabIndex = 0;

  String get _reviewsTargetId {
    final storeId = widget.storeId?.trim() ?? '';
    return storeId.isNotEmpty ? storeId : widget.sellerId;
  }

  bool get _isStoreProfile => _store != null;

  bool get _isSelf {
    final currentUser = context.read<UserProvider>().user;
    return currentUser != null && currentUser.uid == widget.sellerId;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _user = await _firestore.getUser(widget.sellerId);
      if (widget.storeId != null && widget.storeId!.isNotEmpty) {
        _store = await _firestore.getStore(widget.storeId!);
      }

      if (_store != null) {
        _ads = await _firestore.getAdsByStore(_store!.id);
      } else if (widget.sellerId.isNotEmpty) {
        _ads = await _firestore.getPersonalAdsByUser(widget.sellerId);
      }

      if (_reviewsTargetId.isNotEmpty) {
        _reviews = await _firestore.getReviewsForUser(_reviewsTargetId);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  double get _averageRating {
    if (_reviews.isEmpty) return 0;
    final total = _reviews.fold<double>(
      0,
      (sum, review) => sum + ((review['rating'] as num?)?.toDouble() ?? 0),
    );
    return total / _reviews.length;
  }

  List<String> get _departmentLabels {
    final values = <String>{};

    if ((_store?.category.trim().isNotEmpty ?? false)) {
      values.add(AdModel.displayLabel(_store!.category));
    }

    for (final ad in _ads) {
      final category = AdModel.displayLabel(ad.category).trim();
      if (category.isNotEmpty) {
        values.add(category);
      }
    }

    return values.toList()..sort();
  }

  String _displayTitle(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length <= 26) return normalized;

    final parts = normalized.split(' ');
    if (parts.length >= 2) {
      return '${parts.first} ${parts.last}'.trim();
    }

    return normalized;
  }

  Future<void> _openEditProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    if (!mounted) return;
    setState(() => _loading = true);
    await _load();
  }

  void _openReviews() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewsScreen(
          userId: _reviewsTargetId,
          title: 'Avaliacoes',
          allowReply: _isSelf,
        ),
      ),
    );
  }

  Future<void> _openDirectChat() async {
    final currentUser = context.read<UserProvider>().user;
    if (currentUser == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
      return;
    }

    if (widget.sellerId.isEmpty || currentUser.uid == widget.sellerId) return;

    try {
      final chatId = await _firestore.getOrCreateDirectChat(
        currentUser.uid,
        widget.sellerId,
        title: '',
        currentUserName: currentUser.fullName,
        currentUserPhoto: currentUser.profilePhoto ?? '',
        otherUserName: (_user?.fullName ?? widget.sellerName).trim(),
        otherUserPhoto: _user?.profilePhoto ?? '',
      );
      if (!mounted) return;

      final otherUserName = (_user?.fullName ?? widget.sellerName).trim();
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            chatId: chatId,
            otherUserId: widget.sellerId,
            otherUserName: otherUserName.isNotEmpty ? otherUserName : 'Usuario',
            otherUserPhoto: _user?.profilePhoto ?? '',
            adTitle: '',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nao foi possivel abrir a conversa agora.'),
        ),
      );
    }
  }

  SliverGridDelegate _adsGridDelegate(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 980
        ? 4
        : width >= 720
            ? 3
            : 2;

    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 0,
      mainAxisSpacing: 0,
      mainAxisExtent: 246,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.black : const Color(0xFFF3F4F6);

    if (_loading) {
      return Scaffold(
        backgroundColor: bg,
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.facebookBlue),
        ),
      );
    }

    final title = _store?.name ?? _user?.fullName ?? widget.sellerName;
    final displayTitle = _displayTitle(title);
    final locationLabel = ((_store?.address.city.trim().isNotEmpty ?? false)
            ? '${_store!.address.city} - ${_store!.address.state}'
            : ((_user?.address.city.trim().isNotEmpty ?? false)
                ? '${_user!.address.city} - ${_user!.address.state}'
                : 'Localizacao nao informada'))
        .trim();
    final bannerUrl = (_store?.banner?.trim().isNotEmpty ?? false)
        ? _store!.banner!.trim()
        : ((_user?.bannerPhoto?.trim().isNotEmpty ?? false)
            ? _user!.bannerPhoto!.trim()
            : null);
    final avatarUrl =
        ((_store?.logo?.trim().isNotEmpty ?? false) ? _store!.logo : null) ??
            ((_user?.profilePhoto?.trim().isNotEmpty ?? false)
                ? _user!.profilePhoto
                : null);
    final reviewCount = _reviews.length;
    final averageRating = _averageRating;
    final following =
        context.watch<UserProvider>().isFollowingSeller(widget.sellerId);
    final departments = _departmentLabels;
    final tabTitle = _isStoreProfile ? 'Departamentos' : 'Informacoes';

    return Scaffold(
      backgroundColor: bg,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.facebookBlue,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _ProfileHero(
              title: displayTitle,
              fullTitle: title,
              subtitle: locationLabel,
              bannerUrl: bannerUrl,
              avatarUrl: avatarUrl,
              averageRating: averageRating,
              reviewCount: reviewCount,
              isStoreProfile: _isStoreProfile,
              following: following,
              onBack: () => Navigator.maybePop(context),
              onFollow: _isSelf
                  ? null
                  : () {
                      if (context.read<UserProvider>().user == null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProfileScreen(),
                          ),
                        );
                        return;
                      }
                      context
                          .read<UserProvider>()
                          .toggleFollowSeller(widget.sellerId);
                    },
              onEdit: _isSelf ? _openEditProfile : null,
              onMessage: _isSelf ? null : _openDirectChat,
              onOpenReviews: _openReviews,
            ),
            if ((_store?.description.trim().isNotEmpty ?? false))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Text(
                  _store!.description,
                  style: GoogleFonts.roboto(
                    color: Colors.grey.shade700,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
              ),
            const SizedBox(height: 18),
            _ProfileTabs(
              selectedIndex: _selectedTabIndex,
              leftLabel: 'Todos os anuncios',
              rightLabel: tabTitle,
              onChanged: (index) => setState(() => _selectedTabIndex = index),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _selectedTabIndex == 0
                  ? _AdsGridSection(
                      ads: _ads,
                      gridDelegate: _adsGridDelegate(context),
                    )
                  : _isStoreProfile
                      ? _DepartmentsSection(labels: departments)
                      : _UserInfoSection(
                          location: locationLabel,
                          hasStore: _user?.hasStore ?? false,
                          totalAds: _ads.length,
                          averageRating: averageRating,
                          reviewCount: reviewCount,
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.title,
    required this.fullTitle,
    required this.subtitle,
    required this.bannerUrl,
    required this.avatarUrl,
    required this.averageRating,
    required this.reviewCount,
    required this.isStoreProfile,
    required this.following,
    required this.onBack,
    required this.onOpenReviews,
    this.onFollow,
    this.onEdit,
    this.onMessage,
  });

  final String title;
  final String fullTitle;
  final String subtitle;
  final String? bannerUrl;
  final String? avatarUrl;
  final double averageRating;
  final int reviewCount;
  final bool isStoreProfile;
  final bool following;
  final VoidCallback onBack;
  final VoidCallback onOpenReviews;
  final VoidCallback? onFollow;
  final VoidCallback? onEdit;
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final ratingLabel = averageRating.toStringAsFixed(1).replaceAll('.', ',');
    final actionLabel = onEdit != null
        ? 'Editar'
        : following
            ? 'Seguindo'
            : 'Seguir';
    final actionColor = onEdit != null
        ? AppTheme.facebookBlue
        : following
            ? const Color(0xFFE5E7EB)
            : AppTheme.facebookBlue;
    final actionTextColor =
        onEdit != null || !following ? Colors.white : Colors.black87;
    final fallbackLetter = title.isNotEmpty ? title[0].toUpperCase() : 'P';

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              height: 196,
              width: double.infinity,
              child: _BannerArea(
                imageUrl: bannerUrl,
                fallbackIcon:
                    isStoreProfile ? Icons.storefront_rounded : Icons.person,
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 10,
              left: 14,
              child: Material(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: onBack,
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 20,
              bottom: -36,
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: avatarUrl?.trim().isNotEmpty == true
                    ? Image.network(
                        avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _AvatarFallback(
                          letter: fallbackLetter,
                        ),
                      )
                    : _AvatarFallback(letter: fallbackLetter),
              ),
            ),
          ],
        ),
        const SizedBox(height: 44),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Tooltip(
                message: fullTitle,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.roboto(
                    color: primaryTextColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1.04,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.roboto(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: onOpenReviews,
                borderRadius: BorderRadius.circular(999),
                child: _RatingSummary(
                  averageRating: averageRating,
                  reviewCount: reviewCount,
                  ratingLabel: ratingLabel,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: FilledButton(
                        onPressed: onEdit ?? onFollow,
                        style: FilledButton.styleFrom(
                          backgroundColor: actionColor,
                          foregroundColor: actionTextColor,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          textStyle: GoogleFonts.roboto(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        child: Text(actionLabel),
                      ),
                    ),
                  ),
                  if (onMessage != null) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: OutlinedButton.icon(
                          onPressed: onMessage,
                          icon: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 16,
                          ),
                          label: const Text('Mensagem'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black87,
                            side: const BorderSide(color: Color(0xFFD1D5DB)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                            textStyle: GoogleFonts.roboto(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RatingSummary extends StatelessWidget {
  const _RatingSummary({
    required this.averageRating,
    required this.reviewCount,
    required this.ratingLabel,
  });

  final double averageRating;
  final int reviewCount;
  final String ratingLabel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        ...List.generate(
          5,
          (index) => Icon(
            _resolveStarIcon(index, averageRating),
            size: 17,
            color: const Color(0xFFFFB800),
          ),
        ),
        const SizedBox(width: 2),
        Text(
          '($ratingLabel)',
          style: GoogleFonts.roboto(
            color: Colors.black87,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        Text(
          '($reviewCount avaliacoes)',
          style: GoogleFonts.roboto(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }

  static IconData _resolveStarIcon(int index, double rating) {
    final starPosition = index + 1;
    if (rating >= starPosition) return Icons.star_rounded;
    if (rating >= starPosition - 0.5) return Icons.star_half_rounded;
    return Icons.star_outline_rounded;
  }
}

class _BannerArea extends StatelessWidget {
  const _BannerArea({
    required this.imageUrl,
    required this.fallbackIcon,
  });

  final String? imageUrl;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl?.trim().isNotEmpty == true;
    if (hasImage) {
      return _StableBannerImage(
        imageUrl: imageUrl!,
        fallback: _BannerFallback(icon: fallbackIcon),
      );
    }

    return _BannerFallback(icon: fallbackIcon);
  }
}

class _StableBannerImage extends StatelessWidget {
  const _StableBannerImage({
    required this.imageUrl,
    required this.fallback,
  });

  final String imageUrl;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imageUrl,
      key: ValueKey(imageUrl),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }

        return Container(
          color: const Color(0xFFE5E7EB),
        );
      },
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: const Color(0xFFE5E7EB),
        );
      },
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

class _BannerFallback extends StatelessWidget {
  const _BannerFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFCBD5E1),
            Color(0xFFE5E7EB),
            Color(0xFFF8FAFC),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          size: 48,
          color: Colors.white.withValues(alpha: 0.82),
        ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.facebookBlue.withValues(alpha: 0.12),
      ),
      child: Center(
        child: Text(
          letter,
          style: GoogleFonts.roboto(
            color: AppTheme.facebookBlue,
            fontWeight: FontWeight.w900,
            fontSize: 34,
          ),
        ),
      ),
    );
  }
}

class _ProfileTabs extends StatelessWidget {
  const _ProfileTabs({
    required this.selectedIndex,
    required this.leftLabel,
    required this.rightLabel,
    required this.onChanged,
  });

  final int selectedIndex;
  final String leftLabel;
  final String rightLabel;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ProfileTabButton(
              label: leftLabel,
              active: selectedIndex == 0,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _ProfileTabButton(
              label: rightLabel,
              active: selectedIndex == 1,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTabButton extends StatelessWidget {
  const _ProfileTabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? AppTheme.facebookBlue : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.roboto(
            color: active ? AppTheme.facebookBlue : Colors.grey.shade600,
            fontSize: 13,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _AdsGridSection extends StatelessWidget {
  const _AdsGridSection({
    required this.ads,
    required this.gridDelegate,
  });

  final List<AdModel> ads;
  final SliverGridDelegate gridDelegate;

  @override
  Widget build(BuildContext context) {
    if (ads.isEmpty) {
      return const _EmptyStateCard(
        title: 'Nenhum anuncio por enquanto',
        message: 'Quando novos itens forem publicados, eles aparecerao aqui.',
      );
    }

    return GridView.builder(
      key: const ValueKey('ads-grid'),
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: ads.length,
      gridDelegate: gridDelegate,
      itemBuilder: (context, index) => AdCard(
        ad: ads[index],
        index: index,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdDetailScreen(ad: ads[index]),
          ),
        ),
      ),
    );
  }
}

class _DepartmentsSection extends StatelessWidget {
  const _DepartmentsSection({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) {
      return const _EmptyStateCard(
        title: 'Sem departamentos ainda',
        message: 'Os departamentos da loja aparecerao aqui.',
      );
    }

    final items = labels
        .map(
          (label) => _DepartmentCard(
            label: label,
            icon: _departmentIcon(label),
            color: _departmentColor(label),
          ),
        )
        .toList(growable: false);

    return Padding(
      key: const ValueKey('departments-grid'),
      padding: const EdgeInsets.all(14),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 86,
        ),
        itemBuilder: (_, index) => items[index],
      ),
    );
  }

  static IconData _departmentIcon(String label) {
    final value = label.toLowerCase();
    if (value.contains('eletro')) return Icons.devices_rounded;
    if (value.contains('moda') || value.contains('roupa')) {
      return Icons.checkroom_rounded;
    }
    if (value.contains('casa')) return Icons.chair_alt_rounded;
    if (value.contains('esporte')) return Icons.sports_soccer_rounded;
    if (value.contains('beleza')) return Icons.spa_rounded;
    if (value.contains('serv')) return Icons.handyman_rounded;
    return Icons.grid_view_rounded;
  }

  static Color _departmentColor(String label) {
    final value = label.toLowerCase();
    if (value.contains('eletro')) return const Color(0xFF2563EB);
    if (value.contains('moda') || value.contains('roupa')) {
      return const Color(0xFFF59E0B);
    }
    if (value.contains('casa')) return const Color(0xFFEF4444);
    if (value.contains('esporte')) return const Color(0xFF10B981);
    if (value.contains('beleza')) return const Color(0xFFEC4899);
    return AppTheme.facebookBlue;
  }
}

class _DepartmentCard extends StatelessWidget {
  const _DepartmentCard({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.roboto(
                color: Colors.black87,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserInfoSection extends StatelessWidget {
  const _UserInfoSection({
    required this.location,
    required this.hasStore,
    required this.totalAds,
    required this.averageRating,
    required this.reviewCount,
  });

  final String location;
  final bool hasStore;
  final int totalAds;
  final double averageRating;
  final int reviewCount;

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String label, String value})>[
      (
        icon: Icons.location_on_outlined,
        label: 'Localizacao',
        value: location,
      ),
      (
        icon: Icons.sell_outlined,
        label: 'Anuncios publicados',
        value: '$totalAds',
      ),
      (
        icon: Icons.storefront_outlined,
        label: 'Possui loja',
        value: hasStore ? 'Sim' : 'Nao',
      ),
      (
        icon: Icons.star_outline_rounded,
        label: 'Media de avaliacoes',
        value: reviewCount > 0
            ? averageRating.toStringAsFixed(1).replaceAll('.', ',')
            : 'Sem avaliacoes',
      ),
    ];

    return Padding(
      key: const ValueKey('user-info'),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: items
            .map(
              (item) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    Icon(item.icon, color: AppTheme.facebookBlue, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            style: GoogleFonts.roboto(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.value,
                            style: GoogleFonts.roboto(
                              color: Colors.black87,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.inbox_rounded,
              color: AppTheme.facebookBlue,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
