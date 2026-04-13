import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/store_model.dart';
import '../providers/user_provider.dart';
import '../services/firestore_service.dart';
import '../store/create_store_screen.dart';
import '../theme/app_theme.dart';
import 'my_store_screen.dart';
import 'store_access_screen.dart';

class MyStoresScreen extends StatefulWidget {
  const MyStoresScreen({super.key});

  @override
  State<MyStoresScreen> createState() => _MyStoresScreenState();
}

class _MyStoresScreenState extends State<MyStoresScreen> {
  final _firestore = FirestoreService();
  bool _loading = true;
  List<StoreModel> _stores = const [];
  int _lastMarketplaceRefreshTick = -1;

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  Future<void> _loadStores() async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;

    setState(() => _loading = true);
    final stores = await _firestore.getStoresForUser(user.uid);
    if (!mounted) return;
    setState(() {
      _stores = stores;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final marketplaceRefreshTick =
        context.watch<UserProvider>().marketplaceRefreshTick;
    if (_lastMarketplaceRefreshTick != marketplaceRefreshTick) {
      _lastMarketplaceRefreshTick = marketplaceRefreshTick;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadStores();
      });
    }

    final user = context.watch<UserProvider>().user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.black : AppTheme.lightBg;
    final cardBg = isDark ? AppTheme.blackCard : Colors.white;
    final border = isDark ? AppTheme.blackBorder : const Color(0xFFE8E8E8);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? AppTheme.whiteMuted : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.black : Colors.white,
        elevation: 0,
        title: Text(
          'Minhas lojas',
          style: GoogleFonts.roboto(
            color: textColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.facebookBlue),
            )
          : RefreshIndicator(
              onRefresh: _loadStores,
              color: AppTheme.facebookBlue,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_stores.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: border),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.storefront_outlined,
                            size: 52,
                            color: AppTheme.facebookBlue.withValues(alpha: 0.8),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Você ainda não participa de nenhuma loja.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.roboto(
                              color: textColor,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ..._stores.map((store) {
                    final canManage = store.isAdmin(user?.uid ?? '');
                    final logoUrl = store.logo?.trim() ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MyStoreScreen(storeId: store.id),
                          ),
                        ).then((_) => _loadStores()),
                        child: Ink(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: border),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor:
                                    AppTheme.facebookBlue.withValues(alpha: 0.10),
                                backgroundImage: logoUrl.isNotEmpty
                                    ? NetworkImage(logoUrl)
                                    : null,
                                child: logoUrl.isEmpty
                                    ? Text(
                                        store.name.isNotEmpty
                                            ? store.name[0].toUpperCase()
                                            : 'L',
                                        style: GoogleFonts.roboto(
                                          color: AppTheme.facebookBlue,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 24,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      store.name,
                                      style: GoogleFonts.roboto(
                                        color: textColor,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      canManage ? 'Administrador' : 'Membro',
                                      style: GoogleFonts.roboto(
                                        color: AppTheme.facebookBlue,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${store.members.length} membros',
                                      style: GoogleFonts.roboto(
                                        color: subColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: subColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: user == null
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CreateStoreScreen(userId: user.uid),
                              ),
                            ).then((_) => _loadStores()),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.facebookBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppTheme.facebookBlue.withValues(alpha: 0.20),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.add_circle_outline_rounded,
                            color: AppTheme.facebookBlue,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Criar nova loja +',
                            style: GoogleFonts.roboto(
                              color: AppTheme.facebookBlue,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StoreJoinScreen(),
                      ),
                    ).then((_) => _loadStores()),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: border),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.login_rounded,
                            color: AppTheme.facebookBlue,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Entrar nova loja +',
                            style: GoogleFonts.roboto(
                              color: AppTheme.facebookBlue,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
