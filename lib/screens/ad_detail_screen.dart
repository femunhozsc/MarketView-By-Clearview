import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/ad_model.dart';
import '../providers/user_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ad_card.dart';
import '../widgets/edge_swipe_back.dart';
import '../widgets/favorite_button.dart';
import 'chat_detail_screen.dart';
import 'edit_ad_screen.dart';
import 'image_gallery_viewer_screen.dart';
import 'my_store_screen.dart';
import 'seller_profile_screen.dart';
import 'profile_screen.dart';

class AdDetailScreen extends StatefulWidget {
  const AdDetailScreen({
    super.key,
    required this.ad,
  });

  final AdModel ad;

  @override
  State<AdDetailScreen> createState() => _AdDetailScreenState();
}

class _AdDetailScreenState extends State<AdDetailScreen> {
  final _firestore = FirestoreService();
  final _pageController = PageController();
  final _messageComposer = TextEditingController(
    text: 'Oi, esse item ainda está disponível?',
  );
  int _currentImage = 0;

  List<String> get _galleryImages => widget.ad.images
      .where((image) => image.trim().isNotEmpty)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    if (widget.ad.id.isNotEmpty) {
      _firestore.incrementAdClick(widget.ad.id);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<UserProvider>().trackRecentlyViewedAd(widget.ad.id);
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _messageComposer.dispose();
    super.dispose();
  }

  Future<String?> _ensureChat() async {
    final user = context.read<UserProvider>().user;
    if (user == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
      return null;
    }

    if (user.uid == widget.ad.sellerId || widget.ad.sellerId.isEmpty) {
      return null;
    }

    return _firestore.getOrCreateChat(
      user.uid,
      widget.ad.sellerId,
      widget.ad.id,
      adTitle: widget.ad.title,
    );
  }

