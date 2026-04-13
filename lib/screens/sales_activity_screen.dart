import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ad_model.dart';
import '../providers/user_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

class SalesActivityScreen extends StatefulWidget {
  const SalesActivityScreen({super.key});

  @override
  State<SalesActivityScreen> createState() => _SalesActivityScreenState();
}

class _SalesActivityScreenState extends State<SalesActivityScreen> {
  final _firestore = FirestoreService();
  bool _loading = true;
  Map<String, dynamic> _insights = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;
    final insights = await _firestore.getSalesInsights(
      user.uid,
      storeId: user.primaryStoreId,
    );
    if (!mounted) return;
    setState(() {
      _insights = insights;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mostViewed = (_insights['mostViewed'] as List<AdModel>? ?? []);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.black : AppTheme.lightBg,
      appBar: AppBar(title: const Text('Atividades de venda')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.facebookBlue))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _StatCard(
                    title: 'Anúncios ativos',
                    value: '${_insights['totalAds'] ?? 0}'),
                _StatCard(
                    title: 'Cliques totais',
                    value: '${_insights['totalClicks'] ?? 0}'),
                _StatCard(
                    title: 'Média de cliques',
                    value:
                        '${(_insights['averageClicks'] ?? 0.0).toStringAsFixed(1)}'),
                const SizedBox(height: 16),
                const Text('Mais vistos'),
                const SizedBox(height: 8),
                ...mostViewed.map(
                  (ad) => ListTile(
                    title: Text(ad.title),
                    subtitle: Text('${ad.clickCount} cliques'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;

  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.blackCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          const SizedBox(height: 6),
          Text(value,
              style:
                  const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
