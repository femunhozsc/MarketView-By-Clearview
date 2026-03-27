import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';
import '../models/ad_model.dart';
import '../providers/user_provider.dart';
import '../services/cloudinary_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

class EditAdScreen extends StatefulWidget {
  final AdModel ad;
  const EditAdScreen({super.key, required this.ad});

  @override
  State<EditAdScreen> createState() => _EditAdScreenState();
}

class _EditAdScreenState extends State<EditAdScreen> {
  final _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;

  // Controllers
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _kmCtrl;

  String _selectedCategory = '';
  String _selectedType = '';
  List<File> _newImages = [];
  List<String> _existingImages = [];
  List<String> _existingPublicIds = [];
  List<String> _imagesToDelete = [];

  final _cloudinary = CloudinaryService();
  final _firestore = FirestoreService();

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.ad.title);
    _descCtrl = TextEditingController(text: widget.ad.description);
    _priceCtrl = TextEditingController(text: widget.ad.price.toStringAsFixed(2).replaceAll('.', ','));
    _locationCtrl = TextEditingController(text: widget.ad.location);
    _kmCtrl = TextEditingController(text: widget.ad.km?.toString() ?? '');

    _selectedCategory = widget.ad.category;
    _selectedType = widget.ad.type;
    _existingImages = List.from(widget.ad.images);
    _existingPublicIds = List.from(widget.ad.imagePublicIds);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _locationCtrl.dispose();
    _kmCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 2) {
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
    if (file != null && (_newImages.length + _existingImages.length) < 10) {
      setState(() => _newImages.add(file));
    }
  }

  Future<void> _removeExistingImage(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover foto?'),
        content: const Text('Esta foto será deletada do servidor.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      setState(() {
        _imagesToDelete.add(_existingPublicIds[index]);
        _existingImages.removeAt(index);
        _existingPublicIds.removeAt(index);
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      final user = context.read<UserProvider>().user;
      if (user == null) throw Exception('Você precisa estar logado.');

      // Deleta imagens marcadas para remoção
      if (_imagesToDelete.isNotEmpty) {
        await _cloudinary.deleteImages(_imagesToDelete);
      }

      // Upload de novas imagens
      List<String> newImageUrls = [];
      List<String> newPublicIds = [];
      for (int i = 0; i < _newImages.length; i++) {
        final result = await _cloudinary.uploadAdPhotoFull(user.uid, _newImages[i], i);
        if (result != null) {
          newImageUrls.add(result['url']!);
          newPublicIds.add(result['publicId']!);
        }
      }

      // Combina imagens existentes com novas
      final allImages = [..._existingImages, ...newImageUrls];
      final allPublicIds = [..._existingPublicIds, ...newPublicIds];

      // Detecta mudança de preço
      final newPrice = double.tryParse(_priceCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ?? widget.ad.price;
      final priceChanged = newPrice != widget.ad.price;

      // Atualiza o anúncio
      await _firestore.updateAd(widget.ad.id, {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'price': newPrice,
        'oldPrice': priceChanged ? widget.ad.price : null,
        'category': _selectedCategory,
        'type': _selectedType,
        'images': allImages,
        'imagePublicIds': allPublicIds,
        'location': _locationCtrl.text.trim().isNotEmpty
            ? _locationCtrl.text.trim()
            : (user.address.city.isNotEmpty ? user.address.city : 'Localização não informada'),
        'km': _selectedCategory == 'Veículos' ? int.tryParse(_kmCtrl.text.replaceAll('.', '')) : null,
        'updatedAt': DateTime.now(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('✅ Anúncio atualizado!'), backgroundColor: AppTheme.facebookBlue),
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
        title: Text('Editar Anúncio', style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.w700)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / 3,
            backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.facebookBlue),
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _stepInfo(isDark),
          _stepPhotos(isDark),
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
              onPressed: _isLoading ? null : (_currentStep == 2 ? _submit : _nextStep),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.facebookBlue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(_currentStep == 2 ? 'Salvar Alterações' : 'Continuar',
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ── ETAPA 0: INFORMAÇÕES ────────────────────────────────────
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

  // ── ETAPA 1: FOTOS ──────────────────────────────────────────
  Widget _stepPhotos(bool isDark) {
    final totalImages = _existingImages.length + _newImages.length;
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
            // Imagens existentes
            ..._existingImages.asMap().entries.map((e) => Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(e.value, width: 100, height: 100, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 100,
                        height: 100,
                        color: isDark ? AppTheme.blackLight : Colors.grey.shade200,
                        child: const Icon(Icons.image_not_supported),
                      )),
                ),
                Positioned(
                  top: 4, right: 4,
                  child: GestureDetector(
                    onTap: () => _removeExistingImage(e.key),
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
            // Novas imagens
            ..._newImages.asMap().entries.map((e) => Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(e.value, width: 100, height: 100, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 4, right: 4,
                  child: GestureDetector(
                    onTap: () => setState(() => _newImages.removeAt(e.key)),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            )),
            // Botão adicionar
            if (totalImages < 10)
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

  // ── ETAPA 2: RESUMO ─────────────────────────────────────────
  Widget _stepSummary(bool isDark) {
    final newPrice = double.tryParse(_priceCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ?? widget.ad.price;
    final priceChanged = newPrice != widget.ad.price;
    
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Resumo do anúncio', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 32),
        if (_existingImages.isNotEmpty || _newImages.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _existingImages.isNotEmpty
                ? Image.network(_existingImages[0], height: 200, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 200,
                      color: isDark ? AppTheme.blackLight : Colors.grey.shade200,
                      child: const Icon(Icons.image_not_supported),
                    ))
                : Image.file(_newImages[0], height: 200, width: double.infinity, fit: BoxFit.cover),
          ),
        const SizedBox(height: 24),
        Text(_titleCtrl.text, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 8),
        if (priceChanged)
          Row(
            children: [
              Text(
                _formatPrice(widget.ad.price),
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatPrice(newPrice),
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF4A4A4A),
                ),
              ),
            ],
          )
        else
          Text(
            _formatPrice(newPrice),
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF4A4A4A),
            ),
          ),
        const Divider(height: 40),
        _summaryRow('Categoria', _selectedCategory, isDark),
        _summaryRow('Tipo', _selectedType.toUpperCase(), isDark),
        if (_selectedCategory == 'Veículos') _summaryRow('KM', _kmCtrl.text, isDark),
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

  String _formatPrice(double price) {
    final parts = price.toStringAsFixed(2).split('.');
    final buffer = StringBuffer();
    int count = 0;
    for (int i = parts[0].length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write('.');
      buffer.write(parts[0][i]);
      count++;
    }
    final formatted = buffer.toString().split('').reversed.join('');
    return 'R\$ $formatted,${parts[1]}';
  }
}
