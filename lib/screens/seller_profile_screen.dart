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
import 'reviews_screen.dart';
import 'profile_screen.dart';

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

  String get _reviewsTargetId {
    final storeId = widget.storeId?.trim() ?? '';
    return storeId.isNotEmpty ? storeId : widget.sellerId;
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

  bool get _isSelf {
    final currentUser = context.read<UserProvider>().user;
    return currentUser != null && currentUser.uid == widget.sellerId;
  }

  void _openReviews() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewsScreen(
          userId: _reviewsTargetId,
          title: 'Avalia\u00e7\u00f5es',
          allowReply: _isSelf,
        ),
      ),
    );
  }

  void _openEditProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    if (!mounted) return;
    setState(() => _loading = true);
    await _load();
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
      );
      if (!mounted) return;

      final otherUserName = (_user?.fullName ?? widget.sellerName).trim();
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            chatId: chatId,
            otherUserId: widget.sellerId,
            otherUserName:
                otherUserName.isNotEmpty ? otherUserName : 'Usu\u00e1rio',
            adTitle: '',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'N\u00e3o foi poss\u00edvel abrir a conversa agora.',
          ),
        ),
      );
    }
  }

  Widget _buildMarketViewWordmark(bool isDark) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Market',
                style: GoogleFonts.montserrat(
                  color: const Color(0xFF0066EE),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: -0.9,
                ),
              ),
              TextSpan(
                text: 'View',
                style: GoogleFonts.montserrat(
                  color: isDark ? Colors.white : const Color(0xFF303030),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: -0.9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.black : AppTheme.lightBg;
    final textColor = isDark ? Colors.white : Colors.black87;

    if (_loading) {
      return Scaffold(
        backgroundColor: bg,
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.facebookBlue),
        ),
      );
    }

    final following =
        context.watch<UserProvider>().isFollowingSeller(widget.sellerId);
    final title = _store?.name ?? _user?.fullName ?? widget.sellerName;
    final avatarUrl =
        ((_store?.logo?.trim().isNotEmpty ?? false) ? _store!.logo : null) ??
            ((_user?.profilePhoto?.trim().isNotEmpty ?? false)
                ? _user!.profilePhoto
                : null);
    final subtitle = (_store?.category != null
            ? AdModel.displayLabel(_store!.category)
            : null) ??
        (_user?.address.city.isNotEmpty == true
            ? '${_user!.address.city}, ${_user!.address.state}'
            : 'Vendedor da comunidade');
    final reviewCount = _reviews.length;
    final averageRating = _averageRating;
    final isStoreProfile = _store != null;
    final ratingLabel =
        '${averageRating.toStringAsFixed(1).replaceAll('.', ',')} ($reviewCount)';
    final locationLabel = ((_store?.address.city.trim().isNotEmpty ?? false)
            ? '${_store!.address.city}, ${_store!.address.state}'
            : ((_user?.address.city.trim().isNotEmpty ?? false)
                ? '${_user!.address.city}, ${_user!.address.state}'
                : 'Localiza\u00e7\u00e3o n\u00e3o informada'))
        .trim();

    Widget infoPill({
      required IconData icon,
      required String text,
      VoidCallback? onTap,
    }) {
      final hasContainerStyle = isStoreProfile;
      final pill = Container(
        padding: hasContainerStyle
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
            : EdgeInsets.zero,
        decoration: hasContainerStyle
            ? BoxDecoration(
                color: isDark ? AppTheme.blackCard : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color:
                      isDark ? AppTheme.blackBorder : const Color(0xFFE5E7EB),
                ),
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: icon == Icons.star_rounded
                  ? const Color(0xFFFFB800)
                  : Colors.grey,
            ),
            const SizedBox(width: 6),
            Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.roboto(
                color: textColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );

      if (onTap == null) return pill;
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: pill,
      );
    }

    final actionButton = _isSelf
        ? SizedBox(
            height: 34,
            child: FilledButton(
              onPressed: widget.sellerId.isEmpty ? null : _openEditProfile,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.facebookBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: GoogleFonts.roboto(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Editar'),
            ),
          )
        : Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: FilledButton(
                    onPressed: widget.sellerId.isEmpty
                        ? null
                        : () {
                            if (context.read<UserProvider>().user == null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const ProfileScreen()),
                              );
                              return;
                            }
                            context
                                .read<UserProvider>()
                                .toggleFollowSeller(widget.sellerId);
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: following
                          ? (isDark
                              ? AppTheme.blackLight
                              : const Color(0xFFE5E7EB))
                          : AppTheme.facebookBlue,
                      foregroundColor: following ? textColor : Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: GoogleFonts.roboto(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text(following ? 'Seguindo' : 'Seguir'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: OutlinedButton.icon(
                    onPressed: _openDirectChat,
                    icon: const Icon(Icons.chat_bubble_rounded, size: 16),
                    label: const Text('Mensagem'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(
                        color: isDark
                            ? AppTheme.blackBorder
                            : const Color(0xFFD1D5DB),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: GoogleFonts.roboto(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );

    return Scaffold(
      backgroundColor: bg,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: isDark ? AppTheme.black : Colors.white,
              elevation: 0,
              title: _buildMarketViewWordmark(isDark),
            )
          : null,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor:
                      AppTheme.facebookBlue.withValues(alpha: 0.10),
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? Text(
                          title.isNotEmpty ? title[0].toUpperCase() : 'V',
                          style: GoogleFonts.roboto(
                            color: AppTheme.facebookBlue,
                            fontWeight: FontWeight.w800,
                            fontSize: 24,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.roboto(
                          color: textColor,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if ((_store?.category.trim().isNotEmpty ?? false) &&
                          subtitle != locationLabel)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            subtitle,
                            style: GoogleFonts.roboto(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          infoPill(
                            icon: Icons.location_on_outlined,
                            text: locationLabel,
                          ),
                          infoPill(
                            icon: Icons.star_rounded,
                            text: ratingLabel,
                            onTap: _openReviews,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      actionButton,
                    ],
                  ),
                ),
              ],
            ),
          ),
          if ((_store?.description ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Text(
                _store!.description,
                style: GoogleFonts.roboto(
                  color: Colors.grey.shade600,
                  fontSize: 13.5,
                  height: 1.35,
                ),
              ),
            ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            child: Text(
              'An\u00fancios',
              style: GoogleFonts.roboto(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _ads.length,
            gridDelegate: _adsGridDelegate(context),
            itemBuilder: (context, index) => AdCard(
              ad: _ads[index],
              index: index,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdDetailScreen(ad: _ads[index]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
