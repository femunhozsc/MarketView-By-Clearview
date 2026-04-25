import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:provider/provider.dart';

import '../models/store_model.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../services/cloudinary_service.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'create_store_screen.dart';

class EditStoreScreen extends StatefulWidget {
  const EditStoreScreen({
    super.key,
    required this.store,
    required this.currentUserId,
  });

  final StoreModel store;
  final String currentUserId;

  @override
  State<EditStoreScreen> createState() => _EditStoreScreenState();
}

class _EditStoreScreenState extends State<EditStoreScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirestoreService();
  final _cloudinary = CloudinaryService();
  final _storage = StorageService();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _ownerNameCtrl;
  late final TextEditingController _ownerDocumentCtrl;
  late final TextEditingController _cepCtrl;
  late final TextEditingController _streetCtrl;
  late final TextEditingController _numberCtrl;
  late final TextEditingController _complementCtrl;
  late final TextEditingController _neighborhoodCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _stateCtrl;

  late String _category;
  late String _type;
  late bool _hasDelivery;
  late bool _hasInstallments;
  File? _newLogoFile;
  File? _newBannerFile;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final store = widget.store;
    _nameCtrl = TextEditingController(text: store.name);
    _descriptionCtrl = TextEditingController(text: store.description);
    _ownerNameCtrl = TextEditingController(text: store.ownerName);
    _ownerDocumentCtrl = TextEditingController(text: store.ownerDocument);
    _cepCtrl = TextEditingController(text: store.address.cep);
    _streetCtrl = TextEditingController(text: store.address.street);
    _numberCtrl = TextEditingController(text: store.address.number);
    _complementCtrl = TextEditingController(text: store.address.complement);
    _neighborhoodCtrl = TextEditingController(text: store.address.neighborhood);
    _cityCtrl = TextEditingController(text: store.address.city);
    _stateCtrl = TextEditingController(text: store.address.state);
    _category = store.category;
    _type = store.type;
    _hasDelivery = store.hasDelivery;
    _hasInstallments = store.hasInstallments;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _ownerNameCtrl.dispose();
    _ownerDocumentCtrl.dispose();
    _cepCtrl.dispose();
    _streetCtrl.dispose();
    _numberCtrl.dispose();
    _complementCtrl.dispose();
    _neighborhoodCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final file = await _cloudinary.pickAndCropImage(
      context: context,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      title: 'Recortar logo da loja',
    );
    if (!mounted || file == null) return;
    setState(() => _newLogoFile = file);
  }

  Future<void> _pickBanner() async {
    final file = await _cloudinary.pickAndCropImage(
      context: context,
      aspectRatio: const CropAspectRatio(ratioX: 3, ratioY: 1),
      title: 'Recortar banner da loja',
    );
    if (!mounted || file == null) return;
    setState(() => _newBannerFile = file);
  }

  Future<String?> _uploadStoreImage({
    required File? file,
    required bool isLogo,
  }) async {
    if (file == null) return null;

    final cloudinaryUrl = isLogo
        ? await _cloudinary.uploadStoreLogo(widget.store.id, file)
        : await _cloudinary.uploadStoreBanner(widget.store.id, file);
    if (cloudinaryUrl != null && cloudinaryUrl.trim().isNotEmpty) {
      return cloudinaryUrl;
    }

    final firebaseUrl = isLogo
        ? await _storage.uploadStoreLogo(widget.store.id, file)
        : await _storage.uploadStoreBanner(widget.store.id, file);
    if (firebaseUrl != null && firebaseUrl.trim().isNotEmpty) {
      return firebaseUrl;
    }

    throw Exception(
      isLogo
          ? 'Nao foi possivel enviar a logomarca.'
          : 'Nao foi possivel enviar o banner.',
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final logoUrl = await _uploadStoreImage(file: _newLogoFile, isLogo: true);
      final bannerUrl =
          await _uploadStoreImage(file: _newBannerFile, isLogo: false);
      final updates = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'category': _category,
        'type': _type,
        'hasDelivery': _hasDelivery,
        'hasInstallments': _hasInstallments,
        'description': _descriptionCtrl.text.trim(),
        'ownerName': _ownerNameCtrl.text.trim(),
        'ownerDocument': _ownerDocumentCtrl.text.trim(),
        'address': AddressModel(
          cep: _cepCtrl.text.trim(),
          street: _streetCtrl.text.trim(),
          number: _numberCtrl.text.trim(),
          complement: _complementCtrl.text.trim(),
          neighborhood: _neighborhoodCtrl.text.trim(),
          city: _cityCtrl.text.trim(),
          state: _stateCtrl.text.trim(),
          lat: widget.store.address.lat,
          lng: widget.store.address.lng,
        ).toMap(),
      };

      if (logoUrl != null && logoUrl.isNotEmpty) {
        updates['logo'] = logoUrl;
      }
      if (bannerUrl != null && bannerUrl.isNotEmpty) {
        updates['banner'] = bannerUrl;
      }

      final refreshedStore = await _firestore.updateStoreProfile(
        storeId: widget.store.id,
        data: updates,
      );

      if (!mounted) return;
      context.read<UserProvider>().notifyMarketplaceChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loja atualizada com sucesso!'),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.pop(context, refreshedStore);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      final message = e.code == 'permission-denied'
          ? 'O Firestore bloqueou a atualizacao da loja.'
          : 'Erro do Firestore ao salvar a loja: ${e.message ?? e.code}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar a loja: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deleteStore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir loja'),
        content: const Text(
          'Tem certeza? Todos os anúncios, imagens e dados da loja serão removidos permanentemente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await _firestore.deleteStore(
        storeId: widget.store.id,
        actingUserId: widget.currentUserId,
      );
      if (!mounted) return;
      final userProvider = context.read<UserProvider>();
      await userProvider.refresh();
      if (!mounted) return;
      userProvider.notifyMarketplaceChanged();
      Navigator.pop(context, 'deleted');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir a loja: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.black : AppTheme.lightBg;
    final cardBg = isDark ? AppTheme.blackCard : Colors.white;
    final border = isDark ? AppTheme.blackBorder : const Color(0xFFE8E8E8);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? AppTheme.whiteMuted : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.black : Colors.white,
        elevation: 0,
        title: Text(
          'Editar loja',
          style: GoogleFonts.roboto(
            color: textColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Salvar'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _card(
              cardBg: cardBg,
              border: border,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Visual da loja',
                    style: GoogleFonts.roboto(
                      color: textColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: _pickBanner,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 140,
                        width: double.infinity,
                        child: _buildBannerPreview(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _pickLogo,
                        child: CircleAvatar(
                          radius: 34,
                          backgroundColor:
                              AppTheme.facebookBlue.withValues(alpha: 0.10),
                          backgroundImage: _newLogoFile != null
                              ? FileImage(_newLogoFile!)
                              : ((widget.store.logo?.trim().isNotEmpty ?? false)
                                  ? NetworkImage(widget.store.logo!)
                                  : null) as ImageProvider<Object>?,
                          child: _newLogoFile == null &&
                                  !(widget.store.logo?.trim().isNotEmpty ??
                                      false)
                              ? Text(
                                  widget.store.name.isNotEmpty
                                      ? widget.store.name[0].toUpperCase()
                                      : 'L',
                                  style: GoogleFonts.roboto(
                                    color: AppTheme.facebookBlue,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 24,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Toque no banner ou na logo para abrir a galeria e ajustar o corte antes de salvar.',
                          style: GoogleFonts.roboto(
                            color: subColor,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _card(
              cardBg: cardBg,
              border: border,
              child: Column(
                children: [
                  _field(_nameCtrl, 'Nome da loja', validator: _required),
                  const SizedBox(height: 14),
                  _dropdownField(
                    label: 'Categoria',
                    value: _category,
                    items: storeCategories,
                    onChanged: (value) => setState(() => _category = value!),
                  ),
                  const SizedBox(height: 14),
                  _dropdownField(
                    label: 'Tipo de loja',
                    value: _type,
                    items: const ['produto', 'servico', 'ambos'],
                    onChanged: (value) => setState(() => _type = value!),
                    labelBuilder: (value) => switch (value) {
                      'servico' => 'Serviços',
                      'ambos' => 'Produtos e serviços',
                      _ => 'Produtos',
                    },
                  ),
                  const SizedBox(height: 14),
                  _settingsToggleTile(
                    label: 'Oferece entrega',
                    value: _hasDelivery,
                    onChanged: (value) => setState(() => _hasDelivery = value),
                  ),
                  const SizedBox(height: 10),
                  _settingsToggleTile(
                    label: 'Aceita parcelamento',
                    value: _hasInstallments,
                    onChanged: (value) =>
                        setState(() => _hasInstallments = value),
                  ),
                  const SizedBox(height: 14),
                  _field(
                    _descriptionCtrl,
                    'Descrição',
                    maxLines: 4,
                    validator: _required,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _card(
              cardBg: cardBg,
              border: border,
              child: Column(
                children: [
                  _field(_ownerNameCtrl, 'Responsável', validator: _required),
                  const SizedBox(height: 14),
                  _field(
                    _ownerDocumentCtrl,
                    'CPF/CNPJ do responsável',
                    validator: _required,
                  ),
                  const SizedBox(height: 14),
                  _field(_cepCtrl, 'CEP'),
                  const SizedBox(height: 14),
                  _field(_streetCtrl, 'Rua'),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _field(_numberCtrl, 'Número')),
                      const SizedBox(width: 12),
                      Expanded(child: _field(_complementCtrl, 'Complemento')),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _field(_neighborhoodCtrl, 'Bairro'),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _field(_cityCtrl, 'Cidade')),
                      const SizedBox(width: 12),
                      Expanded(child: _field(_stateCtrl, 'Estado')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (widget.currentUserId == widget.store.ownerId)
              FilledButton(
                onPressed: _saving ? null : _deleteStore,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(
                  'Excluir loja',
                  style: GoogleFonts.roboto(fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerPreview() {
    if (_newBannerFile != null) {
      return Image.file(_newBannerFile!, fit: BoxFit.cover);
    }
    if (widget.store.banner?.trim().isNotEmpty ?? false) {
      return Image.network(
        widget.store.banner!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _bannerFallback(),
      );
    }
    return _bannerFallback();
  }

  Widget _bannerFallback() {
    return Container(
      color: const Color(0xFFEFF6FF),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        color: AppTheme.facebookBlue,
        size: 42,
      ),
    );
  }

  Widget _card({
    required Color cardBg,
    required Color border,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      style: GoogleFonts.roboto(
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.roboto(),
        filled: true,
        fillColor: isDark ? AppTheme.blackLight : const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _dropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String Function(String value)? labelBuilder,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DropdownButtonFormField<String>(
      initialValue: value,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: isDark ? AppTheme.blackLight : const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(labelBuilder?.call(item) ?? item),
            ),
          )
          .toList(),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obrigatório';
    }
    return null;
  }

  Widget _settingsToggleTile({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.blackLight : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.roboto(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.facebookBlue,
          ),
        ],
      ),
    );
  }
}
