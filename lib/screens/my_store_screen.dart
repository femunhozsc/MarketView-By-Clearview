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
  int _selectedTabIndex = 0;

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
              Text('Usuario: ${invite.username}'),
              const SizedBox(height: 8),
              Text('Codigo: ${invite.code}'),
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
    const bg = Color(0xFFF3F4F6);

    if (_loading) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
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
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          title: Text(
            'Minha loja',
            style: GoogleFonts.roboto(
              color: Colors.black87,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: Center(
          child: Text(
            'Loja nao encontrada.',
            style: GoogleFonts.roboto(color: Colors.black87),
          ),
        ),
      );
    }

    final store = _store!;
    final isAdmin = store.isAdmin(user?.uid ?? '');

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Text(
          store.name,
          style: GoogleFonts.roboto(
            color: Colors.black87,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadStore,
        color: AppTheme.facebookBlue,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _MyStoreHero(
              store: store,
              isAdmin: isAdmin,
              onEdit: isAdmin
                  ? () {
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
                    }
                  : null,
              onOpenReviews: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReviewsScreen(
                    userId: store.id,
                    allowReply: isAdmin,
                    title: 'Avaliacoes da loja',
                  ),
                ),
              ),
            ),
            if (store.description.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Text(
                  store.description,
                  style: GoogleFonts.roboto(
                    color: Colors.grey.shade700,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
              ),
            const SizedBox(height: 18),
            _StoreTabs(
              selectedIndex: _selectedTabIndex,
              onChanged: (index) => setState(() => _selectedTabIndex = index),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _selectedTabIndex == 0
                  ? _StoreAdsSection(
                      key: const ValueKey('my-store-ads'),
                      storeId: store.id,
                      firestore: _firestore,
                    )
                  : _StoreManageSection(
                      key: const ValueKey('my-store-manage'),
                      store: store,
                      isAdmin: isAdmin,
                      onToggleStatus: isAdmin ? _toggleStoreStatus : null,
                      onCreateAd: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CreateAdScreen(initialStoreId: store.id),
                        ),
                      ).then((_) => _loadStore()),
                      onEditStore: isAdmin
                          ? () {
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
                            }
                          : null,
                      onGenerateInvite: isAdmin ? _generateInvite : null,
                      onManageMembers: isAdmin
                          ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      StoreMembersScreen(storeId: store.id),
                                ),
                              ).then((_) => _loadStore())
                          : null,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyStoreHero extends StatelessWidget {
  const _MyStoreHero({
    required this.store,
    required this.isAdmin,
    required this.onOpenReviews,
    this.onEdit,
  });

  final StoreModel store;
  final bool isAdmin;
  final VoidCallback onOpenReviews;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final location = store.address.city.trim().isNotEmpty
        ? '${store.address.city} - ${store.address.state}'
        : store.address.state;
    final statusLabel = store.isActive ? 'Loja ativa' : 'Loja pausada';
    final statusColor =
        store.isActive ? AppTheme.success : const Color(0xFFF59E0B);
    final fallbackLetter =
        store.name.isNotEmpty ? store.name[0].toUpperCase() : 'L';

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              height: 180,
              width: double.infinity,
              child: store.banner?.trim().isNotEmpty == true
                  ? _StableStoreBannerImage(
                      imageUrl: store.banner!,
                      fallback: const _StoreBannerFallback(),
                    )
                  : const _StoreBannerFallback(),
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
                child: store.logo?.trim().isNotEmpty == true
                    ? Image.network(
                        store.logo!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _StoreAvatarFallback(letter: fallbackLetter),
                      )
                    : _StoreAvatarFallback(letter: fallbackLetter),
              ),
            ),
          ],
        ),
        const SizedBox(height: 44),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      style: GoogleFonts.roboto(
                        color: Colors.black87,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      location,
                      style: GoogleFonts.roboto(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        InkWell(
                          onTap: onOpenReviews,
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7E6),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 16,
                                  color: Color(0xFFFFB800),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  store.rating
                                      .toStringAsFixed(1)
                                      .replaceAll('.', ','),
                                  style: GoogleFonts.roboto(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '(${store.totalReviews} avaliacoes)',
                                  style: GoogleFonts.roboto(
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusLabel,
                            style: GoogleFonts.roboto(
                              color: statusColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              if (onEdit != null)
                SizedBox(
                  height: 38,
                  child: FilledButton(
                    onPressed: onEdit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.facebookBlue,
                      foregroundColor: Colors.white,
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
                    child: Text(isAdmin ? 'Editar loja' : 'Ver loja'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StoreBannerFallback extends StatelessWidget {
  const _StoreBannerFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFDBEAFE),
            Color(0xFFE0F2FE),
            Color(0xFFF8FAFC),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.storefront_rounded,
          size: 48,
          color: AppTheme.facebookBlue.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}

class _StableStoreBannerImage extends StatelessWidget {
  const _StableStoreBannerImage({
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

class _StoreAvatarFallback extends StatelessWidget {
  const _StoreAvatarFallback({required this.letter});

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

class _StoreTabs extends StatelessWidget {
  const _StoreTabs({
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
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
            child: _StoreTabButton(
              label: 'Todos os anuncios',
              active: selectedIndex == 0,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _StoreTabButton(
              label: 'Gerenciar',
              active: selectedIndex == 1,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreTabButton extends StatelessWidget {
  const _StoreTabButton({
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

class _StoreAdsSection extends StatelessWidget {
  const _StoreAdsSection({
    super.key,
    required this.storeId,
    required this.firestore,
  });

  final String storeId;
  final FirestoreService firestore;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdModel>>(
      future: firestore.getAdsByStore(
        storeId,
        includeInactive: true,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.facebookBlue),
            ),
          );
        }

        final ads = snapshot.data ?? const <AdModel>[];
        if (ads.isEmpty) {
          return const _ManageEmptyCard(
            title: 'Sem anuncios',
            message: 'Nenhum anuncio da loja por enquanto.',
          );
        }

        return GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: ads.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 0,
            mainAxisSpacing: 0,
            mainAxisExtent: 246,
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
    );
  }
}

class _StoreManageSection extends StatelessWidget {
  const _StoreManageSection({
    super.key,
    required this.store,
    required this.isAdmin,
    required this.onCreateAd,
    this.onToggleStatus,
    this.onEditStore,
    this.onGenerateInvite,
    this.onManageMembers,
  });

  final StoreModel store;
  final bool isAdmin;
  final VoidCallback onCreateAd;
  final VoidCallback? onToggleStatus;
  final VoidCallback? onEditStore;
  final VoidCallback? onGenerateInvite;
  final VoidCallback? onManageMembers;

  @override
  Widget build(BuildContext context) {
    final infoChips = <Widget>[
      _InfoChip(
        icon: Icons.category_rounded,
        label: AdModel.displayLabel(store.category),
      ),
      _InfoChip(
        icon: Icons.sell_rounded,
        label: store.type == 'servico'
            ? 'Servicos'
            : store.type == 'ambos'
                ? 'Produtos e servicos'
                : 'Produtos',
      ),
      if (store.hasDelivery)
        const _InfoChip(
          icon: Icons.local_shipping_outlined,
          label: 'Entrega',
        ),
      if (store.hasInstallments)
        const _InfoChip(
          icon: Icons.credit_card_rounded,
          label: 'Parcelamento',
        ),
    ];

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _ManageCard(
            title: 'Resumo da loja',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...infoChips,
                _InfoChip(
                  icon: Icons.groups_rounded,
                  label: '${store.members.length} membros',
                ),
                _InfoChip(
                  icon: Icons.alternate_email_rounded,
                  label: '@${store.accessUsername}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ManageCard(
            title: 'Informacoes',
            child: Column(
              children: [
                _ManageInfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Endereco',
                  value: store.address.formatted,
                ),
                const SizedBox(height: 14),
                _ManageInfoRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Responsavel',
                  value: store.ownerName,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ManageCard(
            title: 'Acoes',
            child: Column(
              children: [
                _ManageActionTile(
                  label: 'Adicionar produto / servico',
                  subtitle: 'Criar anuncio em nome desta loja',
                  icon: Icons.add_business_outlined,
                  onTap: onCreateAd,
                ),
                if (isAdmin) ...[
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  _ManageActionTile(
                    label: store.isActive ? 'Pausar loja' : 'Ativar loja',
                    subtitle: store.isActive
                        ? 'Oculta temporariamente os anuncios da loja'
                        : 'Torna a loja visivel novamente',
                    icon: store.isActive
                        ? Icons.pause_circle_outline_rounded
                        : Icons.play_circle_outline_rounded,
                    onTap: onToggleStatus,
                  ),
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  _ManageActionTile(
                    label: 'Editar loja',
                    subtitle: 'Alterar logo, banner, dados e endereco',
                    icon: Icons.edit_outlined,
                    onTap: onEditStore,
                  ),
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  _ManageActionTile(
                    label: 'Adicionar membro',
                    subtitle: 'Gerar usuario e codigo validos por 10 minutos',
                    icon: Icons.person_add_alt_1_outlined,
                    onTap: onGenerateInvite,
                  ),
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  _ManageActionTile(
                    label: 'Gerenciar membros',
                    subtitle: 'Tornar admin, remover usuario e mais',
                    icon: Icons.groups_outlined,
                    onTap: onManageMembers,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ManageCard extends StatelessWidget {
  const _ManageCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.roboto(
              color: Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.facebookBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.facebookBlue),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.roboto(
              color: AppTheme.facebookBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ManageInfoRow extends StatelessWidget {
  const _ManageInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
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
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: GoogleFonts.roboto(
                  color: Colors.black87,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ManageActionTile extends StatelessWidget {
  const _ManageActionTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppTheme.facebookBlue),
      title: Text(
        label,
        style: GoogleFonts.roboto(
          color: Colors.black87,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.roboto(
          color: Colors.grey.shade600,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: Colors.grey,
      ),
    );
  }
}

class _ManageEmptyCard extends StatelessWidget {
  const _ManageEmptyCard({
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
              Icons.store_mall_directory_outlined,
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
