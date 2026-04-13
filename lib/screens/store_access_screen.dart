import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';
import '../services/firestore_service.dart';
import '../store/create_store_screen.dart';
import '../theme/app_theme.dart';
import 'my_store_screen.dart';

class StoreAccessScreen extends StatelessWidget {
  const StoreAccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.black : AppTheme.lightBg;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.black : Colors.white,
        elevation: 0,
        title: Text(
          'Entrar/Cadastrar Loja',
          style: GoogleFonts.roboto(
            color: textColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            _AccessOption(
              icon: Icons.login_rounded,
              title: 'Entrar em uma loja',
              subtitle: 'Use o usuário e código gerados pelo administrador.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const StoreJoinScreen(),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _AccessOption(
              icon: Icons.storefront_rounded,
              title: 'Cadastrar nova loja',
              subtitle: 'Crie uma nova loja com seu perfil atual.',
              onTap: () {
                final user = context.read<UserProvider>().user;
                if (user == null) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateStoreScreen(userId: user.uid),
                  ),
                );
              },
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class StoreJoinScreen extends StatefulWidget {
  const StoreJoinScreen({super.key});

  @override
  State<StoreJoinScreen> createState() => _StoreJoinScreenState();
}

class _StoreJoinScreenState extends State<StoreJoinScreen> {
  final _usernameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _firestore = FirestoreService();
  bool _loading = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;
    final userProvider = context.read<UserProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _loading = true);
    try {
      final result = await _firestore.joinStoreWithInvite(
        userId: user.uid,
        username: _usernameCtrl.text.trim(),
        code: _codeCtrl.text.trim(),
      );
      await userProvider.refresh();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.alreadyMember
                ? 'Você já faz parte dessa loja.'
                : 'Entrada na loja concluída com sucesso.',
          ),
        ),
      );
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => MyStoreScreen(storeId: result.store.id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.black : AppTheme.lightBg;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.black : Colors.white,
        elevation: 0,
        title: Text(
          'Entrar em loja',
          style: GoogleFonts.roboto(
            color: textColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Use o usuário e o código enviados pelo administrador da loja.',
            style: GoogleFonts.roboto(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          _field(
            controller: _usernameCtrl,
            label: 'Usuário',
            hint: 'pet_store',
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          _field(
            controller: _codeCtrl,
            label: 'Código',
            hint: '12345678',
            isDark: isDark,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _loading ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.facebookBlue,
              minimumSize: const Size.fromHeight(50),
            ),
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Entrar',
                    style: GoogleFonts.roboto(fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.roboto(
            color: isDark ? AppTheme.whiteSecondary : Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: GoogleFonts.roboto(
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: isDark ? AppTheme.blackLight : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _AccessOption extends StatelessWidget {
  const _AccessOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.blackCard : Colors.white;
    final border = isDark ? AppTheme.blackBorder : const Color(0xFFE8E8E8);
    final textColor = isDark ? Colors.white : Colors.black87;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.facebookBlue.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppTheme.facebookBlue),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.roboto(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.roboto(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }
}
