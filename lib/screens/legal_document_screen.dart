import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.sections,
  });

  final String title;
  final List<LegalSection> sections;

  static List<LegalSection> privacyPolicySections() {
    return const [
      LegalSection(
        heading: '1. Coleta de dados',
        body:
            'Coletamos os dados informados por voce no cadastro e durante o uso do app, como nome, e-mail, telefone, localizacao de busca, anuncios e imagens enviadas.',
      ),
      LegalSection(
        heading: '2. Finalidade',
        body:
            'Esses dados sao usados para autenticar sua conta, publicar anuncios, aproximar compradores e vendedores, personalizar recomendacoes e melhorar a seguranca da plataforma.',
      ),
      LegalSection(
        heading: '3. Compartilhamento',
        body:
            'Os dados exibidos publicamente se limitam ao necessario para funcionamento do marketplace, como nome exibido, fotos, localidade do anuncio e dados da loja quando aplicavel.',
      ),
      LegalSection(
        heading: '4. Armazenamento e seguranca',
        body:
            'Os dados sao mantidos em infraestrutura em nuvem e protegidos por controles de autenticacao e regras de acesso. Nenhuma medida e absoluta, por isso mantemos melhorias continuas de seguranca.',
      ),
      LegalSection(
        heading: '5. Seus direitos',
        body:
            'Voce pode revisar, editar e solicitar a exclusao da sua conta e dos dados associados, respeitando obrigacoes tecnicas e legais eventualmente aplicaveis.',
      ),
      LegalSection(
        heading: '6. Contato',
        body:
            'Em caso de duvidas sobre privacidade, use os canais de suporte disponibilizados no app.',
      ),
    ];
  }

  static List<LegalSection> termsOfUseSections() {
    return const [
      LegalSection(
        heading: '1. Uso da plataforma',
        body:
            'O MarketView e uma plataforma de anuncios e interacao entre usuarios. O usuario e responsavel pela veracidade das informacoes publicadas e pela conduta dentro do app.',
      ),
      LegalSection(
        heading: '2. Conteudo proibido',
        body:
            'Nao e permitido publicar conteudo ilicito, enganoso, ofensivo, fraudulento, que viole direitos de terceiros ou que descumpra a legislacao aplicavel.',
      ),
      LegalSection(
        heading: '3. Responsabilidade pelas negociacoes',
        body:
            'As negociacoes sao realizadas entre os usuarios. O app atua como plataforma de intermediacao e pode remover conteudos ou contas que apresentem risco ou abuso.',
      ),
      LegalSection(
        heading: '4. Contas e seguranca',
        body:
            'Voce deve manter suas credenciais em sigilo e informar qualquer uso indevido da conta. Podemos limitar ou encerrar contas em caso de violacao destes termos.',
      ),
      LegalSection(
        heading: '5. Disponibilidade',
        body:
            'Buscamos manter o app disponivel e confiavel, mas podem ocorrer indisponibilidades, manutencoes e alteracoes de funcionalidade ao longo do tempo.',
      ),
      LegalSection(
        heading: '6. Atualizacoes',
        body:
            'O uso continuado do app apos novas versoes implica concordancia com as atualizacoes relevantes destes termos.',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.black : AppTheme.lightBg;
    final cardBg = isDark ? AppTheme.blackCard : Colors.white;
    final border = isDark ? AppTheme.blackBorder : const Color(0xFFE5E7EB);
    final textColor = isDark ? Colors.white : Colors.black87;
    final muted = isDark ? AppTheme.whiteSecondary : Colors.grey.shade700;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.black : Colors.white,
        title: Text(title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: border),
            ),
            child: Text(
              'Documento informativo disponibilizado dentro do app para facilitar consulta e dar mais transparencia ao uso da plataforma.',
              style: GoogleFonts.roboto(
                color: muted,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...sections.map(
            (section) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.heading,
                      style: GoogleFonts.roboto(
                        color: textColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      section.body,
                      style: GoogleFonts.roboto(
                        color: muted,
                        height: 1.55,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LegalSection {
  final String heading;
  final String body;

  const LegalSection({
    required this.heading,
    required this.body,
  });
}