  Future<void> _openChat() async {
    final chatId = await _ensureChat();
    if (chatId == null || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          chatId: chatId,
          otherUserId: widget.ad.sellerId,
          otherUserName:
              widget.ad.isStoreAd && widget.ad.displaySellerUserName.isNotEmpty
                  ? widget.ad.displaySellerUserName
                  : widget.ad.displaySellerName,
          adTitle: widget.ad.title,
          adId: widget.ad.id,
          sellerId: widget.ad.sellerId,
          adPrice: widget.ad.price,
          adIntent: widget.ad.intent,
        ),
      ),
    );
  }

  Future<void> _openOfferFlow() async {
    final chatId = await _ensureChat();
    if (chatId == null || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          chatId: chatId,
          otherUserId: widget.ad.sellerId,
          otherUserName:
              widget.ad.isStoreAd && widget.ad.displaySellerUserName.isNotEmpty
                  ? widget.ad.displaySellerUserName
                  : widget.ad.displaySellerName,
          adTitle: widget.ad.title,
          adId: widget.ad.id,
          sellerId: widget.ad.sellerId,
          adPrice: widget.ad.price,
          adIntent: widget.ad.intent,
          openOfferComposerOnLoad: true,
        ),
      ),
    );
  }

  Future<void> _openEditAd() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditAdScreen(ad: widget.ad)),
    );
    if (!mounted) return;

    final refreshedAd = await _firestore.getAd(widget.ad.id);
    if (!mounted) return;

    context.read<UserProvider>().notifyMarketplaceChanged();

    if (refreshedAd == null || !refreshedAd.isActive) {
      Navigator.pop(context);
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => AdDetailScreen(ad: refreshedAd)),
    );
  }

  Future<bool?> _askIfSoldOnMarketView() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Você vendeu no MarketView?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Se a venda aconteceu pelo app, vamos vincular o comprador para pedir a avaliacao depois.',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Sim, eu vendi no MarketView'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Nao, eu nao vendi no MarketView'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmSoldWithoutBuyer() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nenhum comprador encontrado'),
        content: const Text(
          'Não encontramos conversas sobre esse anúncio. Deseja marcar como vendido mesmo assim?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Marcar como vendido'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<Map<String, dynamic>?> _pickBuyerForSale(
    List<Map<String, dynamic>> candidates,
  ) {
    String? selectedBuyerId;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Quem comprou esse produto?'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Selecione um dos usuários que conversaram com você sobre este anúncio.',
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 320,
                  child: SingleChildScrollView(
                    child: Column(
                      children: candidates.map((candidate) {
                        final buyerId = candidate['buyerId'] as String? ?? '';
                        final buyerName =
                            candidate['buyerName'] as String? ?? 'Usuario';
                        final buyerPhoto =
                            (candidate['buyerPhoto'] as String? ?? '').trim();
                        final lastMessage =
                            (candidate['lastMessage'] as String? ?? '').trim();
                        final isSelected = selectedBuyerId == buyerId;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.facebookBlue
                                  : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              setDialogState(() => selectedBuyerId = buyerId);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppTheme.facebookBlue
                                        .withValues(alpha: 0.12),
                                    backgroundImage: buyerPhoto.isNotEmpty
                                        ? NetworkImage(buyerPhoto)
                                        : null,
                                    child: buyerPhoto.isEmpty
                                        ? Text(
                                            buyerName[0].toUpperCase(),
                                            style: GoogleFonts.roboto(
                                              color: AppTheme.facebookBlue,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          buyerName,
                                          style: GoogleFonts.roboto(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        if (lastMessage.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            lastMessage,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.roboto(
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    isSelected
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.radio_button_off_rounded,
                                    color: isSelected
                                        ? AppTheme.facebookBlue
                                        : Colors.grey,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: selectedBuyerId == null
                  ? null
                  : () => Navigator.pop(
                        dialogContext,
                        candidates.firstWhere(
                          (candidate) =>
                              candidate['buyerId'] == selectedBuyerId,
                        ),
                      ),
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmSelectedBuyer(Map<String, dynamic> buyer) async {
    final buyerName = buyer['buyerName'] as String? ?? 'Usuario';
    final buyerPhoto = (buyer['buyerPhoto'] as String? ?? '').trim();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar comprador'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 38,
              backgroundColor: AppTheme.facebookBlue.withValues(alpha: 0.12),
              backgroundImage:
                  buyerPhoto.isNotEmpty ? NetworkImage(buyerPhoto) : null,
              child: buyerPhoto.isEmpty
                  ? Text(
                      buyerName[0].toUpperCase(),
                      style: GoogleFonts.roboto(
                        color: AppTheme.facebookBlue,
                        fontWeight: FontWeight.w800,
                        fontSize: 28,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 14),
            Text(
              buyerName,
              style: GoogleFonts.roboto(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Você confirma que foi esse usuário que comprou o anúncio?',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _markAsSold() async {
    final soldOnMarketView = await _askIfSoldOnMarketView();
    if (soldOnMarketView == null) return;

    Map<String, dynamic>? selectedBuyer;
    var shouldCreateReviewRequest = false;

    if (soldOnMarketView) {
      final candidates = await _firestore.getSaleBuyerCandidates(widget.ad.id);
      if (!mounted) return;

      if (candidates.isEmpty) {
        final proceedWithoutBuyer = await _confirmSoldWithoutBuyer();
        if (!proceedWithoutBuyer) return;
      } else {
        selectedBuyer = await _pickBuyerForSale(candidates);
        if (selectedBuyer == null) return;

        final confirmedBuyer = await _confirmSelectedBuyer(selectedBuyer);
        if (!confirmedBuyer) return;
        shouldCreateReviewRequest = true;
      }
    }

    try {
      await _firestore.markAdAsSold(
        ad: widget.ad,
        soldOnMarketView: shouldCreateReviewRequest,
        buyerId: selectedBuyer?['buyerId'] as String?,
        buyerName: selectedBuyer?['buyerName'] as String?,
        buyerPhoto: selectedBuyer?['buyerPhoto'] as String?,
        chatId: selectedBuyer?['chatId'] as String?,
      );
      if (!mounted) return;

      context.read<UserProvider>().notifyMarketplaceChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            shouldCreateReviewRequest
                ? 'Anuncio vendido e comprador vinculado para avaliacao.'
                : 'Anuncio marcado como vendido.',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nao foi possivel marcar como vendido: $e')),
      );
    }
  }

  void _openGallery([int initialIndex = 0]) {
    if (_galleryImages.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageGalleryViewerScreen(
          images: _galleryImages,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.black : Colors.white;
    final sectionBg = isDark ? AppTheme.blackCard : Colors.white;
    final border = isDark ? AppTheme.blackBorder : const Color(0xFFE5E7EB);
    final titleColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? AppTheme.whiteSecondary : Colors.grey.shade600;
    final sellerName = widget.ad.displaySellerName.trim().isNotEmpty
        ? widget.ad.displaySellerName.trim()
        : 'Vendedor';
    final sellerAvatarUrl = widget.ad.displaySellerAvatar.trim();
    final validImages = _galleryImages;
    final isFollowing =
        context.watch<UserProvider>().isFollowingSeller(widget.ad.sellerId);
    final isMe = context.watch<UserProvider>().user?.uid == widget.ad.sellerId;
    final canNegotiate =
        !widget.ad.isWantedAd && !isMe && widget.ad.sellerId.isNotEmpty;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded, color: titleColor),
        ),
        actions: [
          FavoriteButton(
            adId: widget.ad.id,
            size: 34,
            showBackground: false,
          ),
        ],
      ),
      body: EdgeSwipeBack(
        child: ListView(
          children: [
            SizedBox(
              height: 340,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (validImages.isNotEmpty)
                    PageView.builder(
                      controller: _pageController,
                      itemCount: validImages.length,
                      onPageChanged: (value) =>
                          setState(() => _currentImage = value),
                      itemBuilder: (_, index) => GestureDetector(
                        onTap: () => _openGallery(index),
                        child: Image.network(
                          validImages[index],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: Colors.grey.shade500,
                              size: 44,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(color: Colors.grey.shade200),
                  if (validImages.length > 1)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_currentImage + 1}/${validImages.length}',
                            style: GoogleFonts.roboto(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              color: sectionBg,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.ad.title,
                    style: GoogleFonts.roboto(
                      color: titleColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (widget.ad.isWantedAd)
                    Text(
                      'Ele(a) espera pagar:',
                      style: GoogleFonts.roboto(
                        color: subColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (widget.ad.isWantedAd) const SizedBox(height: 2),
                  Text(
                    widget.ad.displayPriceLabel,
                    style: GoogleFonts.roboto(
                      color: titleColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.ad.location,
                    style: GoogleFonts.roboto(color: subColor),
                  ),
                ],
              ),
            ),
            _section(
              title: 'Descrição',
              child: Text(
                widget.ad.description,
                style: GoogleFonts.roboto(
                  color: subColor,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
            _section(
              title: widget.ad.isWantedAd ? 'Solicitante' : 'Vendedor',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _SellerAvatar(
                        imageUrl: sellerAvatarUrl,
                        label: sellerName,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (widget.ad.isStoreAd) {
                              if (isMe) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MyStoreScreen(
                                        storeId: widget.ad.storeId),
                                  ),
                                );
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SellerProfileScreen(
                                      sellerId: widget.ad.sellerId,
                                      sellerName: widget.ad.displaySellerName,
                                      storeId: widget.ad.storeId,
                                    ),
                                  ),
                                );
                              }
                              return;
                            }

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SellerProfileScreen(
                                  sellerId: widget.ad.sellerId,
                                  sellerName: widget.ad.displaySellerName,
                                ),
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sellerName,
                                style: GoogleFonts.roboto(
                                  color: titleColor,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                widget.ad.isStoreAd
                                    ? 'Perfil da loja'
                                    : (widget.ad.isWantedAd
                                        ? 'Perfil de quem precisa disso'
                                        : 'Perfil do vendedor'),
                                style: GoogleFonts.roboto(color: subColor),
                              ),
                            ],
                          ),
                        ),
                      ),
                      FilledButton(
                        onPressed: widget.ad.sellerId.isEmpty
                            ? null
                            : () {
                                if (context.read<UserProvider>().user == null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                                  );
                                  return;
                                }
                                context.read<UserProvider>().toggleFollowSeller(widget.ad.sellerId);
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: isFollowing
                              ? Colors.grey.shade400
                              : AppTheme.facebookBlue,
                        ),
                        child: Text(isFollowing ? 'Seguindo' : 'Seguir'),
                      ),
                    ],
                  ),
                  if (widget.ad.isStoreAd &&
                      widget.ad.sellerUserName != null &&
                      widget.ad.sellerUserName!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      children: [
                        Text(
                          'Anúncio feito pelo vendedor ',
                          style: GoogleFonts.roboto(color: subColor),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SellerProfileScreen(
                                sellerId: widget.ad.sellerId,
                                sellerName: widget.ad.displaySellerUserName,
                              ),
                            ),
                          ),
                          child: Text(
                            widget.ad.displaySellerUserName,
                            style: GoogleFonts.roboto(
                              color: AppTheme.facebookBlue,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            _section(
              title: 'Detalhes',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow('Categoria', widget.ad.displayCategoryLabel,
                      titleColor, subColor),
                  if (widget.ad.displayCategoryTypeLabel.isNotEmpty)
                    _detailRow(
                      'Subtipo',
                      widget.ad.displayCategoryTypeLabel,
                      titleColor,
                      subColor,
                    ),
                  _detailRow(
                    'Tipo',
                    widget.ad.displayTypeLabel,
                    titleColor,
                    subColor,
                  ),
                  if (widget.ad.isServiceAd)
                    _detailRow(
                      'Cobrança',
                      widget.ad.displayServicePriceTypeLabel,
                      titleColor,
                      subColor,
                    ),
                  if (widget.ad.isPropertyProduct)
                    _detailRow(
                      'Negocio',
                      widget.ad.displayPropertyOfferLabel,
                      titleColor,
                      subColor,
                    ),
                  _detailRow(
                    'Secao',
                    widget.ad.isWantedAd ? 'Compro' : 'Vendo',
                    titleColor,
                    subColor,
                  ),
                  if (widget.ad.storeName != null &&
                      widget.ad.storeName!.isNotEmpty)
                    _detailRow(
                        'Loja', widget.ad.storeName!, titleColor, subColor),
                ],
              ),
            ),
            if (widget.ad.hasVehicleDetails)
              _section(
                title: 'Ficha do veículo',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.ad.vehicleDetailEntries
                      .map(
                        (entry) => _detailRow(
                          entry.key,
                          entry.value,
                          titleColor,
                          subColor,
                        ),
                      )
                      .toList(),
                ),
              ),
            if (widget.ad.hasPropertyDetails)
              _section(
                title: 'Ficha do imovel',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.ad.propertyDetailEntries
                      .where((entry) => entry.key != 'Subtipo')
                      .map(
                        (entry) => _detailRow(
                          entry.key,
                          entry.value,
                          titleColor,
                          subColor,
                        ),
                      )
                      .toList(),
                ),
              ),
            _section(
              title: 'Da mesma categoria',
              child: FutureBuilder<List<AdModel>>(
                future: _firestore.getAdsByCategory(
                  widget.ad.category,
                  excludeAdId: widget.ad.id,
                  intent: widget.ad.intent,
                  limit: 6,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.facebookBlue,
                        ),
                      ),
                    );
                  }

                  final relatedAds = snapshot.data ?? const <AdModel>[];
                  if (relatedAds.isEmpty) {
                    return Text(
                      widget.ad.isWantedAd
                          ? 'Nenhum outro pedido desta categoria por enquanto.'
                          : 'Nenhum outro anúncio desta categoria por enquanto.',
                      style: GoogleFonts.roboto(color: subColor),
                    );
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount =
                          constraints.maxWidth >= 720 ? 3 : 2;
                      final mainAxisExtent =
                          constraints.maxWidth >= 720 ? 300.0 : 282.0;

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: relatedAds.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          mainAxisExtent: mainAxisExtent,
                        ),
                        itemBuilder: (context, index) => AdCard(
                          ad: relatedAds[index],
                          index: index,
                          onTap: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AdDetailScreen(ad: relatedAds[index]),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: BoxDecoration(
            color: sectionBg,
            border: Border(top: BorderSide(color: border)),
          ),
          child: Row(
            children: [
              if (isMe) ...[
                Expanded(
                  flex: 3,
                  child: FilledButton.icon(
                    onPressed: _markAsSold,
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('Marcar como vendido'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.facebookBlue,
                      minimumSize: const Size.fromHeight(48),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: _openEditAd,
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Editar'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _openChat,
                    icon: const Icon(Icons.chat_bubble_rounded),
                    label: const Text('Mensagem'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.facebookBlue,
                      minimumSize: const Size.fromHeight(48),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                if (!widget.ad.isWantedAd) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: canNegotiate ? _openOfferFlow : null,
                      icon: const Icon(Icons.local_offer_rounded),
                      label: const Text('Fazer oferta'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value,
    Color titleColor,
    Color subColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.roboto(color: subColor),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.roboto(
                color: titleColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : Colors.black87;

    return Container(
      color: isDark ? AppTheme.blackCard : Colors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.roboto(
              color: titleColor,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SellerAvatar extends StatelessWidget {
  const _SellerAvatar({
    required this.imageUrl,
    required this.label,
  });

  final String imageUrl;
  final String label;

  @override
  Widget build(BuildContext context) {
    final fallback = label.isNotEmpty ? label[0].toUpperCase() : '?';

    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xFFE4E6EB),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Text(
                  fallback,
                  style: GoogleFonts.roboto(
                    color: Colors.black87,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                fallback,
                style: GoogleFonts.roboto(
                  color: Colors.black87,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
    );
  }
}
