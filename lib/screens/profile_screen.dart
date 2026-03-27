import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
// import '../theme/theme_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../store/create_store_screen.dart';
// Novas telas
import 'my_ads_screen.dart';
import 'favorites_screen.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'help_screen.dart';
import 'my_store_screen.dart';
// Chat já existe
import 'chat_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userProvider = context.watch<UserProvider>();

    if (userProvider.isLoggedIn && userProvider.user != null) {
      return _LoggedInProfile(isDark: isDark, userProvider: userProvider);
    } else {
      return _GuestProfile(isDark: isDark);
    }
  }
}

// ── Perfil quando NÃO está logado ──────────────────────────────────────────
class _GuestProfile extends StatelessWidget {
  final bool isDark;
  const _GuestProfile({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppTheme.black : AppTheme.lightBg;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppTheme.facebookBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded,
                    color: AppTheme.facebookBlue, size: 52),
              ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
              const SizedBox(height: 28),
              Text(
                'Olá, visitante!',
                style: GoogleFonts.outfit(
                  color: textColor, fontSize: 26, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ).animate(delay: 100.ms).fadeIn(),
              const SizedBox(height: 10),
              Text(
                'Entre ou crie sua conta para anunciar produtos, serviços, criar sua loja e muito mais!',
                style: GoogleFonts.outfit(color: Colors.grey, fontSize: 14, height: 1.5),
                textAlign: TextAlign.center,
              ).animate(delay: 160.ms).fadeIn(),
              const Spacer(),
              ...[
                'Anunciar produtos e serviços',
                'Criar sua loja virtual',
                'Conversar com vendedores',
                'Salvar favoritos',
              ].asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: AppTheme.facebookBlue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: AppTheme.facebookBlue, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      e.value,
                      style: GoogleFonts.outfit(
                        color: textColor, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ).animate(delay: Duration(milliseconds: 200 + e.key * 60)).fadeIn(),
              )),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.facebookBlue,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.facebookBlue.withOpacity(0.3),
                        blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Text('Entrar',
                    style: GoogleFonts.outfit(
                        color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center),
                ),
              ).animate(delay: 500.ms).fadeIn().slideY(begin: 0.2, end: 0),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.blackLight : const Color(0xFFF0F2F5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? AppTheme.blackBorder : const Color(0xFFE0E0E0)),
                  ),
                  child: Text('Criar conta gratuita',
                    style: GoogleFonts.outfit(
                        color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center),
                ),
              ).animate(delay: 560.ms).fadeIn().slideY(begin: 0.2, end: 0),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Perfil quando ESTÁ logado ───────────────────────────────────────────────
class _LoggedInProfile extends StatelessWidget {
  final bool isDark;
  final UserProvider userProvider;

  const _LoggedInProfile({required this.isDark, required this.userProvider});

