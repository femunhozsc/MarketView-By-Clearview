import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final List<_FaqItem> _faqs = [
    _FaqItem(
      question: 'Como criar um anúncio?',
      answer:
          'Toque no botão "+" na barra inferior e preencha as informações do produto ou serviço. Adicione fotos, defina o preço e a categoria e publique. Seu anúncio ficará visível para compradores próximos a você.',
    ),
    _FaqItem(
      question: 'Como funciona o chat?',
      answer:
          'Ao clicar em "Enviar mensagem" em um anúncio, você inicia uma conversa direta com o vendedor. As mensagens ficam salvas na aba Mensagens.',
    ),
    _FaqItem(
      question: 'Como criar uma loja?',
      answer:
          'Acesse seu perfil e toque em "Criar minha loja". Preencha os dados da empresa, adicione logo e banner, e sua loja estará online. Com uma loja você tem mais visibilidade e pode gerenciar seus produtos em um único lugar.',
    ),
    _FaqItem(
      question: 'Como favoritar um anúncio?',
      answer:
          'No detalhe de qualquer anúncio, toque no ícone de coração (♡) no canto superior direito. O anúncio será salvo em sua lista de Favoritos no perfil.',
    ),
    _FaqItem(
      question: 'Como alterar o raio de busca?',
      answer:
          'Acesse Perfil → Editar perfil → Raio de busca. Use o controle deslizante para definir a distância em km. Os anúncios exibidos serão filtrados com base nesse raio a partir da sua localização.',
    ),
    _FaqItem(
      question: 'Como excluir um anúncio?',
      answer:
          'Acesse Perfil → Meus anúncios. Em cada anúncio há um botão "Excluir". A exclusão é permanente e não pode ser desfeita.',
    ),
    _FaqItem(
      question: 'Meus dados estão seguros?',
      answer:
          'Sim. Utilizamos Firebase Authentication para login seguro e todos os dados são armazenados com criptografia no Firestore. Imagens são hospedadas no Cloudinary com acesso controlado.',
    ),
    _FaqItem(
      question: 'Como redefinir minha senha?',
      answer:
          'Acesse a tela de login e toque em "Esqueceu a senha?". Digite seu e-mail e você receberá um link de redefinição. Também é possível pelo menu Configurações → Alterar senha.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          'Ajuda e suporte',
          style: GoogleFonts.roboto(color: textColor, fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner de contato
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AppTheme.facebookBlue,
                  AppTheme.facebookBlueDark,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.facebookBlue.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.support_agent_rounded, color: Colors.white, size: 36),
                const SizedBox(height: 10),
                Text(
                  'Precisa de ajuda?',
                  style: GoogleFonts.roboto(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Nossa equipe está disponível para ajudar você com qualquer dúvida ou problema.',
                  style: GoogleFonts.roboto(
                    color: Colors.white.withValues(alpha: 0.85), fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _contactBtn(
                      icon: Icons.email_outlined,
                      label: 'E-mail',
                      onTap: () {},
                    ),
                    const SizedBox(width: 10),
                    _contactBtn(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'WhatsApp',
                      onTap: () {},
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: 0.05, end: 0),

          const SizedBox(height: 24),

          Text(
            'PERGUNTAS FREQUENTES',
            style: GoogleFonts.roboto(
              color: isDark ? AppTheme.whiteMuted : Colors.grey.shade500,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ).animate(delay: 80.ms).fadeIn(),

          const SizedBox(height: 10),

          // FAQs
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: Column(
              children: _faqs.asMap().entries.map((e) {
                final isLast = e.key == _faqs.length - 1;
                return Column(
                  children: [
                    _FaqTile(item: e.value, isDark: isDark, textColor: textColor),
                    if (!isLast)
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: border,
                      ),
                  ],
                );
              }).toList(),
            ),
          ).animate(delay: 120.ms).fadeIn().slideY(begin: 0.05, end: 0),

          const SizedBox(height: 24),

          // Links rápidos
          Text(
            'LINKS ÚTEIS',
            style: GoogleFonts.roboto(
              color: isDark ? AppTheme.whiteMuted : Colors.grey.shade500,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ).animate(delay: 160.ms).fadeIn(),

          const SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: Column(
              children: [
                _linkTile(
                  icon: Icons.policy_outlined,
                  iconColor: AppTheme.facebookBlue,
                  label: 'Política de privacidade',
                  textColor: textColor,
                  isDark: isDark,
                  onTap: () {},
                ),
                Divider(height: 1, indent: 66, color: border),
                _linkTile(
                  icon: Icons.description_outlined,
                  iconColor: AppTheme.facebookBlue,
                  label: 'Termos de uso',
                  textColor: textColor,
                  isDark: isDark,
                  onTap: () {},
                ),
                Divider(height: 1, indent: 66, color: border),
                _linkTile(
                  icon: Icons.star_outline_rounded,
                  iconColor: Colors.orange,
                  label: 'Avaliar o MarketView na loja',
                  textColor: textColor,
                  isDark: isDark,
                  onTap: () {},
                ),
              ],
            ),
          ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.05, end: 0),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _contactBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.roboto(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _linkTile({
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
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label, style: GoogleFonts.roboto(
                  color: textColor, fontSize: 14, fontWeight: FontWeight.w500)),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;
  _FaqItem({required this.question, required this.answer});
}

class _FaqTile extends StatefulWidget {
  final _FaqItem item;
  final bool isDark;
  final Color textColor;
  const _FaqTile({required this.item, required this.isDark, required this.textColor});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.item.question,
                    style: GoogleFonts.roboto(
                      color: widget.textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: _expanded ? AppTheme.facebookBlue : Colors.grey,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              widget.item.answer,
              style: GoogleFonts.roboto(
                color: widget.isDark ? AppTheme.whiteSecondary : Colors.grey.shade600,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ),
          crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }
}
