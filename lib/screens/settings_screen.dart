import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';
import '../screens/legal_document_screen.dart';
import '../services/app_preferences_service.dart';
import '../services/auth_service.dart';
import '../services/external_links_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authService = AuthService();
  final _preferencesService = AppPreferencesService();
  final _linksService = ExternalLinksService();

  bool _notifyMessages = true;
  bool _notifyOffers = true;
  bool _notifyNews = false;
  bool _loadingPreferences = true;
  bool _deletingAccount = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreferences();
  }

  Future<void> _loadNotificationPreferences() async {
    final preferences =
        await _preferencesService.loadNotificationPreferences();
    if (!mounted) return;
    setState(() {
      _notifyMessages = preferences.messages;
      _notifyOffers = preferences.offers;
      _notifyNews = preferences.news;
      _loadingPreferences = false;
    });
  }

  Future<void> _saveNotificationPreferences({
    bool? messages,
    bool? offers,
    bool? news,
  }) async {
    final nextPreferences = NotificationPreferences(
      messages: messages ?? _notifyMessages,
      offers: offers ?? _notifyOffers,
      news: news ?? _notifyNews,
    );

    setState(() {
      _notifyMessages = nextPreferences.messages;
      _notifyOffers = nextPreferences.offers;
      _notifyNews = nextPreferences.news;
    });

    await _preferencesService.saveNotificationPreferences(nextPreferences);
  }

  Future<void> _confirmDeleteAccount() async {
    if (_deletingAccount) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.blackCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Excluir conta',
          style: GoogleFonts.roboto(
            fontWeight: FontWeight.w800,
            color: AppTheme.error,
          ),
        ),
        content: Text(
          'Essa acao e irreversivel. Sua conta, seus anuncios, suas lojas, chats, favoritos e demais dados associados serao removidos.',
          style: GoogleFonts.roboto(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.roboto(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Excluir conta',
              style: GoogleFonts.roboto(
                color: AppTheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _deletingAccount = true);
    final result = await _authService.deleteCurrentAccount();
    if (!mounted) return;

    setState(() => _deletingAccount = false);
    if (result.success) {
      context.read<UserProvider>().clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conta excluida com sucesso.'),
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.error ?? 'Erro ao excluir a conta.')),
    );
  }

  Future<void> _openPrivacyPolicy() async {
    if (ExternalLinksService.privacyPolicyUrl.trim().isNotEmpty) {
      await _linksService.openOrExplain(
        context,
        url: ExternalLinksService.privacyPolicyUrl,
        unavailableMessage:
            'Nao foi possivel abrir a politica de privacidade agora.',
      );
      return;
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LegalDocumentScreen(
          title: 'Politica de privacidade',
          sections: LegalDocumentScreen.privacyPolicySections(),
        ),
      ),
    );
  }

  Future<void> _openTermsOfUse() async {
    if (ExternalLinksService.termsUrl.trim().isNotEmpty) {
      await _linksService.openOrExplain(
        context,
        url: ExternalLinksService.termsUrl,
        unavailableMessage: 'Nao foi possivel abrir os termos de uso agora.',
      );
      return;
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LegalDocumentScreen(
          title: 'Termos de uso',
          sections: LegalDocumentScreen.termsOfUseSections(),
        ),
      ),
    );
  }

  Future<void> _openAppReview() async {
    const reviewUrl = ExternalLinksService.appReviewUrl;
    if (reviewUrl.trim().isNotEmpty) {
      await _linksService.openOrExplain(
        context,
        url: reviewUrl,
        unavailableMessage: 'Nao foi possivel abrir a pagina de avaliacao.',
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'A avaliacao na loja sera habilitada assim que a versao publicada estiver disponivel.',
        ),
      ),
    );
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
          'Configuracoes',
          style: GoogleFonts.roboto(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _loadingPreferences
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.facebookBlue),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionLabel('Aparencia', isDark),
                const SizedBox(height: 8),
                _card(
                  cardBg: cardBg,
                  border: border,
                  child: _switchTile(
                    icon: isDark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    iconColor: isDark
                        ? const Color(0xFF9B59B6)
                        : Colors.orange,
                    label: 'Modo escuro',
                    subtitle: isDark ? 'Ativado' : 'Desativado',
                    value: themeProvider.isDarkMode,
                    textColor: textColor,
                    onChanged: (_) => themeProvider.toggleTheme(),
                  ),
                ).animate().fadeIn().slideY(begin: 0.05, end: 0),
                const SizedBox(height: 16),
                _sectionLabel('Notificacoes', isDark),
                const SizedBox(height: 8),
                _card(
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
                        onChanged: (value) =>
                            _saveNotificationPreferences(messages: value),
                      ),
                      _divider(isDark),
                      _switchTile(
                        icon: Icons.local_offer_outlined,
                        iconColor: AppTheme.facebookBlue,
                        label: 'Propostas e ofertas',
                        subtitle: 'Novidades nos seus anuncios',
                        value: _notifyOffers,
                        textColor: textColor,
                        onChanged: (value) =>
                            _saveNotificationPreferences(offers: value),
                      ),
                      _divider(isDark),
                      _switchTile(
                        icon: Icons.campaign_outlined,
                        iconColor: Colors.orange,
                        label: 'Novidades do app',
                        subtitle: 'Dicas e atualizacoes',
                        value: _notifyNews,
                        textColor: textColor,
                        onChanged: (value) =>
                            _saveNotificationPreferences(news: value),
                      ),
                    ],
                  ),
                ).animate(delay: 60.ms).fadeIn().slideY(begin: 0.05, end: 0),
                const SizedBox(height: 16),
                _sectionLabel('Privacidade e seguranca', isDark),
                const SizedBox(height: 8),
                _card(
                  cardBg: cardBg,
                  border: border,
                  child: Column(
                    children: [
                      _navTile(
                        icon: Icons.lock_outline_rounded,
                        iconColor: AppTheme.facebookBlue,
                        label: 'Alterar senha',
                        textColor: textColor,
                        onTap: () => _showChangePasswordDialog(context, isDark),
                      ),
                      _divider(isDark),
                      _navTile(
                        icon: Icons.policy_outlined,
                        iconColor: Colors.grey,
                        label: 'Politica de privacidade',
                        textColor: textColor,
                        onTap: _openPrivacyPolicy,
                      ),
                      _divider(isDark),
                      _navTile(
                        icon: Icons.description_outlined,
                        iconColor: Colors.grey,
                        label: 'Termos de uso',
                        textColor: textColor,
                        onTap: _openTermsOfUse,
                      ),
                    ],
                  ),
                ).animate(delay: 120.ms).fadeIn().slideY(begin: 0.05, end: 0),
                const SizedBox(height: 16),
                _sectionLabel('Sobre', isDark),
                const SizedBox(height: 8),
                _card(
                  cardBg: cardBg,
                  border: border,
                  child: Column(
                    children: [
                      _infoTile(
                        icon: Icons.info_outline_rounded,
                        label: 'Versao do app',
                        value: '1.0.0',
                        textColor: textColor,
                      ),
                      _divider(isDark),
                      _navTile(
                        icon: Icons.star_outline_rounded,
                        iconColor: Colors.orange,
                        label: 'Avaliar o MarketView',
                        textColor: textColor,
                        onTap: _openAppReview,
                      ),
                    ],
                  ),
                ).animate(delay: 180.ms).fadeIn().slideY(begin: 0.05, end: 0),
                const SizedBox(height: 16),
                _sectionLabel('Zona de perigo', isDark),
                const SizedBox(height: 8),
                _card(
                  cardBg: cardBg,
                  border: border,
                  child: GestureDetector(
                    onTap: _deletingAccount ? null : _confirmDeleteAccount,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppTheme.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: _deletingAccount
                                ? const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.error,
                                    ),
                                  )
                                : const Icon(
                                    Icons.delete_forever_rounded,
                                    color: AppTheme.error,
                                    size: 20,
                                  ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Excluir minha conta',
                                  style: GoogleFonts.roboto(
                                    color: AppTheme.error,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Remove conta, anuncios, lojas, chats e dados associados',
                                  style: GoogleFonts.roboto(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.grey.shade400,
                            size: 20,
                          ),
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
        title: Text(
          'Alterar senha',
          style: GoogleFonts.roboto(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Insira seu e-mail para receber o link de redefinicao de senha.',
              style: GoogleFonts.roboto(
                fontSize: 13,
                color: Colors.grey,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: ctrl,
              keyboardType: TextInputType.emailAddress,
              style: GoogleFonts.roboto(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'seu@email.com',
                hintStyle: GoogleFonts.roboto(color: Colors.grey),
                filled: true,
                fillColor: isDark
                    ? AppTheme.blackLight
                    : const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancelar',
              style: GoogleFonts.roboto(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await _authService.resetPassword(ctrl.text.trim());
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    result.success
                        ? 'E-mail de redefinicao enviado!'
                        : (result.error ?? 'Nao foi possivel enviar o e-mail.'),
                    style: GoogleFonts.roboto(color: Colors.white),
                  ),
                  backgroundColor:
                      result.success ? AppTheme.success : AppTheme.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            child: Text(
              'Enviar',
              style: GoogleFonts.roboto(
                color: AppTheme.facebookBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, bool isDark) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.roboto(
        color: isDark ? AppTheme.whiteMuted : Colors.grey.shade500,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _card({
    required Color cardBg,
    required Color border,
    required Widget child,
  }) {
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
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.roboto(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.roboto(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.facebookBlue,
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
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.roboto(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey.shade400,
              size: 20,
            ),
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
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.grey, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.roboto(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.roboto(color: Colors.grey, fontSize: 13),
          ),
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
