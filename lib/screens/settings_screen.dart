import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../theme/theme_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifyMessages = true;
  bool _notifyOffers = true;
  bool _notifyNews = false;

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.blackCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Excluir conta',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: AppTheme.error)),
        content: Text(
          'Essa ação é irreversível. Todos os seus dados, anúncios e histórico serão apagados permanentemente.',
          style: GoogleFonts.outfit(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: GoogleFonts.outfit(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Excluir conta',
                style: GoogleFonts.outfit(color: AppTheme.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      // Em produção: deletar dados do Firestore e conta do Firebase Auth
      await AuthService().logout();
      if (mounted) context.read<UserProvider>().clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = context.watch<ThemeProvider>();
    final bg = isDark ? AppTheme.black : AppTheme.lightBg;
    final cardBg = isDark ? AppTheme.blackCard : Colors.white;
    final border = isDark ? AppTheme.blackBorder : const Color(0xFFE8E8E8);
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
        title: Text(
          'Configurações',
          style: GoogleFonts.outfit(color: textColor, fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // Aparência
          _sectionLabel('Aparência', isDark),
          const SizedBox(height: 8),
          _card(
            isDark: isDark,
            cardBg: cardBg,
            border: border,
            child: _switchTile(
              icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              iconColor: isDark ? const Color(0xFF9B59B6) : Colors.orange,
              label: 'Modo escuro',
              subtitle: isDark ? 'Ativado' : 'Desativado',
              value: themeProvider.isDarkMode,
              textColor: textColor,
              isDark: isDark,
              onChanged: (_) => themeProvider.toggleTheme(),
            ),
          ).animate().fadeIn().slideY(begin: 0.05, end: 0),

          const SizedBox(height: 16),

          // Notificações
          _sectionLabel('Notificações', isDark),
          const SizedBox(height: 8),
          _card(
            isDark: isDark,
            cardBg: cardBg,
            border: border,
            child: Column(
              children: [
                _switchTile(
                  icon: Icons.chat_bubble_outline_rounded,
                  iconColor: const Color(0xFF27AE60),
                  label: 'Novas mensagens',
                  subtitle: 'Alertas de conversas',
                  value: _notifyMessages,
                  textColor: textColor,
                  isDark: isDark,
                  onChanged: (v) => setState(() => _notifyMessages = v),
                ),
                _divider(isDark),
                _switchTile(
                  icon: Icons.local_offer_outlined,
                  iconColor: AppTheme.facebookBlue,
                  label: 'Propostas e ofertas',
                  subtitle: 'Novidades nos seus anúncios',
                  value: _notifyOffers,
                  textColor: textColor,
                  isDark: isDark,
                  onChanged: (v) => setState(() => _notifyOffers = v),
                ),
                _divider(isDark),
                _switchTile(
                  icon: Icons.campaign_outlined,
                  iconColor: Colors.orange,
                  label: 'Novidades do app',
                  subtitle: 'Dicas e atualizações',
                  value: _notifyNews,
                  textColor: textColor,
                  isDark: isDark,
                  onChanged: (v) => setState(() => _notifyNews = v),
                ),
              ],
            ),
          ).animate(delay: 60.ms).fadeIn().slideY(begin: 0.05, end: 0),

          const SizedBox(height: 16),

          // Privacidade
          _sectionLabel('Privacidade e segurança', isDark),
          const SizedBox(height: 8),
          _card(
            isDark: isDark,
            cardBg: cardBg,
            border: border,
            child: Column(
              children: [
                _navTile(
                  icon: Icons.lock_outline_rounded,
                  iconColor: AppTheme.facebookBlue,
                  label: 'Alterar senha',
                  textColor: textColor,
                  isDark: isDark,
                  onTap: () => _showChangePasswordDialog(context, isDark),
                ),
                _divider(isDark),
                _navTile(
                  icon: Icons.policy_outlined,
                  iconColor: Colors.grey,
                  label: 'Política de privacidade',
                  textColor: textColor,
                  isDark: isDark,
                  onTap: () {},
                ),
                _divider(isDark),
                _navTile(
                  icon: Icons.description_outlined,
                  iconColor: Colors.grey,
                  label: 'Termos de uso',
                  textColor: textColor,
                  isDark: isDark,
                  onTap: () {},
                ),
              ],
            ),
          ).animate(delay: 120.ms).fadeIn().slideY(begin: 0.05, end: 0),

          const SizedBox(height: 16),

          // Sobre
          _sectionLabel('Sobre', isDark),
          const SizedBox(height: 8),
          _card(
            isDark: isDark,
            cardBg: cardBg,
            border: border,
            child: Column(
              children: [
                _infoTile(
                  icon: Icons.info_outline_rounded,
                  label: 'Versão do app',
                  value: '1.0.0',
                  textColor: textColor,
                  isDark: isDark,
                ),
                _divider(isDark),
                _navTile(
                  icon: Icons.star_outline_rounded,
                  iconColor: Colors.orange,
                  label: 'Avaliar o MarketView',
                  textColor: textColor,
                  isDark: isDark,
                  onTap: () {},
                ),
              ],
            ),
          ).animate(delay: 180.ms).fadeIn().slideY(begin: 0.05, end: 0),

          const SizedBox(height: 16),

          // Zona de perigo
          _sectionLabel('Zona de perigo', isDark),
          const SizedBox(height: 8),
          _card(
            isDark: isDark,
            cardBg: cardBg,
            border: border,
            child: GestureDetector(
              onTap: () => _confirmDeleteAccount(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.delete_forever_rounded,
                          color: AppTheme.error, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Excluir minha conta',
                            style: GoogleFonts.outfit(
                              color: AppTheme.error,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Apaga todos os seus dados permanentemente',
                            style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20),
                  ],
                ),
              ),
            ),
          ).animate(delay: 240.ms).fadeIn().slideY(begin: 0.05, end: 0),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, bool isDark) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.blackCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Alterar senha',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Insira seu e-mail para receber o link de redefinição de senha.',
                style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey, height: 1.5)),
            const SizedBox(height: 16),
            TextFormField(
              controller: ctrl,
              keyboardType: TextInputType.emailAddress,
              style: GoogleFonts.outfit(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'seu@email.com',
                hintStyle: GoogleFonts.outfit(color: Colors.grey),
                filled: true,
                fillColor: isDark ? AppTheme.blackLight : const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: GoogleFonts.outfit(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService().resetPassword(ctrl.text.trim());
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('E-mail de redefinição enviado!',
                        style: GoogleFonts.outfit(color: Colors.white)),
                    backgroundColor: AppTheme.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            },
            child: Text('Enviar',
                style: GoogleFonts.outfit(color: AppTheme.facebookBlue, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, bool isDark) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.outfit(
        color: isDark ? AppTheme.whiteMuted : Colors.grey.shade500,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _card({required bool isDark, required Color cardBg, required Color border, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }

  Widget _switchTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String subtitle,
    required bool value,
    required Color textColor,
    required bool isDark,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.outfit(color: textColor, fontSize: 14, fontWeight: FontWeight.w500)),
                Text(subtitle, style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.facebookBlue,
          ),
        ],
      ),
    );
  }

  Widget _navTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required Color textColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label, style: GoogleFonts.outfit(color: textColor, fontSize: 14, fontWeight: FontWeight.w500)),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color textColor,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.grey, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label, style: GoogleFonts.outfit(color: textColor, fontSize: 14, fontWeight: FontWeight.w500)),
          ),
          Text(value, style: GoogleFonts.outfit(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _divider(bool isDark) {
    return Divider(
      height: 1,
      indent: 66,
      color: isDark ? AppTheme.blackBorder : const Color(0xFFE8E8E8),
    );
  }
}