import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/ad_model.dart';
import '../providers/user_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/edge_swipe_back.dart';
import 'ad_detail_screen.dart';
import 'seller_profile_screen.dart';

class ChatDetailScreen extends StatefulWidget {
  final String chatId;
  final String? otherUserId;
  final String otherUserName;
  final String adTitle;
  final String? adId;
  final String? sellerId;
  final double? adPrice;
  final String? adIntent;
  final bool openOfferComposerOnLoad;

  const ChatDetailScreen({
    super.key,
    required this.chatId,
    this.otherUserId,
    required this.otherUserName,
    required this.adTitle,
    this.adId,
    this.sellerId,
    this.adPrice,
    this.adIntent,
    this.openOfferComposerOnLoad = false,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  static const List<String> _sellerStrengthOptions = [
    'Atencioso',
    'Comunicacao rapida',
    'Pontual',
    'Honesto',
    'Produto conforme o anuncio',
  ];
  final _messageCtrl = TextEditingController();
  final _firestore = FirestoreService();
  bool _showQuickReplies = true;
  bool _handledInitialOffer = false;
  final bool _showDealBar = true;

  bool get _isDirectChat {
    final adId = widget.adId?.trim() ?? '';
    return widget.chatId.startsWith('direct_') || adId.startsWith('direct_');
  }

  bool get _hasLinkedAd {
    final adId = widget.adId?.trim() ?? '';
    return adId.isNotEmpty && !adId.startsWith('direct_');
  }

  bool get _isSellerSide {
    final currentUserId = context.read<UserProvider>().user?.uid;
    return currentUserId != null &&
        widget.sellerId != null &&
        currentUserId == widget.sellerId;
  }

  List<String> get _roleQuickReplies {
    if (_isSellerSide) {
      return const [
        'Oi! Tenho esse item disponivel.',
        'Posso te passar mais detalhes agora.',
        'Se quiser, pode me mandar uma oferta.',
      ];
    }

    return const [
      'Oi! Ainda esta disponivel?',
      'Voce consegue entregar hoje?',
      'Aceita negociar o valor?',
    ];
  }

  void _openOtherProfile() {
    final otherUserId = widget.otherUserId?.trim() ?? '';
    if (otherUserId.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SellerProfileScreen(
          sellerId: otherUserId,
          sellerName: widget.otherUserName,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _messageCtrl.addListener(() {
      if (_showQuickReplies && _messageCtrl.text.isNotEmpty) {
        setState(() => _showQuickReplies = false);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeOpenOfferComposer();
      _maybePromptPendingReview();
    });
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  String _formatCurrency(double value) {
    final fixed = value.toStringAsFixed(2).split('.');
    final chars = fixed[0].split('');
    final buffer = StringBuffer();
    for (var i = 0; i < chars.length; i++) {
      final reverseIndex = chars.length - i;
      buffer.write(chars[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write('.');
      }
    }
    return 'R\$ ${buffer.toString()},${fixed[1]}';
  }

  double? _parseCurrency(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isEmpty) return null;
    return int.parse(cleaned) / 100;
  }

  Future<void> _sendMessage([String? forcedText]) async {
    final text = (forcedText ?? _messageCtrl.text).trim();
    if (text.isEmpty) return;

    final user = context.read<UserProvider>().user;
    if (user == null) return;

    _messageCtrl.clear();
    try {
      await _firestore.sendMessage(widget.chatId, user.uid, text);
      if (mounted) setState(() => _showQuickReplies = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Erro ao enviar mensagem. Tente novamente.')),
      );
      _messageCtrl.text = text;
    }
  }

  Future<void> _sendQuickReply(String text) async {
    await _sendMessage(text);
  }

  bool get _canSendOffer {
    final currentUserId = context.read<UserProvider>().user?.uid;
    return _hasLinkedAd &&
        widget.sellerId != null &&
        widget.sellerId!.isNotEmpty &&
        widget.adPrice != null &&
        widget.adIntent != AdModel.intentBuy &&
        currentUserId != null &&
        currentUserId != widget.sellerId;
  }

  Future<void> _maybeOpenOfferComposer() async {
    if (!mounted || _handledInitialOffer || !widget.openOfferComposerOnLoad) {
      return;
    }
    _handledInitialOffer = true;
    if (_canSendOffer) {
      await _startOfferFlow();
    }
  }

  Future<double?> _showPriceDialog({
    required String title,
    required String actionLabel,
    required List<String> details,
  }) async {
    final controller = TextEditingController();

    controller.addListener(() {
      final parsed = _parseCurrency(controller.text);
      if (parsed == null) return;
      final formatted = _formatCurrency(parsed).replaceFirst('R\$ ', '');
      if (formatted == controller.text) return;
      controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    });

    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : Colors.black87;

        return AlertDialog(
          backgroundColor: isDark ? AppTheme.blackCard : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text(
            title,
            style: GoogleFonts.roboto(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...details.map(
                (detail) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    detail,
                    style: GoogleFonts.roboto(
                      color: isDark
                          ? AppTheme.whiteSecondary
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: GoogleFonts.roboto(color: textColor),
                decoration: InputDecoration(
                  labelText: 'R\$ x,xx',
                  prefixText: 'R\$ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                _parseCurrency(controller.text),
              ),
              child: Text(actionLabel),
            ),
          ],
        );
      },
    );

    await Future.delayed(const Duration(milliseconds: 350));
    controller.dispose();
    return result;
  }

  Future<void> _acceptOffer(String messageId, Map<String, dynamic> data) async {
    await _firestore.updateOfferMessage(
      chatId: widget.chatId,
      messageId: messageId,
      updates: {
        'offerStatus': 'accepted',
        'agreedPrice': data['offerPrice'],
      },
      preview: 'Oferta aceita',
    );
  }

  Future<void> _rejectOffer(String messageId) async {
    await _firestore.updateOfferMessage(
      chatId: widget.chatId,
      messageId: messageId,
      updates: {'offerStatus': 'rejected'},
      preview: 'Oferta recusada',
    );
  }

  Future<void> _counterOffer(
      String messageId, Map<String, dynamic> data) async {
    final adPrice = (data['adPrice'] as num?)?.toDouble() ?? 0;
    final offerPrice = (data['offerPrice'] as num?)?.toDouble() ?? 0;
    final value = await _showPriceDialog(
      title: 'Enviar contra proposta',
      actionLabel: 'Enviar contra proposta',
      details: [
        'Preço do anúncio: ${_formatCurrency(adPrice)}',
        'Oferta do comprador: ${_formatCurrency(offerPrice)}',
      ],
    );
    if (value == null) return;

    await _firestore.updateOfferMessage(
      chatId: widget.chatId,
      messageId: messageId,
      updates: {
        'offerStatus': 'countered',
        'counterPrice': value,
      },
      preview: 'Contra proposta enviada',
    );
  }

  Future<void> _acceptCounter(
      String messageId, Map<String, dynamic> data) async {
    await _firestore.updateOfferMessage(
      chatId: widget.chatId,
      messageId: messageId,
      updates: {
        'offerStatus': 'closed',
        'agreedPrice': data['counterPrice'],
      },
      preview: 'Negociação concluída',
    );
  }

  Future<void> _declineCounter(String messageId) async {
    await _firestore.updateOfferMessage(
      chatId: widget.chatId,
      messageId: messageId,
      updates: {'offerStatus': 'buyer_declined'},
      preview: 'Comprador desistiu',
    );
  }

  Future<void> _reoffer(String messageId, Map<String, dynamic> data) async {
    final adPrice = (data['adPrice'] as num?)?.toDouble() ?? 0;
    final counterPrice = (data['counterPrice'] as num?)?.toDouble() ?? 0;
    final value = await _showPriceDialog(
      title: 'Enviar rebate',
      actionLabel: 'Enviar rebate',
      details: [
        'Preço do anúncio: ${_formatCurrency(adPrice)}',
        'Contra proposta atual: ${_formatCurrency(counterPrice)}',
      ],
    );
    if (value == null) return;

    await _firestore.updateOfferMessage(
      chatId: widget.chatId,
      messageId: messageId,
      updates: {
        'offerStatus': 'pending',
        'offerPrice': value,
        'counterPrice': null,
        'agreedPrice': null,
      },
      preview: 'Nova oferta enviada',
    );
  }

  Future<void> _startOfferFlow() async {
    if (!_canSendOffer) return;

    final user = context.read<UserProvider>().user;
    if (user == null) return;

    final value = await _showPriceDialog(
      title: 'Fazer oferta',
      actionLabel: 'Enviar oferta',
      details: [
        'Anúncio: ${widget.adTitle}',
        'Preço do anúncio: ${_formatCurrency(widget.adPrice ?? 0)}',
      ],
    );
    if (value == null) return;

    await _firestore.sendOfferMessage(
      chatId: widget.chatId,
      senderId: user.uid,
      buyerId: user.uid,
      sellerId: widget.sellerId!,
      buyerFirstName:
          user.firstName.isNotEmpty ? user.firstName : user.fullName,
      adId: widget.adId!,
      adTitle: widget.adTitle,
      adPrice: widget.adPrice!,
      offerPrice: value,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Oferta enviada com sucesso.')),
    );
  }

  Future<void> _maybePromptPendingReview() async {
    if (!mounted || _isSellerSide || !_hasLinkedAd) return;

    final user = context.read<UserProvider>().user;
    if (user == null) return;

    final pendingRequests = await _firestore.getPendingReviewRequests(user.uid);
    if (!mounted || pendingRequests.isEmpty) return;

    final currentAdId = (widget.adId ?? '').trim();
    final currentChatId = widget.chatId.trim();

    Map<String, dynamic>? pendingRequest;
    for (final request in pendingRequests) {
      final requestChatId = (request['chatId'] as String? ?? '').trim();
      final requestAdId = (request['adId'] as String? ?? '').trim();
      if ((requestChatId.isNotEmpty && requestChatId == currentChatId) ||
          (requestAdId.isNotEmpty && requestAdId == currentAdId)) {
        pendingRequest = request;
        break;
      }
    }

    if (pendingRequest == null) return;

    final submission = await _showPendingReviewDialog(pendingRequest);
    if (!mounted || submission == null) return;

    await _firestore.submitSaleReview(
      reviewRequestId: pendingRequest['id'] as String,
      reviewerId: user.uid,
      reviewerName: user.fullName.trim().isNotEmpty ? user.fullName : 'Usuario',
      reviewerAvatar: user.profilePhoto,
      rating: submission['rating'] as int,
      strengths: List<String>.from(
        submission['strengths'] as List<dynamic>? ?? const [],
      ),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Avaliacao enviada com sucesso.')),
    );
  }

  Future<Map<String, dynamic>?> _showPendingReviewDialog(
    Map<String, dynamic> request,
  ) async {
    var selectedRating = 0;
    final selectedStrengths = <String>{};

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : Colors.black87;
        final subtitleColor =
            isDark ? AppTheme.whiteSecondary : Colors.grey.shade700;
        final sellerName =
            (request['sellerName'] as String? ?? widget.otherUserName).trim();
        final storeName = (request['storeName'] as String? ?? '').trim();
        final adTitle = (request['adTitle'] as String? ?? widget.adTitle).trim();
        final sellerAvatar =
            (request['sellerAvatar'] as String? ?? '').trim();

        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: isDark ? AppTheme.blackCard : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            title: Text(
              'Avalie sua compra',
              style: GoogleFonts.roboto(
                color: textColor,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor:
                            AppTheme.facebookBlue.withValues(alpha: 0.12),
                        backgroundImage: sellerAvatar.isNotEmpty
                            ? NetworkImage(sellerAvatar)
                            : null,
                        child: sellerAvatar.isEmpty
                            ? Text(
                                sellerName.isNotEmpty
                                    ? sellerName[0].toUpperCase()
                                    : 'V',
                                style: GoogleFonts.roboto(
                                  color: AppTheme.facebookBlue,
                                  fontWeight: FontWeight.w800,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sellerName.isNotEmpty ? sellerName : 'Vendedor',
                              style: GoogleFonts.roboto(
                                color: textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (storeName.isNotEmpty)
                              Text(
                                storeName,
                                style: GoogleFonts.roboto(
                                  color: AppTheme.facebookBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (adTitle.isNotEmpty)
                              Text(
                                adTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.roboto(
                                  color: subtitleColor,
                                  fontSize: 12.5,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Como foi sua experiencia?',
                    style: GoogleFonts.roboto(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: List.generate(
                      5,
                      (index) => IconButton(
                        onPressed: () {
                          setDialogState(() => selectedRating = index + 1);
                        },
                        icon: Icon(
                          index < selectedRating
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: Colors.amber,
                          size: 32,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 40,
                          height: 40,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Pontos fortes do vendedor',
                    style: GoogleFonts.roboto(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _sellerStrengthOptions.map((strength) {
                      final isSelected = selectedStrengths.contains(strength);
                      return FilterChip(
                        label: Text(strength),
                        selected: isSelected,
                        onSelected: (selected) {
                          setDialogState(() {
                            if (selected) {
                              selectedStrengths.add(strength);
                            } else {
                              selectedStrengths.remove(strength);
                            }
                          });
                        },
                        selectedColor:
                            AppTheme.facebookBlue.withValues(alpha: 0.14),
                        checkmarkColor: AppTheme.facebookBlue,
                        labelStyle: GoogleFonts.roboto(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? AppTheme.facebookBlue.withValues(alpha: 0.30)
                              : (isDark
                                  ? AppTheme.blackBorder
                                  : const Color(0xFFE5E7EB)),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Depois'),
              ),
              FilledButton(
                onPressed: selectedRating == 0
                    ? null
                    : () => Navigator.of(dialogContext).pop({
                          'rating': selectedRating,
                          'strengths': selectedStrengths.toList(),
                        }),
                child: const Text('Enviar avaliacao'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickReplies(bool isDark) {
    if (_isDirectChat || !_showQuickReplies) return const SizedBox.shrink();
    final quickReplies = _roleQuickReplies;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: quickReplies.map((reply) {
          return ActionChip(
            onPressed: () => _sendQuickReply(reply),
            backgroundColor:
                isDark ? AppTheme.blackLight : const Color(0xFFEFF4FF),
            side: BorderSide(
              color: isDark ? AppTheme.blackBorder : const Color(0xFFD4E3FF),
            ),
            label: Text(
              reply,
              style: GoogleFonts.roboto(
                color: isDark ? Colors.white : AppTheme.facebookBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isMe, bool isDark) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe
              ? AppTheme.facebookBlue
              : (isDark ? AppTheme.blackLight : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomRight:
                isMe ? const Radius.circular(0) : const Radius.circular(18),
            bottomLeft:
                isMe ? const Radius.circular(18) : const Radius.circular(0),
          ),
        ),
        child: Text(
          text,
          style: GoogleFonts.roboto(
            color:
                isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildOfferCard(
    Map<String, dynamic> data,
    String messageId,
    bool isDark,
    String currentUserId,
  ) {
    final buyerId = data['buyerId'] as String? ?? '';
    final sellerId = data['sellerId'] as String? ?? '';
    final buyerName = data['buyerFirstName'] as String? ?? 'Usuário';
    final offerStatus = data['offerStatus'] as String? ?? 'pending';
    final adPrice = (data['adPrice'] as num?)?.toDouble() ?? 0;
    final offerPrice = (data['offerPrice'] as num?)?.toDouble() ?? 0;
    final counterPrice = (data['counterPrice'] as num?)?.toDouble();
    final agreedPrice = (data['agreedPrice'] as num?)?.toDouble();
    final isSeller = currentUserId == sellerId;
    final isBuyer = currentUserId == buyerId;

    Color accent;
    String title;
    String subtitle;
    List<Widget> actions = [];

    switch (offerStatus) {
      case 'pending':
        accent = Colors.blue;
        if (isSeller) {
          title =
              'O $buyerName ofereceu ${_formatCurrency(offerPrice)} pelo seu item.';
          subtitle = 'Preço do anúncio: ${_formatCurrency(adPrice)}';
          actions = [
            _actionButton(
                'Aceitar', accent, () => _acceptOffer(messageId, data)),
            _actionButton('Recusar', Colors.red, () => _rejectOffer(messageId)),
            _actionButton('Contra proposta', Colors.orange,
                () => _counterOffer(messageId, data)),
          ];
        } else {
          title = 'Oferta aguardando resposta';
          subtitle = 'Você ofereceu ${_formatCurrency(offerPrice)}.';
        }
        break;
      case 'accepted':
        accent = Colors.green;
        title = 'Oferta aceita pelo vendedor!';
        subtitle = 'Uhuuul, agora marquem um ponto de encontro.';
        break;
      case 'rejected':
        accent = Colors.red;
        title = 'Sua oferta foi recusada pelo vendedor.';
        subtitle = 'Tente mandar uma oferta maior e conversar com o vendedor.';
        if (isBuyer) {
          actions = [
            _actionButton(
                'Nova oferta',
                Colors.red,
                () => _reoffer(messageId, {
                      ...data,
                      'counterPrice': data['adPrice'],
                    })),
          ];
        }
        break;
      case 'countered':
        accent = Colors.amber.shade700;
        if (isBuyer) {
          title =
              'O vendedor pensou na sua proposta de ${_formatCurrency(offerPrice)}, mas disse que vende por ${_formatCurrency(counterPrice ?? 0)}';
          subtitle = 'Vocês ainda podem fechar um bom negócio.';
          actions = [
            _actionButton(
                'Aceitar', Colors.green, () => _acceptCounter(messageId, data)),
            _actionButton(
                'Desistir', Colors.red, () => _declineCounter(messageId)),
            _actionButton(
                'Rebater', Colors.orange, () => _reoffer(messageId, data)),
          ];
        } else {
          title =
              'Contra proposta enviada por ${_formatCurrency(counterPrice ?? 0)}';
          subtitle = 'Aguardando o comprador decidir.';
        }
        break;
      case 'closed':
        accent = Colors.green;
        title = 'A negociação foi um sucesso!';
        subtitle =
            'Vocês fecharam por ${_formatCurrency(agreedPrice ?? counterPrice ?? offerPrice)}. Marquem um local de encontro e finalizem o negócio :D';
        break;
      case 'buyer_declined':
        accent = Colors.red.shade400;
        title = 'O comprador desistiu da negociação :(';
        subtitle =
            'Se algo ficou mal entendido vocês ainda podem usar o chat, não desistam um do outro!';
        break;
      default:
        accent = Colors.blueGrey;
        title = 'Atualização de negociação';
        subtitle = 'Confira os detalhes acima.';
    }

    return Align(
      alignment: isBuyer ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.84),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.blackCard : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Negociação',
                style: GoogleFonts.roboto(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.roboto(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: GoogleFonts.roboto(
                color: isDark ? AppTheme.whiteSecondary : Colors.grey.shade700,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback onPressed) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        label,
        style: GoogleFonts.roboto(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildChatHeader(bool isDark, Color textColor) {
    final otherUserId = widget.otherUserId?.trim() ?? '';
    final showAdTitle = !_isDirectChat && widget.adTitle.trim().isNotEmpty;

    if (otherUserId.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.otherUserName,
            style: GoogleFonts.roboto(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (showAdTitle)
            Text(
              widget.adTitle,
              style: GoogleFonts.roboto(color: Colors.grey, fontSize: 12),
            ),
        ],
      );
    }

    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final profilePhoto = (data?['profilePhoto'] as String? ?? '').trim();
        final initials = widget.otherUserName.trim().isNotEmpty
            ? widget.otherUserName.trim()[0].toUpperCase()
            : 'U';

        return InkWell(
          onTap: _openOtherProfile,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              GestureDetector(
                onTap: _openOtherProfile,
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor:
                      AppTheme.facebookBlue.withValues(alpha: 0.12),
                  backgroundImage: profilePhoto.isNotEmpty
                      ? NetworkImage(profilePhoto)
                      : null,
                  child: profilePhoto.isEmpty
                      ? Text(
                          initials,
                          style: GoogleFonts.roboto(
                            color: AppTheme.facebookBlue,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.otherUserName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.roboto(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (showAdTitle)
                      Text(
                        widget.adTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.roboto(
                            color: Colors.grey, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDealBar(bool isDark) {
    if (!_hasLinkedAd) return const SizedBox.shrink();
    final adId = widget.adId!.trim();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('ads').doc(adId).get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        if (data == null) return const SizedBox.shrink();

        final ad = AdModel.fromMap(data);
        final imageUrl = ad.images.isNotEmpty ? ad.images.first.trim() : '';
        final subtitleColor =
            isDark ? AppTheme.whiteSecondary : Colors.grey.shade700;
        final barHeight = _showDealBar ? 112.0 : 0.0;
        if (barHeight <= 2) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: barHeight,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.blackCard : Colors.white,
              border: Border(
                top: BorderSide(
                  color:
                      isDark ? AppTheme.blackBorder : const Color(0xFFE4E7EB),
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 56,
                          height: 56,
                          color: isDark
                              ? AppTheme.blackLight
                              : const Color(0xFFF3F4F6),
                          child: imageUrl.isNotEmpty
                              ? Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.image_rounded,
                                    color: subtitleColor,
                                  ),
                                )
                              : Icon(
                                  Icons.image_rounded,
                                  color: subtitleColor,
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ad.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.roboto(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${ad.displayPriceLabel} | ${ad.location}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.roboto(
                                  color: subtitleColor,
                                  fontSize: 12.2,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 30,
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AdDetailScreen(ad: ad),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(30),
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              textStyle: GoogleFonts.roboto(
                                fontSize: 12.2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: const Text('Ver anuncio'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: _canSendOffer ? _startOfferFlow : null,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(30),
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              textStyle: GoogleFonts.roboto(
                                fontSize: 12.2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: const Text('Fazer oferta'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputArea(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.blackCard : Colors.white,
        border: Border(
            top: BorderSide(
                color: isDark ? AppTheme.blackBorder : Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageCtrl,
              style: GoogleFonts.roboto(
                  color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Digite uma mensagem...',
                hintStyle: GoogleFonts.roboto(color: Colors.grey),
                filled: true,
                fillColor: isDark ? AppTheme.black : Colors.grey.shade100,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          if (_canSendOffer)
            IconButton(
              icon: const Icon(
                Icons.local_offer_rounded,
                color: AppTheme.facebookBlue,
              ),
              onPressed: _startOfferFlow,
              tooltip: 'Fazer oferta',
            ),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: AppTheme.facebookBlue),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.black : AppTheme.lightBg;
    final textColor = isDark ? Colors.white : Colors.black87;
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.user;
    final isPinned = userProvider.isPinnedChat(widget.chatId);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.black : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: _buildChatHeader(isDark, textColor),
        actions: [
          IconButton(
            onPressed: user == null
                ? null
                : () => userProvider.togglePinnedChat(widget.chatId),
            icon: Icon(
              isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              color: isPinned ? AppTheme.facebookBlue : textColor,
            ),
            tooltip: isPinned ? 'Desafixar conversa' : 'Fixar conversa',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(
            _hasLinkedAd ? 112 : 0,
          ),
          child: _buildDealBar(isDark),
        ),
      ),
      body: EdgeSwipeBack(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.getMessagesStream(widget.chatId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.facebookBlue));
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Erro ao carregar mensagens',
                        style: GoogleFonts.roboto(color: Colors.grey),
                      ),
                    );
                  }

                  final docs = List<QueryDocumentSnapshot>.from(
                      snapshot.data?.docs ?? [])
                    ..sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      final aTime = (aData['time'] as Timestamp?)?.toDate() ??
                          DateTime(2000);
                      final bTime = (bData['time'] as Timestamp?)?.toDate() ??
                          DateTime(2000);
                      return bTime.compareTo(aTime);
                    });

                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        'Nenhuma mensagem ainda.',
                        style: GoogleFonts.roboto(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final type = data['type'] as String? ?? 'text';
                      final isMe = data['senderId'] == user?.uid;

                      if (type == 'offer' && user != null) {
                        return _buildOfferCard(data, doc.id, isDark, user.uid);
                      }

                      final text = data['text'] as String? ?? '';
                      if (text.isEmpty) return const SizedBox.shrink();
                      return _buildMessageBubble(text, isMe, isDark);
                    },
                  );
                },
              ),
            ),
            _buildQuickReplies(isDark),
            _buildInputArea(isDark),
          ],
        ),
      ),
    );
  }
}
