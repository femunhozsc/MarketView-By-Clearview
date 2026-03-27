import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/ad_model.dart';
import '../models/store_model.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/ad_card.dart';
import '../widgets/pill_sections.dart';
import '../widgets/top_bar.dart';
import 'create_ad_screen.dart';
import 'ad_detail_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'seller_profile_screen.dart';
import 'for_you_screen.dart';
import 'category_ads_screen.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../providers/user_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // Pílulas: 0=Para Você, 1=Produtos, 2=Serviços, 3=Lojas, 4=Categorias, 5=Favoritos
  int _selectedSection = 0;
  int _selectedNavIndex = 0;
  bool _isDrawerOpen = false;
  bool _isSearching = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  late AnimationController _drawerCtrl;
  late Animation<double> _drawerAnim;

  @override
  void initState() {
    super.initState();
    _loadAds();
    _drawerCtrl = AnimationController(
      duration: const Duration(milliseconds: 320),
      vsync: this,
    );
    _drawerAnim =
        CurvedAnimation(parent: _drawerCtrl, curve: Curves.easeInOutCubic);
  }

  @override
  void dispose() {
    _drawerCtrl.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleDrawer() {
    setState(() => _isDrawerOpen = !_isDrawerOpen);
    _isDrawerOpen ? _drawerCtrl.forward() : _drawerCtrl.reverse();
  }

  final _firestore = FirestoreService();
  List<AdModel> _realAds = [];
  List<StoreModel> _realStores = [];
  bool _isLoadingAds = false;

  Future<void> _loadAds() async {
    setState(() => _isLoadingAds = true);
    try {
      final ads = await _firestore.getAds();
      final stores = await _firestore.getStores();
      setState(() {
        _realAds = ads;
        _realStores = stores;
      });
    } finally {
      setState(() => _isLoadingAds = false);
    }
  }

  List<AdModel> get _filteredAds {
    List<AdModel> ads = _realAds.isEmpty ? sampleAds : _realAds;
    
    // Pílulas: 0=Para Você, 1=Produtos, 2=Serviços, 3=Lojas, 4=Categorias, 5=Favoritos
    switch (_selectedSection) {
      case 1: // Produtos
        ads = ads.where((a) => a.type == 'produto').toList();
        break;
      case 2: // Serviços
        ads = ads.where((a) => a.type == 'servico').toList();
        break;
      case 5: // Favoritos
        final user = context.read<UserProvider>().user;
        if (user != null) {
          ads = ads.where((a) => user.favoriteAdIds.contains(a.id)).toList();
        } else {
          ads = [];
        }
        break;
    }
    
    if (_searchQuery.isNotEmpty) {
      ads = ads
          .where((a) =>
              a.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              a.category.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    return ads;
  }

  // ── Navega para tela de acordo com índice da barra inferior
  Widget _getScreen() {
    switch (_selectedNavIndex) {
      case 3:
        return const ChatScreen();
      case 4:
        return const ProfileScreen();
      default:
        return _buildHomeContent();
    }
  }

  Widget _buildHomeContent() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        if (!_isSearching)
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.black : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? AppTheme.blackBorder
                      : const Color(0xFFE0E0E0),
                  width: 1,
                ),
              ),
            ),
            child: PillSections(
              onSectionChanged: (i) => setState(() => _selectedSection = i),
            ),
          ),
        Expanded(
          child: _buildSectionContent(isDark),
        ),
      ],
    );
  }

  Widget _buildSectionContent(bool isDark) {
    switch (_selectedSection) {
      case 0: // Para Você
        return ForYouScreen(
          onViewMoreStores: () {
            setState(() => _selectedSection = 3);
          },
        );
      case 3: // Lojas
        return _buildStoresGrid(isDark);
      case 4: // Categorias
        return _buildCategoriesGrid(isDark);
      default: // Produtos, Serviços, Favoritos
        return _buildFeed(isDark);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.black : AppTheme.lightBg;

    return Scaffold(
      backgroundColor: bg,
      appBar: (_selectedNavIndex == 3 || _selectedNavIndex == 4)
          ? null
          : (_isSearching
              ? _buildSearchBar(isDark)
              : MarketViewTopBar(
                  onMenuTap: _toggleDrawer,
                  onSearchTap: () => setState(() => _isSearching = true),
                  onNotificationTap: () => _showNotifications(context),
                  onLogoTap: () => setState(() {
                    _selectedNavIndex = 0;
                    _selectedSection = 0;
                  }),
                )),
      body: Stack(
        children: [
          _getScreen(),

          // Overlay escuro
          if (_isDrawerOpen)
            GestureDetector(
              onTap: _toggleDrawer,
              child: AnimatedBuilder(
                animation: _drawerAnim,
                builder: (_, __) => Container(
                  color: Colors.black.withOpacity(0.55 * _drawerAnim.value),
                ),
              ),
            ),

          // Drawer
          AnimatedBuilder(
            animation: _drawerAnim,
            builder: (_, child) => Transform.translate(
              offset: Offset(280 * (1 - _drawerAnim.value), 0),
              child: child,
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: _buildDrawer(isDark),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(isDark),
    );
  }

  // ── SearchBar ──────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildSearchBar(bool isDark) {
    return AppBar(
      backgroundColor: isDark ? AppTheme.black : Colors.white,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: GoogleFonts.outfit(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: 'Buscar produtos, serviços...',
                  hintStyle:
                      GoogleFonts.outfit(color: Colors.grey, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: Colors.grey, size: 22),
                  filled: true,
                  fillColor: isDark
                      ? AppTheme.blackLight
                      : const Color(0xFFF0F2F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => setState(() {
                _isSearching = false;
                _searchQuery = '';
                _searchController.clear();
              }),
              child: Text(
                'Cancelar',
                style: GoogleFonts.outfit(
                  color: AppTheme.facebookBlue,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: isDark ? AppTheme.blackBorder : const Color(0xFFE0E0E0),
        ),
      ),
    );
  }

  // ── Feed de anúncios ───────────────────────────────────────────────────────
  Widget _buildFeed(bool isDark) {
    if (_isLoadingAds) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.facebookBlue),
      );
    }

    final ads = _filteredAds;

    if (ads.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded,
                color: Colors.grey.shade300, size: 72),
            const SizedBox(height: 16),
            Text(
              'Nenhum anúncio encontrado',
              style: GoogleFonts.outfit(
                color: Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ).animate().fadeIn(),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(
                  '${ads.length} anúncios',
                  style: GoogleFonts.outfit(
                      color: Colors.grey,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ).animate().fadeIn(delay: 150.ms),
                const Spacer(),
                _filterBtn(isDark),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final ad = ads[index];
                return AdCard(
                  ad: ad,
                  index: index,
                  onTap: () {
                    // Rastreia interesse na categoria
                    context.read<UserProvider>().trackCategoryClick(ad.category);
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, anim, __) =>
                            AdDetailScreen(ad: ad),
                        transitionsBuilder: (_, anim, __, child) =>
                            FadeTransition(opacity: anim, child: child),
                      ),
                    );
                  },
                );
              },
              childCount: ads.length,
            ),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.68,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStoresGrid(bool isDark) {
    if (_realStores.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_outlined, color: Colors.grey.shade300, size: 72),
            const SizedBox(height: 16),
            Text(
              'Nenhuma loja encontrada',
              style: GoogleFonts.outfit(
                color: Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ).animate().fadeIn(),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1,
        mainAxisSpacing: 16,
        childAspectRatio: 2.5,
      ),
      itemCount: _realStores.length,
      itemBuilder: (context, index) {
        final store = _realStores[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SellerProfileScreen(
                  sellerId: store.ownerId,
                  sellerName: store.name,
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.blackCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppTheme.blackBorder : const Color(0xFFE8E8E8)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                  child: store.logo != null
                      ? Image.network(store.logo!, width: 120, height: double.infinity, fit: BoxFit.cover)
                      : Container(width: 120, color: Colors.grey.shade200, child: const Icon(Icons.store, size: 40)),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(store.name, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
                        Text(store.category, style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.facebookBlue, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(store.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _filterBtn(bool isDark) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.blackLight : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark
                ? AppTheme.blackBorder
                : const Color(0xFFE0E0E0),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.tune_rounded,
                color: isDark
                    ? AppTheme.whiteSecondary
                    : Colors.grey.shade600,
                size: 17),
            const SizedBox(width: 6),
            Text(
              'Filtrar',
              style: GoogleFonts.outfit(
                color: isDark
                    ? AppTheme.whiteSecondary
                    : Colors.grey.shade600,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ).animate().fadeIn(delay: 150.ms),
    );
  }

  // ── Categorias ─────────────────────────────────────────────────────────────
  Widget _buildCategoriesGrid(bool isDark) {
    final icons = [
      Icons.devices_rounded, Icons.directions_car_rounded,
      Icons.home_rounded, Icons.chair_rounded,
      Icons.checkroom_rounded, Icons.sports_soccer_rounded,
      Icons.design_services_rounded, Icons.school_rounded,
      Icons.health_and_safety_rounded,
      Icons.face_retouching_natural_rounded,
      Icons.pets_rounded, Icons.sell_rounded,
    ];
    final colors = [
      const Color(0xFF1877F2), const Color(0xFFE74C3C),
      const Color(0xFF27AE60), const Color(0xFFE67E22),
      const Color(0xFF9B59B6), const Color(0xFF2ECC71),
      const Color(0xFF3498DB), const Color(0xFF1ABC9C),
      const Color(0xFFE91E63), const Color(0xFFFF5722),
      const Color(0xFF795548), const Color(0xFF607D8B),
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: categories.length,
      itemBuilder: (context, i) {
        return GestureDetector(
          onTap: () {
            // Rastreia interesse
            context.read<UserProvider>().trackCategoryClick(categories[i]);
            // Navega para tela da categoria
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CategoryAdsScreen(
                  category: categories[i],
                  icon: icons[i],
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.blackCard : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? AppTheme.blackBorder
                    : const Color(0xFFE8E8E8),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: colors[i].withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icons[i], color: colors[i], size: 26),
                ),
                const SizedBox(height: 8),
                Text(
                  categories[i],
                  style: GoogleFonts.outfit(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          )
              .animate(delay: Duration(milliseconds: i * 50))
              .fadeIn(duration: 300.ms)
              .scale(
                begin: const Offset(0.85, 0.85),
                end: const Offset(1, 1),
              ),
        );
      },
    );
  }

  // ── Drawer ─────────────────────────────────────────────────────────────────
  Widget _buildDrawer(bool isDark) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = context.watch<UserProvider>().user;
    final bg = isDark ? AppTheme.blackCard : Colors.white;
    final border = isDark ? AppTheme.blackBorder : const Color(0xFFE0E0E0);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? AppTheme.whiteSecondary : Colors.grey.shade600;

    return Container(
      width: 280,
      height: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        border: Border(left: BorderSide(color: border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 20,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppTheme.facebookBlue.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppTheme.facebookBlue.withOpacity(0.3)),
                    ),
                    child: user?.profilePhoto != null
                        ? ClipOval(
                            child: Image.network(
                              user!.profilePhoto!,
                              fit: BoxFit.cover,
                              width: 52,
                              height: 52,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.person_rounded,
                                  color: AppTheme.facebookBlue,
                                  size: 28),
                            ),
                          )
                        : const Icon(Icons.person_rounded,
                            color: AppTheme.facebookBlue, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Olá, ${user?.firstName ?? 'Visitante'}!',
                            style: GoogleFonts.outfit(
                                color: textColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 17)),
                        Text('Ver perfil',
                            style: GoogleFonts.outfit(
                                color: AppTheme.facebookBlue,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Divider(color: border, height: 1),

            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    themeProvider.isDarkMode
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    color: subColor,
                    size: 22,
                  ),
                  const SizedBox(width: 14),
                  Text('Modo escuro',
                      style: GoogleFonts.outfit(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Switch(
                    value: themeProvider.isDarkMode,
                    onChanged: (_) => themeProvider.toggleTheme(),
                    activeColor: AppTheme.facebookBlue,
                  ),
                ],
              ),
            ),

            Divider(color: border, height: 1),

            _drawerItem(Icons.person_outline_rounded, 'Meu Perfil', textColor, subColor,
                onTap: () => setState(() => _selectedNavIndex = 4)),
            _drawerItem(Icons.store_outlined, 'Minha Loja', textColor, subColor,
                onTap: () => setState(() => _selectedNavIndex = 4)),
            _drawerItem(Icons.sell_outlined, 'Meus Anúncios', textColor, subColor,
                onTap: () => setState(() => _selectedNavIndex = 4)),
            _drawerItem(Icons.favorite_outline_rounded, 'Favoritos', textColor, subColor,
                onTap: () => setState(() {
                  _selectedNavIndex = 0;
                  _selectedSection = 5;
                })),
            _drawerItem(Icons.chat_bubble_outline_rounded, 'Mensagens', textColor, subColor,
                onTap: () => setState(() => _selectedNavIndex = 3)),
            _drawerItem(Icons.settings_outlined, 'Configurações', textColor, subColor),

            const SizedBox(height: 20),

            Divider(color: border, height: 1),

            _drawerItem(Icons.logout_rounded, 'Sair', Colors.red, Colors.red,
                isDestructive: true, onTap: () async {
                  await AuthService().logout();
                  if (mounted) context.read<UserProvider>().clear();
                }),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'MarketView by Clearview Dev',
                  style: GoogleFonts.outfit(
                      color: Colors.grey.shade400, fontSize: 11),
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawerItem(
    IconData icon,
    String label,
    Color textColor,
    Color iconColor, {
    bool isDestructive = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: () {
        _toggleDrawer();
        if (onTap != null) onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 14),
            Text(label,
                style: GoogleFonts.outfit(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            if (!isDestructive)
              Icon(Icons.chevron_right_rounded,
                  color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }

  // ── Bottom Nav ─────────────────────────────────────────────────────────────
  Widget _buildBottomNav(bool isDark) {
    final bg = isDark ? AppTheme.blackCard : Colors.white;
    final border = isDark ? AppTheme.blackBorder : const Color(0xFFE0E0E0);
    final active = AppTheme.facebookBlue;
    final inactive = isDark ? AppTheme.whiteMuted : Colors.grey.shade500;

    final items = [
      {'icon': Icons.home_rounded, 'label': 'Início'},
      {'icon': Icons.search_rounded, 'label': 'Buscar'},
      null, // botão +
      {'icon': Icons.chat_bubble_outline_rounded, 'label': 'Chat'},
      {'icon': Icons.person_outline_rounded, 'label': 'Perfil'},
    ];

    return Container(
      height: 75,
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(items.length, (index) {
          if (items[index] == null) {
            return Expanded(
              child: InkWell(
                onTap: _openCreateAd,
                child: Center(
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppTheme.facebookBlue,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.facebookBlue.withOpacity(0.35),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: Colors.white, size: 28),
                  )
                      .animate(onPlay: (c) => c.repeat())
                      .shimmer(
                        delay: 3000.ms,
                        duration: 1000.ms,
                        color: Colors.white.withOpacity(0.25),
                      ),
                ),
              ),
            );
          }

          final item = items[index]!;
          final isActive = _selectedNavIndex == index;

          return Expanded(
            child: InkWell(
              onTap: () {
                setState(() => _selectedNavIndex = index);
                if (index == 0) setState(() => _selectedSection = 0);
                if (index == 1) setState(() => _isSearching = true);
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isActive
                          ? active.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item['icon'] as IconData,
                      color: isActive ? active : inactive,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item['label'] as String,
                    style: GoogleFonts.outfit(
                      color: isActive ? active : inactive,
                      fontSize: 11,
                      fontWeight: isActive
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  void _openCreateAd() async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => const CreateAdScreen(),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
    // Recarrega os anúncios se um novo foi criado
    _loadAds();
  }

  void _showNotifications(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.blackCard : Colors.white,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            const SizedBox(height: 24),
            Text('Notificações',
                style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 60),
            Icon(Icons.notifications_none_rounded,
                size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Nenhuma notificação',
                style: GoogleFonts.outfit(
                    color: Colors.grey,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
