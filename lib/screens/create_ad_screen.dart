import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_cropper/image_cropper.dart';
import '../providers/user_provider.dart';
import 'dart:io';
import '../models/ad_model.dart';
import '../services/cloudinary_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

class CreateAdScreen extends StatefulWidget {
  const CreateAdScreen({super.key});

  @override
  State<CreateAdScreen> createState() => _CreateAdScreenState();
}

class _CreateAdScreenState extends State<CreateAdScreen> {
  final _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;

  // Controllers
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _kmCtrl = TextEditingController();

  String _selectedType = 'produto';
  String _selectedCategory = 'Eletrônicos';
  String _selectedAccount = 'personal'; // 'personal' ou 'store'
  List<File> _images = [];

  final _cloudinary = CloudinaryService();
  final _firestore = FirestoreService();

  @override
  void initState() {
    super.initState();
    _priceCtrl.addListener(_formatPriceInput);
  }

  void _formatPriceInput() {
    String text = _priceCtrl.text;
    if (text.isEmpty) return;
    String numOnly = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (numOnly.isEmpty) {
      _priceCtrl.text = '';
      return;
    }
    int value = int.parse(numOnly);
    double doubleValue = value / 100;
    String formatted = doubleValue.toStringAsFixed(2);
    List<String> parts = formatted.split('.');
    String intPart = parts[0];
    String decPart = parts[1];
    StringBuffer buffer = StringBuffer();
    int count = 0;
    for (int i = intPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write('.');
      buffer.write(intPart[i]);
      count++;
    }
    String formattedInt = buffer.toString().split('').reversed.join('');
    String result = '$formattedInt,$decPart';
    if (_priceCtrl.text != result) {
      _priceCtrl.value = TextEditingValue(
        text: result,
        selection: TextSelection.fromPosition(TextPosition(offset: result.length)),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.removeListener(_formatPriceInput);
    _priceCtrl.dispose();
    _locationCtrl.dispose();
    _kmCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 5) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep--);
    }
  }

  Future<void> _pickImage() async {
    final file = await _cloudinary.pickAndCropImage(
      context: context,
      aspectRatio: const CropAspectRatio(ratioX: 4, ratioY: 3),
      title: 'Recortar Foto do Anúncio',
    );
    if (file != null && _images.length < 10) {
      setState(() => _images.add(file));
    }
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      final userProvider = context.read<UserProvider>();
      final user = userProvider.user;
      
      if (user == null) {
        throw Exception('Você precisa estar logado para criar um anúncio.');
      }
      
      final userId = user.uid;
      
      String sellerName = user.fullName;
      String? storeName;
      String? storeLogo;

      if (_selectedAccount == 'store' && user.storeId != null) {
        final store = await _firestore.getStore(user.storeId!);
        if (store != null) {
          sellerName = store.name;
          storeName = store.name;
          storeLogo = store.logo;
        }
      }

      List<String> imageUrls = [];
      List<String> imagePublicIds = [];
      for (int i = 0; i < _images.length; i++) {
        final result = await _cloudinary.uploadAdPhotoFull(userId, _images[i], i);
        if (result != null) {
          imageUrls.add(result['url']!);
          imagePublicIds.add(result['publicId']!);
        }
      }

      final ad = AdModel(
        id: '',
        sellerId: userId,
        storeId: _selectedAccount == 'store' ? user.storeId : null,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        price: double.tryParse(_priceCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0.0,
        category: _selectedCategory,
        type: _selectedType,
        images: imageUrls,
        imagePublicIds: imagePublicIds,
        location: _locationCtrl.text.trim().isNotEmpty 
            ? _locationCtrl.text.trim() 
            : (user.address.city.isNotEmpty ? user.address.city : 'Localização não informada'),
        sellerName: sellerName,
        sellerAvatar: user.profilePhoto ?? '',
        storeName: storeName,
        storeLogo: storeLogo,
        createdAt: DateTime.now(),
        km: _selectedCategory == 'Veículos' ? int.tryParse(_kmCtrl.text.replaceAll('.', '')) : null,
      );

      await _firestore.createAd(ad);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('✅ Anúncio publicado!'), backgroundColor: AppTheme.facebookBlue),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Novo Anúncio', style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.w700)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / 6,
            backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.facebookBlue),
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _stepAccount(isDark),
          _stepType(isDark),
          _stepInfo(isDark),
          _stepPhotos(isDark),
          _stepLocation(isDark),
          _stepSummary(isDark),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(isDark),
    );
  }

  Widget _buildBottomBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.blackCard : Colors.white,
        border: Border(top: BorderSide(color: isDark ? AppTheme.blackBorder : Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading ? null : _prevStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppTheme.facebookBlue),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Voltar', style: GoogleFonts.outfit(color: AppTheme.facebookBlue, fontWeight: FontWeight.w600)),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading ? null : (_currentStep == 5 ? _submit : _nextStep),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.facebookBlue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(_currentStep == 5 ? 'Publicar Anúncio' : 'Continuar', 
                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ── ETAPA 0: CONTA ─────────────────────────────────────────
  Widget _stepAccount(bool isDark) {
    final user = context.watch<UserProvider>().user;
    final hasStore = user?.hasStore ?? false;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Onde deseja anunciar?', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 8),
        Text('Escolha se este anúncio pertence ao seu perfil pessoal ou à sua loja.', style: GoogleFonts.outfit(color: Colors.grey)),
        const SizedBox(height: 32),
        _accountOption('personal', 'Perfil Pessoal', 'Anuncie como ${user?.fullName ?? 'Usuário'}', Icons.person_outline_rounded, isDark, true),
        const SizedBox(height: 16),
        _accountOption('store', 'Minha Loja', hasStore ? 'Anuncie em nome da sua loja' : 'Você precisa criar uma loja primeiro', Icons.store_outlined, isDark, hasStore),
      ],
    );
  }

  Widget _accountOption(String value, String title, String sub, IconData icon, bool isDark, bool enabled) {
    final isSelected = _selectedAccount == value;
    return GestureDetector(
      onTap: enabled ? () => setState(() => _selectedAccount = value) : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.facebookBlue.withOpacity(0.1) : (isDark ? AppTheme.blackLight : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? AppTheme.facebookBlue : (isDark ? AppTheme.blackBorder : Colors.grey.shade200), width: 2),
          ),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? AppTheme.facebookBlue : Colors.grey, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: isSelected ? AppTheme.facebookBlue : (isDark ? Colors.white : Colors.black87))),
                    Text(sub, style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey)),
                  ],
                ),
              ),
              if (isSelected) const Icon(Icons.check_circle_rounded, color: AppTheme.facebookBlue),
            ],
          ),
        ),
      ),
    );
  }

  // ── ETAPA 1: TIPO ──────────────────────────────────────────
  Widget _stepType(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('O que você quer anunciar?', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 8),
        Text('Escolha a categoria que melhor define seu anúncio.', style: GoogleFonts.outfit(color: Colors.grey)),
        const SizedBox(height: 32),
        _typeOption('produto', 'Produto', 'Venda itens físicos novos ou usados', Icons.inventory_2_outlined, isDark),
        const SizedBox(height: 16),
        _typeOption('servico', 'Serviço', 'Ofereça suas habilidades e trabalhos', Icons.handyman_outlined, isDark),
      ],
    );
  }

  Widget _typeOption(String value, String title, String sub, IconData icon, bool isDark) {
    final isSelected = _selectedType == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.facebookBlue.withOpacity(0.1) : (isDark ? AppTheme.blackLight : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppTheme.facebookBlue : (isDark ? AppTheme.blackBorder : Colors.grey.shade200), width: 2),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppTheme.facebookBlue : Colors.grey, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: isSelected ? AppTheme.facebookBlue : (isDark ? Colors.white : Colors.black87))),
                  Text(sub, style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey)),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle_rounded, color: AppTheme.facebookBlue),
          ],
        ),
      ),
    );
  }

  // ── ETAPA 2: INFORMAÇÕES ────────────────────────────────────
  Widget _stepInfo(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Detalhes do anúncio', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 32),
        _field(_titleCtrl, 'Título', 'Ex: iPhone 14 Pro Max', isDark),
        const SizedBox(height: 20),
        _field(_descCtrl, 'Descrição', 'Conte mais sobre o que está anunciando...', isDark, maxLines: 4),
        const SizedBox(height: 20),
        _field(_priceCtrl, 'Preço (R\$)', '0,00', isDark, keyboardType: TextInputType.number),
        const SizedBox(height: 20),
        Text('Categoria', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black54)),
        const SizedBox(height: 8),
        _categoryDropdown(isDark),
        if (_selectedCategory == 'Veículos') ...[
          const SizedBox(height: 20),
          _field(_kmCtrl, 'Quilometragem (KM)', 'Ex: 50.000', isDark, keyboardType: TextInputType.number),
        ],
      ],
    );
  }

  // ── ETAPA 3: FOTOS ──────────────────────────────────────────
  Widget _stepPhotos(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Fotos do anúncio', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 8),
        Text('Adicione até 10 fotos. A primeira será a principal.', style: GoogleFonts.outfit(color: Colors.grey)),
        const SizedBox(height: 32),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ..._images.asMap().entries.map((e) => Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(e.value, width: 100, height: 100, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 4, right: 4,
                  child: GestureDetector(
                    onTap: () => setState(() => _images.removeAt(e.key)),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ),
                if (e.key == 0)
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      decoration: const BoxDecoration(color: AppTheme.facebookBlue, borderRadius: BorderRadius.vertical(bottom: Radius.circular(12))),
                      child: Text('Principal', textAlign: TextAlign.center, style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],
            )),
            if (_images.length < 10)
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.blackLight : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? AppTheme.blackBorder : Colors.grey.shade300, style: BorderStyle.solid),
                  ),
                  child: const Icon(Icons.add_a_photo_outlined, color: AppTheme.facebookBlue, size: 32),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ── ETAPA 4: LOCALIZAÇÃO ────────────────────────────────────
  Widget _stepLocation(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Onde você está?', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 32),
        _field(_locationCtrl, 'Cidade / Estado', 'Ex: Curitiba, PR', isDark),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppTheme.facebookBlue.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: AppTheme.facebookBlue),
              const SizedBox(width: 12),
              Expanded(child: Text('Se deixar em branco, usaremos a localização do seu perfil.', style: GoogleFonts.outfit(color: AppTheme.facebookBlue, fontSize: 13))),
            ],
          ),
        ),
      ],
    );
  }

  // ── ETAPA 5: RESUMO ─────────────────────────────────────────
  Widget _stepSummary(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Resumo do anúncio', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 32),
        if (_images.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(_images[0], height: 200, width: double.infinity, fit: BoxFit.cover),
          ),
        const SizedBox(height: 24),
        Text(_titleCtrl.text, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
        Text(_formatPriceDisplay(_priceCtrl.text), style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF4A4A4A))),
        const Divider(height: 40),
        _summaryRow('Categoria', _selectedCategory, isDark),
        _summaryRow('Tipo', _selectedType.toUpperCase(), isDark),
        if (_selectedCategory == 'Veículos') _summaryRow('KM', _kmCtrl.text, isDark),
        _summaryRow('Localização', _locationCtrl.text.isEmpty ? 'Perfil' : _locationCtrl.text, isDark),
      ],
    );
  }

  Widget _summaryRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.outfit(color: Colors.grey)),
          Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        ],
      ),
    );
  }

  // ── WIDGETS AUXILIARES ──────────────────────────────────────
  Widget _field(TextEditingController ctrl, String label, String hint, bool isDark, {int maxLines = 1, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black54)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400),
            filled: true,
            fillColor: isDark ? AppTheme.blackLight : Colors.grey.shade100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _categoryDropdown(bool isDark) {
    final categories = ['Eletrônicos', 'Veículos', 'Imóveis', 'Móveis', 'Roupas', 'Esportes', 'Design', 'Educação', 'Saúde', 'Beleza', 'Animais', 'Outros'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: isDark ? AppTheme.blackLight : Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          isExpanded: true,
          dropdownColor: isDark ? AppTheme.blackCard : Colors.white,
          style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black87),
          items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => setState(() => _selectedCategory = v!),
        ),
      ),
    );
  }

  String _formatPriceDisplay(String text) {
    if (text.isEmpty) return 'R\$ 0,00';
    double price = double.tryParse(text.replaceAll('.', '').replaceAll(',', '.')) ?? 0.0;
    final parts = price.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    final buffer = StringBuffer();
    int count = 0;
    for (int i = intPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write('.');
      buffer.write(intPart[i]);
      count++;
    }
    final formatted = buffer.toString().split('').reversed.join('');
    return 'R\$ $formatted,$decPart';
  }
}
