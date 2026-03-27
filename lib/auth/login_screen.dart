import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();
  bool _isLoading = false;
  bool _showPass = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final result = await _auth.login(
      email: _emailCtrl.text,
      password: _passCtrl.text,
    );
    setState(() => _isLoading = false);
    if (!mounted) return;
    if (result.success) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Erro',
              style: GoogleFonts.outfit(color: Colors.white)),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Digite seu e-mail primeiro',
              style: GoogleFonts.outfit(color: Colors.white)),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    await _auth.resetPassword(email);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('E-mail de recuperação enviado!',
              style: GoogleFonts.outfit(color: Colors.white)),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.blackLight : const Color(0xFFF0F2F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.close_rounded, color: textColor, size: 22),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // Logo
              Row(
                children: [
                  Image.asset(
                    'assets/images/logo_a.png',
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.storefront_rounded,
                      color: AppTheme.facebookBlue,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: 'Market',
                        style: GoogleFonts.outfit(
                          color: textColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(
                        text: 'View',
                        style: GoogleFonts.outfit(
                          color: AppTheme.facebookBlue,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ]),
                  ),
                ],
              ).animate().fadeIn(),

              const SizedBox(height: 32),

              Text(
                'Entrar na sua conta',
                style: GoogleFonts.outfit(
                  color: textColor,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ).animate(delay: 60.ms).fadeIn(),

              Text(
                'Bem-vindo de volta!',
                style: GoogleFonts.outfit(color: Colors.grey, fontSize: 14),
              ).animate(delay: 100.ms).fadeIn(),

              const SizedBox(height: 32),

              // E-mail
              _buildLabel('E-mail', isDark),
              const SizedBox(height: 6),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.outfit(
                    color: textColor, fontSize: 15),
                validator: (v) =>
                    !v!.contains('@') ? 'E-mail inválido' : null,
                decoration: _inputDec(
                    'seu@email.com', isDark,
                    prefix: const Icon(Icons.email_outlined,
                        color: Colors.grey, size: 20)),
              ).animate(delay: 160.ms).fadeIn(),

              const SizedBox(height: 16),

              // Senha
              _buildLabel('Senha', isDark),
              const SizedBox(height: 6),
              TextFormField(
                controller: _passCtrl,
                obscureText: !_showPass,
                style: GoogleFonts.outfit(color: textColor, fontSize: 15),
                validator: (v) => v!.length < 6 ? 'Senha inválida' : null,
                onFieldSubmitted: (_) => _login(),
                decoration: _inputDec(
                  '••••••••',
                  isDark,
                  prefix: const Icon(Icons.lock_outline_rounded,
                      color: Colors.grey, size: 20),
                  suffix: IconButton(
                    icon: Icon(
                      _showPass
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: Colors.grey,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _showPass = !_showPass),
                  ),
                ),
              ).animate(delay: 220.ms).fadeIn(),

              const SizedBox(height: 8),

              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _resetPassword,
                  child: Text(
                    'Esqueceu a senha?',
                    style: GoogleFonts.outfit(
                      color: AppTheme.facebookBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ).animate(delay: 260.ms).fadeIn(),

              const SizedBox(height: 32),

              // Botão entrar
              GestureDetector(
                onTap: _isLoading ? null : _login,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.facebookBlue,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.facebookBlue.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          ),
                        )
                      : Text(
                          'Entrar',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                ),
              ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.2, end: 0),

              const SizedBox(height: 28),

              // Divisor
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'ou',
                      style: GoogleFonts.outfit(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ).animate(delay: 340.ms).fadeIn(),

              const SizedBox(height: 20),

              // Cadastrar
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.blackLight : const Color(0xFFF0F2F5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? AppTheme.blackBorder : const Color(0xFFE0E0E0),
                    ),
                  ),
                  child: Text(
                    'Criar conta gratuita',
                    style: GoogleFonts.outfit(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ).animate(delay: 380.ms).fadeIn().slideY(begin: 0.2, end: 0),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        color: isDark ? AppTheme.whiteSecondary : Colors.grey.shade600,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  InputDecoration _inputDec(String hint, bool isDark,
      {Widget? prefix, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.outfit(color: Colors.grey, fontSize: 14),
      prefixIcon: prefix,
      suffixIcon: suffix,
      filled: true,
      fillColor: isDark ? AppTheme.blackLight : const Color(0xFFF5F5F5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: AppTheme.facebookBlue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.error, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}