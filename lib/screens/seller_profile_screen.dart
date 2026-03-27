import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/ad_model.dart';
import '../models/user_model.dart';
import '../models/store_model.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ad_card.dart';
import 'ad_detail_screen.dart';

class SellerProfileScreen extends StatefulWidget {
  final String sellerId;
  final String sellerName;

  const SellerProfileScreen({
    super.key,
    required this.sellerId,
    required this.sellerName,
  });

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  final FirestoreService _firestore = FirestoreService();
  
  UserModel? _user;
  StoreModel? _store;
  List<AdModel> _ads = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  // 🚀 Busca todos os dados de uma vez só, sem recarregar a cada rolagem!
  Future<void> _fetchProfileData() async {
    try {
      final user = await _firestore.getUser(widget.sellerId);
      _user = user;

      if (user != null) {
        if (user.hasStore && user.storeId != null) {
          _store = await _firestore.getStore(user.storeId!);
          
          if (_store != null) {
            _ads = await _firestore.getAdsByStore(_store!.id) ?? [];
          } else {
            // Fallback caso a loja não exista
            _ads = await _firestore.getPersonalAdsByUser(widget.sellerId) ?? [];
          }
        } else {
          _ads = await _firestore.getPersonalAdsByUser(widget.sellerId) ?? [];
        }
      }
    } catch (e) {
      debugPrint("Erro ao carregar perfil do vendedor: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.black : AppTheme.lightBg;
    final textColor = isDark ? Colors.white : Colors.black87;

    // Tela de carregamento única e centralizada
    if (_isLoading) {
      return Scaffold(
        backgroundColor: bg, 
        body: const Center(child: CircularProgressIndicator(color: AppTheme.facebookBlue))
      );
    }

    if (_user == null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: textColor),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Text('Usuário não encontrado.', style: GoogleFonts.outfit(color: textColor)),
        ),
      );
    }

    if (_store != null) {
      return _buildStorePage(context, _store!, isDark, textColor);
    }

    return _buildUserPage(context, widget.sellerId, widget.sellerName, isDark, textColor);
  }

  Widget _buildUserPage(BuildContext context, String uid, String name, bool isDark, Color textColor) {
    return Scaffold(
      backgroundColor: isDark ? AppTheme.black : AppTheme.lightBg,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.black : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Perfil de $name', style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: _ads.isEmpty
          ? Center(child: Text('Nenhum anúncio encontrado.', style: GoogleFonts.outfit(color: Colors.grey)))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Anúncios (${_ads.length})', style: GoogleFonts.outfit(color: textColor, fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, 
                      childAspectRatio: 0.75, 
                      crossAxisSpacing: 12, 
                      mainAxisSpacing: 12
                    ),
                    itemCount: _ads.length,
                    itemBuilder: (context, index) => AdCard(
                      ad: _ads[index], 
                      index: index, 
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdDetailScreen(ad: _ads[index])))
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStorePage(BuildContext context, StoreModel store, bool isDark, Color textColor) {
    final mutedColor = isDark ? AppTheme.whiteMuted : Colors.grey.shade500;
    
    return Scaffold(
      backgroundColor: isDark ? AppTheme.black : AppTheme.lightBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: isDark ? AppTheme.black : Colors.white,
            leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
            flexibleSpace: FlexibleSpaceBar(
              background: store.banner != null 
                ? Image.network(store.banner!, fit: BoxFit.cover)
                : Container(color: AppTheme.facebookBlue),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (store.logo != null)
                        CircleAvatar(radius: 40, backgroundImage: NetworkImage(store.logo!))
                      else
                        CircleAvatar(
                          radius: 40, 
                          backgroundColor: AppTheme.facebookBlue, 
                          child: Text(
                            store.name.isNotEmpty ? store.name[0].toUpperCase() : 'S', 
                            style: const TextStyle(color: Colors.white, fontSize: 32)
                          )
                        ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(store.name, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: textColor)),
                            Text(store.category, style: GoogleFonts.outfit(color: AppTheme.facebookBlue, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(store.description, style: GoogleFonts.outfit(color: mutedColor, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.orange, size: 20),
                      const SizedBox(width: 4),
                      Text('${store.rating.toStringAsFixed(1)} (${store.totalReviews} avaliações)', style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const Divider(height: 32),
                  Text('Produtos e Serviços', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          _ads.isEmpty 
            ? const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text('Nenhum produto cadastrado.'))))
            : SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, 
                    childAspectRatio: 0.75, 
                    crossAxisSpacing: 12, 
                    mainAxisSpacing: 12
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => AdCard(
                      ad: _ads[index], 
                      index: index, 
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdDetailScreen(ad: _ads[index])))
                    ),
                    childCount: _ads.length,
                  ),
                ),
              ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}