import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/ad_model.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ad_card.dart';
import 'ad_detail_screen.dart';

class CategoryAdsScreen extends StatefulWidget {
  final String category;
  final IconData icon;

  const CategoryAdsScreen({
    super.key,
    required this.category,
    required this.icon,
  });

  @override
  State<CategoryAdsScreen> createState() => _CategoryAdsScreenState();
}

class _CategoryAdsScreenState extends State<CategoryAdsScreen> {
  final _firestore = FirestoreService();
  final _scrollCtrl = ScrollController();

  List<AdModel> _ads = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;

  @override
  void initState() {
    super.initState();
    _loadAds();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 300) {
      if (!_loadingMore && _hasMore) _loadMore();
    }
  }

  Future<void> _loadAds() async {
    setState(() => _loading = true);
    try {
      final result = await _firestore.getAdsByCategoryPaginated(
        widget.category,
        limit: 20,
      );
      final ads = result['ads'] as List<AdModel>;
      if (mounted) {
        setState(() {
          _ads = ads;
          _lastDoc = result['lastDoc'] as DocumentSnapshot?;
          _hasMore = ads.length == 20;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final result = await _firestore.getAdsByCategoryPaginated(
        widget.category,
        limit: 20,
        startAfter: _lastDoc,
      );
      final newAds = result['ads'] as List<AdModel>;
      if (mounted) {
        setState(() {
          _ads.addAll(newAds);
          _lastDoc = result['lastDoc'] as DocumentSnapshot?;
          _hasMore = newAds.length == 20;
          _loadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.black : AppTheme.lightBg;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.black : Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.blackLight : const Color(0xFFF0F2F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.arrow_back_rounded, color: textColor, size: 22),
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.facebookBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(widget.icon, color: AppTheme.facebookBlue, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              widget.category,
              style: GoogleFonts.outfit(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: isDark ? AppTheme.blackBorder : const Color(0xFFE8E8E8),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.facebookBlue))
          : _ads.isEmpty
              ? _buildEmpty(isDark, textColor)
              : RefreshIndicator(
                  onRefresh: _loadAds,
                  color: AppTheme.facebookBlue,
                  child: CustomScrollView(
                    controller: _scrollCtrl,
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.all(12),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.72,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final ad = _ads[i];
                              return AdCard(
                                ad: ad,
                                index: i,
                                onTap: () {
                                  _firestore.incrementAdClick(ad.id);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AdDetailScreen(ad: ad),
                                    ),
                                  );
                                },
                              );
                            },
                            childCount: _ads.length,
                          ),
                        ),
                      ),
                      if (_loadingMore)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: CircularProgressIndicator(color: AppTheme.facebookBlue),
                            ),
                          ),
                        ),
                      if (!_hasMore && _ads.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                'Você viu todos os anúncios de ${widget.category}',
                                style: GoogleFonts.outfit(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmpty(bool isDark, Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppTheme.facebookBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(widget.icon, color: AppTheme.facebookBlue, size: 44),
          ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
          const SizedBox(height: 20),
          Text(
            'Nenhum anúncio em ${widget.category}',
            style: GoogleFonts.outfit(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ).animate(delay: 100.ms).fadeIn(),
          const SizedBox(height: 8),
          Text(
            'Seja o primeiro a anunciar nesta categoria!',
            style: GoogleFonts.outfit(color: Colors.grey, fontSize: 14),
          ).animate(delay: 160.ms).fadeIn(),
        ],
      ),
    );
  }
}