  @override
  Widget build(BuildContext context) {
    final user = userProvider.user!;
    final bg = isDark ? AppTheme.black : AppTheme.lightBg;
    final cardBg = isDark ? AppTheme.blackCard : Colors.white;
    final border = isDark ? AppTheme.blackBorder : const Color(0xFFE8E8E8);
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = isDark ? AppTheme.whiteMuted : Colors.grey.shade500;

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          // ── Cabeçalho ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: isDark ? AppTheme.black : Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
              child: Column(
                children: [
                  // Avatar / Foto
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                    ),
                    child: Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppTheme.facebookBlue.withOpacity(0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.facebookBlue.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: user.profilePhoto != null
                                ? Image.network(user.profilePhoto!, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _avatarLetter(user))
                                : _avatarLetter(user),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: AppTheme.facebookBlue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit_rounded,
                                color: Colors.white, size: 13),
                          ),
                        ),
                      ],
                    ),
                  ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
                  const SizedBox(height: 12),
                  Text(
                    user.fullName,
                    style: GoogleFonts.outfit(
                      color: textColor, fontSize: 22, fontWeight: FontWeight.w800),
                  ).animate(delay: 100.ms).fadeIn(),
                  Text(
                    user.email,
                    style: GoogleFonts.outfit(color: mutedColor, fontSize: 13),
                  ).animate(delay: 140.ms).fadeIn(),
                  const SizedBox(height: 6),
                  if (user.address.city.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.facebookBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_outlined,
                              color: AppTheme.facebookBlue, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${user.address.city}, ${user.address.state} · ${user.searchRadius}km',
                            style: GoogleFonts.outfit(
                              color: AppTheme.facebookBlue,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ).animate(delay: 180.ms).fadeIn(),
                ],
              ),
            ),
          ),

          // ── Conteúdo ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 8),

                // Atividades principais
                _ProfileSection(
                  isDark: isDark,
                  cardBg: cardBg,
                  border: border,
                  items: [
                    _ProfileItem(
                      icon: Icons.sell_outlined,
                      label: 'Meus anúncios',
                      color: AppTheme.facebookBlue,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MyAdsScreen()),
                      ),
                    ),
                    _ProfileItem(
                      icon: Icons.favorite_outline_rounded,
                      label: 'Favoritos',
                      color: Colors.red,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FavoritesScreen()),
                      ),
                    ),
                    _ProfileItem(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Mensagens',
                      color: const Color(0xFF27AE60),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ChatScreen()),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Loja
                if (!user.hasStore)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateStoreScreen(userId: user.uid)),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.facebookBlue.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppTheme.facebookBlue.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: AppTheme.facebookBlue,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.store_rounded,
                                  color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Criar minha loja',
                                    style: GoogleFonts.outfit(
                                      color: AppTheme.facebookBlue,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    )),
                                  Text('Venda mais com uma página personalizada',
                                    style: GoogleFonts.outfit(
                                        color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                color: AppTheme.facebookBlue),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  _ProfileSection(
                    isDark: isDark,
                    cardBg: cardBg,
                    border: border,
                    items: [
                      _ProfileItem(
                        icon: Icons.store_outlined,
                        label: 'Minha loja',
                        color: const Color(0xFF9B59B6),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MyStoreScreen()),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 8),

                // Conta e preferências
                _ProfileSection(
                  isDark: isDark,
                  cardBg: cardBg,
                  border: border,
                  items: [
                    _ProfileItem(
                      icon: Icons.person_outline_rounded,
                      label: 'Editar perfil',
                      color: Colors.grey,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                      ),
                    ),
                    _ProfileItem(
                      icon: Icons.settings_outlined,
                      label: 'Configurações',
                      color: Colors.grey,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      ),
                    ),
                    _ProfileItem(
                      icon: Icons.help_outline_rounded,
                      label: 'Ajuda e suporte',
                      color: Colors.grey,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HelpScreen()),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Sair
                _ProfileSection(
                  isDark: isDark,
                  cardBg: cardBg,
                  border: border,
                  items: [
                    _ProfileItem(
                      icon: Icons.logout_rounded,
                      label: 'Sair',
                      color: AppTheme.error,
                      textColor: AppTheme.error,
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor:
                                isDark ? AppTheme.blackCard : Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            title: Text('Sair da conta',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                            content: Text('Tem certeza que deseja sair?',
                                style: GoogleFonts.outfit()),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text('Cancelar',
                                    style: GoogleFonts.outfit(color: Colors.grey)),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text('Sair',
                                    style: GoogleFonts.outfit(
                                        color: AppTheme.error,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await AuthService().logout();
                          if (context.mounted) {
                            context.read<UserProvider>().clear();
                          }
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarLetter(user) {
    return Center(
      child: Text(
        user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : '?',
        style: GoogleFonts.outfit(
          color: AppTheme.facebookBlue, fontSize: 32, fontWeight: FontWeight.w800),
      ),
    );
  }
}

// ── Seção de itens do perfil ────────────────────────────────────────────────
class _ProfileSection extends StatelessWidget {
  final bool isDark;
  final Color cardBg;
  final Color border;
  final List<_ProfileItem> items;

  const _ProfileSection({
    required this.isDark,
    required this.cardBg,
    required this.border,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final isLast = e.key == items.length - 1;
          return Column(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: e.value.onTap,
                  borderRadius: BorderRadius.vertical(
                    top: e.key == 0 ? const Radius.circular(14) : Radius.zero,
                    bottom: isLast ? const Radius.circular(14) : Radius.zero,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: e.value.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(e.value.icon, color: e.value.color, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          e.value.label,
                          style: GoogleFonts.outfit(
                            color: e.value.textColor ??
                                (isDark ? Colors.white : Colors.black87),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.chevron_right_rounded,
                            color: Colors.grey.shade400, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Divider(height: 1, indent: 66, color: border),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _ProfileItem {
  final IconData icon;
  final String label;
  final Color color;
  final Color? textColor;
  final VoidCallback onTap;

  _ProfileItem({
    required this.icon,
    required this.label,
    required this.color,
    this.textColor,
    required this.onTap,
  });
}