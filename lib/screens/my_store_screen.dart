import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/ad_model.dart';
import '../models/store_model.dart';
import '../providers/user_provider.dart';
import '../services/firestore_service.dart';
import '../store/edit_store_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/ad_card.dart';
import 'ad_detail_screen.dart';
import 'create_ad_screen.dart';
import 'reviews_screen.dart';
import 'store_members_screen.dart';

class MyStoreScreen extends StatefulWidget {
  const MyStoreScreen({
    super.key,
    this.storeId,
  });

  final String? storeId;

  @override
  State<MyStoreScreen> createState() => _MyStoreScreenState();
}

class _MyStoreScreenState extends State<MyStoreScreen> {
  final _firestore = FirestoreService();

  StoreModel? _store;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStore();
  }

  Future<void> _loadStore() async {
    final user = context.read<UserProvider>().user;
    final targetStoreId = widget.storeId ?? user?.primaryStoreId;
    if (targetStoreId == null || targetStoreId.isEmpty) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);
    final store = await _firestore.getStore(targetStoreId);
    if (!mounted) return;
    setState(() {
      _store = store;
      _loading = false;
    });
  }

  Future<void> _toggleStoreStatus() async {
    if (_store == null) return;
    await _firestore.updateStore(_store!.id, {'isActive': !_store!.isActive});
    await _loadStore();
  }

  Future<void> _generateInvite() async {
    final user = context.read<UserProvider>().user;
    final store = _store;
    if (user == null || store == null) return;

    try {
      final invite = await _firestore.generateStoreInvite(
        storeId: store.id,
        adminUserId: user.uid,
      );
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Adicionar membro'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Usuário: ${invite.username}'),
              const SizedBox(height: 8),
              Text('Código: ${invite.code}'),
              const SizedBox(height: 8),
              const Text('Validade: 10 minutos'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
      await _loadStore();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.black : AppTheme.lightBg;
    final textColor = isDark ? Colors.white : Colors.black87;

    if (_loading) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: isDark ? AppTheme.black : Colors.white,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.facebookBlue),
        ),
      );
    }

    if (_store == null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: isDark ? AppTheme.black : Colors.white,
          elevation: 0,
          title: Text(
            'Minha loja',
            style: GoogleFonts.roboto(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: Center(
          child: Text(
            'Loja não encontrada.',
            style: GoogleFonts.roboto(color: textColor),
          ),
        ),
      );
    }

    final store = _store!;
    final isAdmin = store.isAdmin(user?.uid ?? '');
    final mutedColor = isDark ? AppTheme.whiteMuted : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.black : Colors.white,
        elevation: 0,
        title: Text(
          store.name,
          style: GoogleFonts.roboto(
            color: textColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadStore,
        color: AppTheme.facebookBlue,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StoreHeader(store: store, isDark: isDark),
            const SizedBox(height: 16),
            _StoreMetrics(store: store, isDark: isDark),
            const SizedBox(height: 16),
            _SectionCard(
              isDark: isDark,
              title: 'Sobre a loja',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.description.trim().isNotEmpty
                        ? store.description
                        : 'Esta loja ainda não adicionou uma descrição.',
                    style: GoogleFonts.roboto(
                      color: mutedColor,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoPill(
                        icon: Icons.category_rounded,
                        label: AdModel.displayLabel(store.category),
                      ),
                      _InfoPill(
                        icon: Icons.sell_rounded,
                        label: store.type == 'servico'
                            ? 'Serviços'
                            : store.type == 'ambos'
                                ? 'Produtos e serviços'
                                : 'Produtos',
                      ),
                      _InfoPill(
                        icon: store.isActive
                            ? Icons.check_circle_rounded
                            : Icons.pause_circle_rounded,
                        label: store.isActive ? 'Loja ativa' : 'Loja pausada',
                        accent: store.isActive
                            ? AppTheme.success
                            : const Color(0xFFF59E0B),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              isDark: isDark,
              title: 'Informações',
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'Endereço',
                    value: store.address.formatted,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Responsável',
                    value: store.ownerName,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.alternate_email_rounded,
                    label: 'Usuário da loja',
                    value: '@${store.accessUsername}',
                    isDark: isDark,
                    valueColor: AppTheme.facebookBlue,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              isDark: isDark,
              title: 'Avaliações',
              trailing: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReviewsScreen(
                      userId: store.id,
                      allowReply: isAdmin,
                      title: 'Avaliações da loja',
                    ),
                  ),
                ),
                child: const Text('Ver todas'),
              ),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppTheme.facebookBlue.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      store.rating.toStringAsFixed(1),
                      style: GoogleFonts.roboto(
                        color: AppTheme.facebookBlue,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: List.generate(
                            5,
                            (index) => Icon(
                              index < store.rating.round()
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: Colors.amber,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          store.totalReviews > 0
                              ? '${store.totalReviews} avaliações recebidas'
                              : 'Ainda sem avaliações recebidas',
                          style: GoogleFonts.roboto(color: mutedColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              isDark: isDark,
              title: 'Gerenciar loja',
              child: Column(
                children: [
                  _ActionTile(
                    isDark: isDark,
                    label: store.isActive ? 'Pausar loja' : 'Ativar loja',
                    subtitle: store.isActive
                        ? 'Oculta temporariamente os anúncios da loja'
                        : 'Torna a loja visível novamente',
                    icon: store.isActive
                        ? Icons.pause_circle_outline_rounded
                        : Icons.play_circle_outline_rounded,
                    enabled: isAdmin,
                    onTap: isAdmin ? _toggleStoreStatus : null,
                  ),
                  _TileDivider(isDark: isDark),
                  _ActionTile(
                    isDark: isDark,
                    label: 'Adicionar produto / serviço',
                    subtitle: 'Criar anúncio em nome desta loja',
                    icon: Icons.add_business_outlined,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            CreateAdScreen(initialStoreId: store.id),
                      ),
                    ).then((_) => _loadStore()),
                  ),
                  if (isAdmin) ...[
                    _TileDivider(isDark: isDark),
                    _ActionTile(
                      isDark: isDark,
                      label: 'Editar loja',
                      subtitle: 'Alterar logo, banner, dados e endereço',
                      icon: Icons.edit_outlined,
                      onTap: () {
                        final navigator = Navigator.of(context);
                        Navigator.push<Object?>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditStoreScreen(
                              store: store,
                              currentUserId: user?.uid ?? '',
                            ),
                          ),
                        ).then((result) {
                          if (result == 'deleted') {
                            if (mounted) navigator.pop();
                            return;
                          }
                          final updatedStore =
                              result is StoreModel ? result : null;
                          if (updatedStore != null && mounted) {
                            setState(() => _store = updatedStore);
                          }
                          _loadStore();
                        });
                      },
                    ),
                    _TileDivider(isDark: isDark),
                    _ActionTile(
                      isDark: isDark,
                      label: 'Adicionar membro',
                      subtitle: 'Gerar usuário e código válidos por 10 minutos',
                      icon: Icons.person_add_alt_1_outlined,
                      onTap: _generateInvite,
                    ),
                    _TileDivider(isDark: isDark),
                    _ActionTile(
                      isDark: isDark,
                      label: 'Gerenciar membros',
                      subtitle: 'Tornar admin, remover usuário e mais',
                      icon: Icons.groups_outlined,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StoreMembersScreen(storeId: store.id),
                        ),
                      ).then((_) => _loadStore()),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Anúncios da loja',
              style: GoogleFonts.roboto(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<AdModel>>(
              future: _firestore.getAdsByStore(
                store.id,
                includeInactive: true,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(
                        color: AppTheme.facebookBlue,
                      ),
                    ),
                  );
                }

                final ads = snapshot.data ?? const <AdModel>[];
                if (ads.isEmpty) {
                  return _SectionCard(
                    isDark: isDark,
                    title: 'Sem anúncios',
                    child: Text(
                      'Nenhum anúncio da loja por enquanto.',
                      style: GoogleFonts.roboto(color: mutedColor),
                    ),
                  );
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: ads.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    mainAxisExtent: 304,
                  ),
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
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreHeader extends StatelessWidget {
  const _StoreHeader({
    required this.store,
    required this.isDark,
  });

  final StoreModel store;
  final bool isDark;

  bool get _hasBanner =>
      store.banner != null && store.banner!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = isDark ? AppTheme.whiteMuted : Colors.grey.shade600;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.blackCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.blackBorder : const Color(0xFFE8E8E8),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 156,
            width: double.infinity,
            child: _hasBanner
                ? Image.network(
                    store.banner!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _BannerFallback(isDark: isDark),
                  )
                : _BannerFallback(isDark: isDark),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StoreAvatar(
                  imageUrl: store.logo,
                  label: store.name,
                  radius: 34,
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
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AdModel.displayLabel(store.category),
                        style: GoogleFonts.roboto(
                          color: AppTheme.facebookBlue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        store.address.city.isNotEmpty
                            ? '${store.address.city}, ${store.address.state}'
                            : store.address.state,
                        style: GoogleFonts.roboto(color: mutedColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerFallback extends StatelessWidget {
  const _BannerFallback({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF0F172A), Color(0xFF111827)]
              : const [Color(0xFFEFF6FF), Color(0xFFF8FAFC)],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.storefront_rounded,
          color: AppTheme.facebookBlue,
          size: 42,
        ),
      ),
    );
  }
}

class _StoreMetrics extends StatelessWidget {
  const _StoreMetrics({
    required this.store,
    required this.isDark,
  });

  final StoreModel store;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? AppTheme.blackCard : Colors.white;
    final borderColor = isDark ? AppTheme.blackBorder : const Color(0xFFE8E8E8);
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = isDark ? AppTheme.whiteMuted : Colors.grey.shade600;

    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            cardColor: cardColor,
            borderColor: borderColor,
            label: 'Avaliação',
            value: store.rating.toStringAsFixed(1),
            textColor: textColor,
            mutedColor: mutedColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            cardColor: cardColor,
            borderColor: borderColor,
            label: 'Avaliações',
            value: '${store.totalReviews}',
            textColor: textColor,
            mutedColor: mutedColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            cardColor: cardColor,
            borderColor: borderColor,
            label: 'Membros',
            value: '${store.members.length}',
            textColor: textColor,
            mutedColor: mutedColor,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.cardColor,
    required this.borderColor,
    required this.label,
    required this.value,
    required this.textColor,
    required this.mutedColor,
  });

  final Color cardColor;
  final Color borderColor;
  final String label;
  final String value;
  final Color textColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.roboto(
              color: textColor,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.roboto(
              color: mutedColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.isDark,
    required this.title,
    required this.child,
    this.trailing,
  });

  final bool isDark;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.blackCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.blackBorder : const Color(0xFFE8E8E8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.roboto(
                    color: textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    this.accent = AppTheme.facebookBlue,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.roboto(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = isDark ? AppTheme.whiteMuted : Colors.grey.shade600;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.facebookBlue, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.roboto(
                  color: mutedColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.roboto(
                  color: valueColor ?? textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.isDark,
    required this.label,
    required this.subtitle,
    required this.icon,
    this.enabled = true,
    this.onTap,
  });

  final bool isDark;
  final String label;
  final String subtitle;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black87;

    return ListTile(
      onTap: enabled ? onTap : null,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        color: enabled ? AppTheme.facebookBlue : Colors.grey,
      ),
      title: Text(
        label,
        style: GoogleFonts.roboto(
          color: enabled ? textColor : Colors.grey,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.roboto(
          color: isDark ? AppTheme.whiteMuted : Colors.grey.shade600,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: enabled
            ? (isDark ? AppTheme.whiteMuted : Colors.grey.shade600)
            : Colors.grey,
      ),
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 34,
      color: isDark ? AppTheme.blackBorder : const Color(0xFFE8E8E8),
    );
  }
}

class _StoreAvatar extends StatelessWidget {
  const _StoreAvatar({
    required this.imageUrl,
    required this.label,
    required this.radius,
  });

  final String? imageUrl;
  final String label;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';
    final fallback = label.isNotEmpty ? label[0].toUpperCase() : 'L';

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: AppTheme.facebookBlue.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isNotEmpty
          ? Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Text(
                  fallback,
                  style: GoogleFonts.roboto(
                    color: AppTheme.facebookBlue,
                    fontSize: radius * 0.82,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                fallback,
                style: GoogleFonts.roboto(
                  color: AppTheme.facebookBlue,
                  fontSize: radius * 0.82,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
    );
  }
}
