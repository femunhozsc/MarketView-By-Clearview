import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import 'seller_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    this.showAppBar = true,
  });

  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.user;

    if (userProvider.isLoggedIn && user != null) {
      return SellerProfileScreen(
        sellerId: user.uid,
        sellerName: user.fullName,
        showAppBar: showAppBar,
      );
    }

    return _GuestProfile(isDark: isDark);
  }
}

class _GuestProfile extends StatelessWidget {
  const _GuestProfile({required this.isDark});

  final bool isDark;

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
                  color: AppTheme.facebookBlue.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: AppTheme.facebookBlue,
                  size: 52,
                ),
              ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
              const SizedBox(height: 28),
              Text(
                'Olá, visitante!',
                style: GoogleFonts.roboto(
                  color: textColor,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ).animate(delay: 100.ms).fadeIn(),
              const SizedBox(height: 10),
              Text(
                'Entre ou crie sua conta para anunciar produtos, serviços, criar sua loja e muito mais!',
                style: GoogleFonts.roboto(
                  color: Colors.grey,
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ).animate(delay: 160.ms).fadeIn(),
              const Spacer(),
              ...[
                'Anunciar produtos e serviços',
                'Criar sua loja virtual',
                'Conversar com vendedores',
                'Salvar favoritos',
              ].asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.facebookBlue.withValues(alpha: 0.10),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: AppTheme.facebookBlue,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            entry.value,
                            style: GoogleFonts.roboto(
                              color: textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      )
                          .animate(
                            delay: Duration(milliseconds: 200 + entry.key * 60),
                          )
                          .fadeIn(),
                    ),
                  ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.facebookBlue,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.facebookBlue.withValues(alpha: 0.30),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    'Entrar',
                    style: GoogleFonts.roboto(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ).animate(delay: 500.ms).fadeIn().slideY(begin: 0.2, end: 0),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color:
                        isDark ? AppTheme.blackLight : const Color(0xFFF0F2F5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? AppTheme.blackBorder
                          : const Color(0xFFE0E0E0),
                    ),
                  ),
                  child: Text(
                    'Criar conta gratuita',
                    style: GoogleFonts.roboto(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
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
