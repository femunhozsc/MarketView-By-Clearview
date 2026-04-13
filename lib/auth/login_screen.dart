import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _smsFormKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _auth = AuthService();
  final _phoneMask = MaskTextInputFormatter(mask: '(##) #####-####');

  bool _isLoading = false;
  bool _isSendingCode = false;
  bool _isVerifyingCode = false;
  bool _showPass = false;
  int _selectedMode = 0;
  String? _verificationId;
  int? _resendToken;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loginWithEmail() async {
    if (!_emailFormKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final result = await _auth.loginWithVerifiedEmail(
      email: _emailCtrl.text,
      password: _passCtrl.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    _showFeedback(
      result.success
          ? (result.message ?? 'Login realizado com sucesso.')
          : (result.error ?? 'Nao foi possivel entrar agora.'),
      success: result.success,
    );
    if (result.success) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showFeedback('Digite seu e-mail primeiro.', success: false);
      return;
    }

    final result = await _auth.resetPassword(email);
    if (!mounted) return;
    _showFeedback(
      result.success
          ? (result.message ?? 'E-mail de recuperacao enviado.')
          : (result.error ?? 'Nao foi possivel enviar o e-mail.'),
      success: result.success,
    );
  }

  Future<void> _sendSmsCode({bool resend = false}) async {
    _showFeedback(
      'Login via SMS indisponível no momento. Por favor, acesse usando o seu e-mail.',
      success: false,
    );
    return;
  }

  Future<void> _verifySmsCode() async {
    if (_verificationId == null) {
      _showFeedback('Solicite o codigo primeiro.', success: false);
      return;
    }
    if (_codeCtrl.text.trim().length != 6) {
      _showFeedback('Digite o codigo com 6 digitos.', success: false);
      return;
    }

    final phoneNumber = _toE164(_phoneCtrl.text);
    if (phoneNumber == null) {
      _showFeedback('Numero invalido.', success: false);
      return;
    }

    setState(() => _isVerifyingCode = true);
    final result = await _auth.verifySmsCode(
      verificationId: _verificationId!,
      smsCode: _codeCtrl.text,
      phoneNumber: phoneNumber,
    );
    if (!mounted) return;
    setState(() => _isVerifyingCode = false);
    _showFeedback(
      result.success
          ? 'Numero verificado com sucesso.'
          : (result.error ?? 'Nao foi possivel validar o codigo.'),
      success: result.success,
    );
    if (result.success) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _showFeedback(String message, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.roboto(color: Colors.white),
        ),
        backgroundColor: success ? AppTheme.success : AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String? _toE164(String rawPhone) {
    final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11) return '+55$digits';
    if (digits.length == 13 && digits.startsWith('55')) return '+$digits';
    return null;
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Row(
              children: [
                Image.asset(
                  'assets/images/logo_a.png',
                  width: 32,
                  height: 32,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.storefront_rounded,
                    color: AppTheme.facebookBlue,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 8),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Market',
                        style: GoogleFonts.roboto(
                          color: textColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(
                        text: 'View',
                        style: GoogleFonts.roboto(
                          color: AppTheme.facebookBlue,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ).animate().fadeIn(),
            const SizedBox(height: 32),
            Text(
              'Entrar na sua conta',
              style: GoogleFonts.roboto(
                color: textColor,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ).animate(delay: 60.ms).fadeIn(),
            Text(
              _selectedMode == 0
                  ? 'Entre com e-mail verificado ou recupere sua senha.'
                  : 'Receba um SMS e valide o codigo para entrar.',
              style: GoogleFonts.roboto(color: Colors.grey, fontSize: 14),
            ).animate(delay: 100.ms).fadeIn(),
            const SizedBox(height: 24),
            _buildModeSwitcher(isDark, textColor)
                .animate(delay: 130.ms)
                .fadeIn(),
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _selectedMode == 0
                  ? _buildEmailMode(isDark, textColor)
                  : _buildSmsMode(isDark, textColor),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey.shade300)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'ou',
                    style: GoogleFonts.roboto(color: Colors.grey, fontSize: 13),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey.shade300)),
              ],
            ).animate(delay: 340.ms).fadeIn(),
            const SizedBox(height: 20),
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
                    color:
                        isDark ? AppTheme.blackBorder : const Color(0xFFE0E0E0),
                  ),
                ),
                child: Text(
                  'Criar conta gratuita',
                  style: GoogleFonts.roboto(
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
    );
  }

  Widget _buildModeSwitcher(bool isDark, Color textColor) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.blackLight : const Color(0xFFF2F5FA),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _modeButton(
              label: 'Email',
              selected: _selectedMode == 0,
              onTap: () => setState(() => _selectedMode = 0),
            ),
          ),
          Expanded(
            child: _modeButton(
              label: 'SMS',
              selected: _selectedMode == 1,
              onTap: () => setState(() => _selectedMode = 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.facebookBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.roboto(
            color: selected ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildEmailMode(bool isDark, Color textColor) {
    return Form(
      key: _emailFormKey,
      child: Column(
        key: const ValueKey('email-mode'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('E-mail', isDark),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: GoogleFonts.roboto(color: textColor, fontSize: 15),
            validator: (v) => !v!.contains('@') ? 'E-mail invalido' : null,
            decoration: _inputDec(
              'seu@email.com',
              isDark,
              prefix: const Icon(
                Icons.email_outlined,
                color: Colors.grey,
                size: 20,
              ),
            ),
          ).animate(delay: 160.ms).fadeIn(),
          const SizedBox(height: 16),
          _buildLabel('Senha', isDark),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passCtrl,
            obscureText: !_showPass,
            style: GoogleFonts.roboto(color: textColor, fontSize: 15),
            validator: (v) => v!.length < 6 ? 'Senha invalida' : null,
            onFieldSubmitted: (_) => _loginWithEmail(),
            decoration: _inputDec(
              '••••••••',
              isDark,
              prefix: const Icon(
                Icons.lock_outline_rounded,
                color: Colors.grey,
                size: 20,
              ),
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
                style: GoogleFonts.roboto(
                  color: AppTheme.facebookBlue,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ).animate(delay: 260.ms).fadeIn(),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.facebookBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Contas por e-mail so entram depois da verificacao enviada pelo Firebase.',
              style: GoogleFonts.roboto(
                color: textColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _isLoading ? null : _loginWithEmail,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.facebookBlue,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.facebookBlue.withValues(alpha: 0.3),
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
                      'Entrar com e-mail',
                      style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
            ),
          ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.2, end: 0),
        ],
      ),
    );
  }

  Widget _buildSmsMode(bool isDark, Color textColor) {
    return Form(
      key: _smsFormKey,
      child: Column(
        key: const ValueKey('sms-mode'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.facebookBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Se este telefone estiver cadastrado como numero de teste no Firebase, use o codigo definido no console em vez de esperar um SMS real.',
              style: GoogleFonts.roboto(
                color: textColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ).animate(delay: 140.ms).fadeIn(),
          const SizedBox(height: 16),
          _buildLabel('Telefone', isDark),
          const SizedBox(height: 6),
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [_phoneMask],
            style: GoogleFonts.roboto(color: textColor, fontSize: 15),
            validator: (value) {
              final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
              return digits.length != 11
                  ? 'Digite DDD + numero com 11 digitos'
                  : null;
            },
            decoration: _inputDec(
              '(44) 99129-3357',
              isDark,
              prefix: const Icon(
                Icons.phone_iphone_rounded,
                color: Colors.grey,
                size: 20,
              ),
            ).copyWith(prefixText: '+55 '),
          ).animate(delay: 180.ms).fadeIn(),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _isSendingCode ? null : () => _sendSmsCode(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.facebookBlue,
                borderRadius: BorderRadius.circular(14),
              ),
              child: _isSendingCode
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
                      'Enviar codigo por SMS',
                      style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
            ),
          ).animate(delay: 220.ms).fadeIn(),
          if (_verificationId != null) ...[
            const SizedBox(height: 18),
            _buildLabel('Codigo recebido', isDark),
            const SizedBox(height: 6),
            TextFormField(
              controller: _codeCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: GoogleFonts.roboto(color: textColor, fontSize: 15),
              decoration: _inputDec(
                '123456',
                isDark,
                prefix: const Icon(
                  Icons.password_rounded,
                  color: Colors.grey,
                  size: 20,
                ),
              ).copyWith(counterText: ''),
            ).animate(delay: 250.ms).fadeIn(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSendingCode
                        ? null
                        : () => _sendSmsCode(resend: true),
                    child: const Text('Reenviar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isVerifyingCode ? null : _verifySmsCode,
                    child: _isVerifyingCode
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.4,
                            ),
                          )
                        : const Text('Validar codigo'),
                  ),
                ),
              ],
            ).animate(delay: 280.ms).fadeIn(),
          ],
        ],
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Text(
      text,
      style: GoogleFonts.roboto(
        color: isDark ? AppTheme.whiteSecondary : Colors.grey.shade600,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  InputDecoration _inputDec(
    String hint,
    bool isDark, {
    Widget? prefix,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.roboto(color: Colors.grey, fontSize: 14),
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
        borderSide: const BorderSide(color: AppTheme.facebookBlue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.error, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
