import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../services/cep_service.dart';
import '../services/cloudinary_service.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cloudinary = CloudinaryService();
  final _firestoreService = FirestoreService();
  final _cepService = CepService();
  final _storage = StorageService();

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cepCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  final _complementCtrl = TextEditingController();
  final _neighborhoodCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();

  File? _newPhoto;
  bool _saving = false;
  bool _fetchingCep = false;
  bool _didSeed = false;
  int _searchRadius = 50;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didSeed) return;
    final user = context.read<UserProvider>().user;
    if (user == null) return;

    _firstNameCtrl.text = user.firstName;
    _lastNameCtrl.text = user.lastName;
    _phoneCtrl.text = user.phone;
    _cepCtrl.text = user.address.cep;
    _streetCtrl.text = user.address.street;
    _numberCtrl.text = user.address.number;
    _complementCtrl.text = user.address.complement;
    _neighborhoodCtrl.text = user.address.neighborhood;
    _cityCtrl.text = user.address.city;
    _stateCtrl.text = user.address.state;
    _searchRadius = user.searchRadius.clamp(5, 500);
    _didSeed = true;
  }

  @override
  void dispose() {
    for (final controller in [
      _firstNameCtrl,
      _lastNameCtrl,
      _phoneCtrl,
      _cepCtrl,
      _streetCtrl,
      _numberCtrl,
      _complementCtrl,
      _neighborhoodCtrl,
      _cityCtrl,
      _stateCtrl,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await _cloudinary.pickAndCropImage(
      context: context,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      title: 'Recortar Foto de Perfil',
    );
    if (file != null && mounted) {
      setState(() => _newPhoto = file);
    }
  }

  Future<void> _fetchCep() async {
    final cep = _cepCtrl.text.trim();
    if (cep.replaceAll(RegExp(r'\D'), '').length < 8) return;

    setState(() => _fetchingCep = true);
    final result = await _cepService.fetchAddress(cep);
    if (!mounted) return;

    setState(() => _fetchingCep = false);
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'CEP não encontrado.',
            style: GoogleFonts.roboto(color: Colors.white),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _streetCtrl.text = result.street;
    _neighborhoodCtrl.text = result.neighborhood;
    _cityCtrl.text = result.city;
    _stateCtrl.text = result.state;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final userProvider = context.read<UserProvider>();
    final user = userProvider.user;
    if (user == null) return;

    setState(() => _saving = true);

    try {
      String? photoUrl = user.profilePhoto;
      if (_newPhoto != null) {
        photoUrl = await _cloudinary.uploadProfilePhoto(user.uid, _newPhoto!);
        photoUrl ??= await _storage.uploadProfilePhoto(user.uid, _newPhoto!);
      }

      final newAddress = AddressModel(
        cep: _cepCtrl.text.trim(),
        street: _streetCtrl.text.trim(),
        number: _numberCtrl.text.trim(),
        complement: _complementCtrl.text.trim(),
        neighborhood: _neighborhoodCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        state: _stateCtrl.text.trim(),
        country: 'Brasil',
      );

      await _firestoreService.updateUser(user.uid, {
        'firstName': _firstNameCtrl.text.trim(),
        'lastName': _lastNameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'profilePhoto': photoUrl,
        'address': newAddress.toMap(),
        'searchRadius': _searchRadius,
      });

      await userProvider.refresh();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Perfil atualizado com sucesso!',
            style: GoogleFonts.roboto(color: Colors.white),
          ),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.pop(context);
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
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = isDark ? AppTheme.whiteMuted : Colors.grey.shade600;
    final borderColor = isDark ? AppTheme.blackBorder : const Color(0xFFE8E8E8);
    final user = context.watch<UserProvider>().user;

    if (user == null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: isDark ? AppTheme.black : Colors.white,
          elevation: 0,
          title: Text(
            'Editar perfil',
            style: GoogleFonts.roboto(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: Center(
          child: Text(
            'Não foi possível carregar seu perfil agora.',
            style: GoogleFonts.roboto(color: mutedColor),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.black : Colors.white,
        elevation: 0,
        title: Text(
          'Editar perfil',
          style: GoogleFonts.roboto(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickPhoto,
                child: Stack(
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        color: AppTheme.facebookBlue.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.facebookBlue.withValues(alpha: 0.24),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: _newPhoto != null
                            ? Image.file(_newPhoto!, fit: BoxFit.cover)
                            : (user.profilePhoto != null &&
                                    user.profilePhoto!.trim().isNotEmpty
                                ? Image.network(
                                    user.profilePhoto!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _avatarLetter(user.firstName),
                                  )
                                : _avatarLetter(user.firstName)),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          color: AppTheme.facebookBlue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Alterar foto',
                style: GoogleFonts.roboto(
                  color: AppTheme.facebookBlue,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle('Dados pessoais', mutedColor),
            const SizedBox(height: 10),
            _card(
              cardBg,
              borderColor,
              Column(
                children: [
                  _textField('Nome', _firstNameCtrl, textColor),
                  _divider(borderColor),
                  _textField('Sobrenome', _lastNameCtrl, textColor),
                  _divider(borderColor),
                  _textField(
                    'Telefone / WhatsApp',
                    _phoneCtrl,
                    textColor,
                    keyboardType: TextInputType.phone,
                    requiredField: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _sectionTitle('Endereço', mutedColor),
            const SizedBox(height: 10),
            _card(
              cardBg,
              borderColor,
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cepCtrl,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.roboto(color: textColor),
                            decoration: _inputDecoration('CEP', isDark),
                            onChanged: (value) {
                              if (value.replaceAll(RegExp(r'\D'), '').length ==
                                  8) {
                                _fetchCep();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 46,
                          height: 46,
                          child: FilledButton(
                            onPressed: _fetchingCep ? null : _fetchCep,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.facebookBlue,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _fetchingCep
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.2,
                                    ),
                                  )
                                : const Icon(Icons.search_rounded, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _divider(borderColor),
                  _textField('Rua / Logradouro', _streetCtrl, textColor),
                  _divider(borderColor),
                  _textField(
                    'Número',
                    _numberCtrl,
                    textColor,
                    keyboardType: TextInputType.number,
                  ),
                  _divider(borderColor),
                  _textField(
                    'Complemento',
                    _complementCtrl,
                    textColor,
                    requiredField: false,
                  ),
                  _divider(borderColor),
                  _textField('Bairro', _neighborhoodCtrl, textColor),
                  _divider(borderColor),
                  _textField('Cidade', _cityCtrl, textColor),
                  _divider(borderColor),
                  _textField(
                    'UF',
                    _stateCtrl,
                    textColor,
                    maxLength: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _sectionTitle('Raio de busca: ${_searchRadius}km', mutedColor),
            const SizedBox(height: 6),
            Text(
              'Anúncios dentro desse raio aparecerão para você.',
              style: GoogleFonts.roboto(
                color: mutedColor,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 8),
            _card(
              cardBg,
              borderColor,
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppTheme.facebookBlue,
                    thumbColor: AppTheme.facebookBlue,
                    inactiveTrackColor:
                        AppTheme.facebookBlue.withValues(alpha: 0.20),
                    overlayColor: AppTheme.facebookBlue.withValues(alpha: 0.10),
                  ),
                  child: Slider(
                    value: _searchRadius.toDouble(),
                    min: 5,
                    max: 500,
                    divisions: 99,
                    label: '${_searchRadius}km',
                    onChanged: (value) =>
                        setState(() => _searchRadius = value.round()),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.facebookBlue,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.4,
                      ),
                    )
                  : Text(
                      'Salvar alterações',
                      style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(Color cardBg, Color borderColor, Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }

  Widget _divider(Color borderColor) {
    return Divider(height: 1, color: borderColor, indent: 14, endIndent: 14);
  }

  Widget _avatarLetter(String firstName) {
    return Center(
      child: Text(
        firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
        style: GoogleFonts.roboto(
          color: AppTheme.facebookBlue,
          fontSize: 32,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, Color color) {
    return Text(
      title,
      style: GoogleFonts.roboto(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _textField(
    String label,
    TextEditingController controller,
    Color textColor, {
    TextInputType keyboardType = TextInputType.text,
    bool requiredField = true,
    int? maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLength: maxLength,
        style: GoogleFonts.roboto(color: textColor, fontSize: 14.5),
        validator: requiredField
            ? (value) => value == null || value.trim().isEmpty
                ? 'Campo obrigatório'
                : null
            : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.roboto(color: Colors.grey, fontSize: 13),
          counterText: '',
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.roboto(color: Colors.grey, fontSize: 14),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      isDense: true,
    );
  }
}
