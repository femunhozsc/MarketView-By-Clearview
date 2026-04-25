import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ad_model.dart';
import '../providers/user_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ad_card.dart';
import 'ad_detail_screen.dart';

class RecentlyViewedScreen extends StatefulWidget {
  const RecentlyViewedScreen({super.key});

  @override
  State<RecentlyViewedScreen> createState() => _RecentlyViewedScreenState();
}

class _RecentlyViewedScreenState extends State<RecentlyViewedScreen> {
  final _firestore = FirestoreService();
  bool _loading = true;
  List<AdModel> _ads = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ids = context.read<UserProvider>().user?.recentlyViewedAdIds ?? [];
    final ads = await _firestore.getAdsByIds(ids);
    if (!mounted) return;
    setState(() {
      _ads = ads;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppTheme.black : AppTheme.lightBg,
      appBar: AppBar(title: const Text('Vistos recentemente')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.facebookBlue))
          : GridView.builder(
              padding: EdgeInsets.zero,
              gridDelegate: AdCard.gridDelegate(context),
              itemCount: _ads.length,
              itemBuilder: (context, index) => AdCard(
                ad: _ads[index],
                index: index,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AdDetailScreen(ad: _ads[index])),
                ),
              ),
            ),
    );
  }
}
