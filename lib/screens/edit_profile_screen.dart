import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_cropper/image_cropper.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../services/cloudinary_service.dart';
import '../services/firestore_service.dart';
import '../services/cep_service.dart';
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

  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _cepCtrl;
  late TextEditingController _streetCtrl;
  late TextEditingController _numberCtrl;
  late TextEditingController _complementCtrl;
  late TextEditingController _neighborhoodCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _stateCtrl;

  File? _newPhoto;
  bool _saving = false;
  bool _fetchingCep = false;
  int _searchRadius = 50;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>().user!;
    _firstNameCtrl = TextEditingController(text: user.firstName);
    _lastNameCtrl = TextEditingController(text: user.lastName);
    _phoneCtrl = TextEditingController(text: user.phone);
    _cepCtrl = TextEditingController(text: user.address.cep);
    _streetCtrl = TextEditingController(text: user.address.street);
    _numberCtrl = TextEditingController(text: user.address.number);
    _complementCtrl = TextEditingController(text: user.address.complement);
    _neighborhoodCtrl = TextEditingController(text: user.address.neighborhood);
    _cityCtrl = TextEditingController(text: user.address.city);
    _stateCtrl = TextEditingController(text: user.address.state);
    _searchRadius = user.searchRadius;
  }

  @override
  void dispose() {
    for (final c in [
      _firstNameCtrl, _lastNameCtrl, _phoneCtrl, _cepCtrl,
      _streetCtrl, _numberCtrl, _complementCtrl, _neighborhoodCtrl,
      _cityCtrl, _stateCtrl,
    ]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await _cloudinary.pickAndCropImage(
      context: context,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      title: 'Recortar Foto de Perfil',
    );
    if (file != null) setState(() => _newPhoto = file);
  }

  Future<void> _fetchCep() async {
    final cep = _cepCtrl.text.trim();
    if (cep.length < 8) return;
    setState(() => _fetchingCep = true);
    final result = await _cepService.fetchAddress(cep);
    setState(() => _fetchingCep = false);
    if (result != null) {
      _streetCtrl.text = result.street;
      _neighborhoodCtrl.text = result.neighborhood;
      _cityCtrl.text = result.city;
      _stateCtrl.text = result.state;
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CEP não encontrado', style: GoogleFonts.outfit(color: Colors.white)),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final userProvider = context.read<UserProvider>();
    final user = userProvider.user!;
    setState(() => _saving = true);

    String? photoUrl = user.profilePhoto;
    if (_newPhoto != null) {
      photoUrl = await _cloudinary.uploadProfilePhoto(user.uid, _newPhoto!);
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
    setState(() => _saving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Perfil atualizado com sucesso!',
              style: GoogleFonts.outfit(color: Colors.white)),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.black : AppTheme.lightBg;
    final cardBg = isDark ? AppTheme.blackCard : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final user = context.watch<UserProvider>().user!;

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
          'Editar perfil',
          style: GoogleFonts.outfit(color: textColor, fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Foto de perfil
              Center(
                child: GestureDetector(
                  onTap: _pickPhoto,
                  child: Stack(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: AppTheme.facebookBlue.withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.facebookBlue.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: _newPhoto != null
                              ? Image.file(_newPhoto!, fit: BoxFit.cover)
                              : (user.profilePhoto != null
                                  ? Image.network(user.profilePhoto!, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _avatarLetter(user.firstName))
                                  : _avatarLetter(user.firstName)),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: AppTheme.facebookBlue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text('Alterar foto', style: GoogleFonts.outfit(
                  color: AppTheme.facebookBlue, fontSize: 13, fontWeight: FontWeight.w600)),
              ),

              const SizedBox(height: 28),
              _sectionTitle('Dados pessoais', isDark),
              const SizedBox(height: 12),

              _buildCard(
                isDark: isDark,
                cardBg: cardBg,
                child: Column(
                  children: [
                    _field('Nome', _firstNameCtrl, isDark,
                        validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null),
                    _divider(isDark),
                    _field('Sobrenome', _lastNameCtrl, isDark,
                        validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null),
                    _divider(isDark),
                    _field('Telefone / WhatsApp', _phoneCtrl, isDark,
                        keyboard: TextInputType.phone),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              _sectionTitle('Endereço', isDark),
              const SizedBox(height: 12),

              _buildCard(
                isDark: isDark,
                cardBg: cardBg,
                child: Column(
                  children: [
                    // CEP com busca automática
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _cepCtrl,
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black87),
                              decoration: _inputDec('CEP', isDark),
                              onChanged: (v) {
                                if (v.replaceAll(RegExp(r'\D'), '').length == 8) _fetchCep();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _fetchCep,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.facebookBlue,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: _fetchingCep
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.search_rounded,
                                      color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _divider(isDark),
                    _field('Rua / Logradouro', _streetCtrl, isDark),
                    _divider(isDark),
                    Row(
                      children: [
                        Expanded(flex: 2, child: _field('Número', _numberCtrl, isDark, keyboard: TextInputType.number)),
                        Container(width: 1, height: 48, color: isDark ? AppTheme.blackBorder : const Color(0xFFE8E8E8)),
                        Expanded(flex: 3, child: _field('Complemento', _complementCtrl, isDark, required: false)),
                      ],
                    ),
                    _divider(isDark),
                    _field('Bairro', _neighborhoodCtrl, isDark),
                    _divider(isDark),
                    Row(
                      children: [
                        Expanded(flex: 3, child: _field('Cidade', _cityCtrl, isDark)),
                        Container(width: 1, height: 48, color: isDark ? AppTheme.blackBorder : const Color(0xFFE8E8E8)),
                        Expanded(flex: 1, child: _field('UF', _stateCtrl, isDark, maxLength: 2)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              _sectionTitle('Raio de busca: ${_searchRadius}km', isDark),
              const SizedBox(height: 4),
              Text(
                'Anúncios dentro desse raio aparecerão para você',
                style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 8),
              _buildCard(
                isDark: isDark,
                cardBg: cardBg,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppTheme.facebookBlue,
                      thumbColor: AppTheme.facebookBlue,
                      inactiveTrackColor: AppTheme.facebookBlue.withOpacity(0.2),
                      overlayColor: AppTheme.facebookBlue.withOpacity(0.1),
                    ),
                    child: Slider(
                      value: _searchRadius.toDouble(),
                      min: 5,
                      max: 500,
                      divisions: 99,
                      label: '${_searchRadius}km',
                      onChanged: (v) => setState(() => _searchRadius = v.round()),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Botão salvar
              GestureDetector(
                onTap: _saving ? null : _save,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.facebookBlue,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.facebookBlue.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _saving
                      ? const Center(
                          child: SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          ),
                        )
                      : Text(
                          'Salvar alterações',
                          style: GoogleFonts.outfit(
                            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                        ),
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarLetter(String firstName) {
    return Center(
      child: Text(
        firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
        style: GoogleFonts.outfit(
          color: AppTheme.facebookBlue, fontSize: 32, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _sectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        color: isDark ? AppTheme.whiteSecondary : Colors.grey.shade600,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildCard({required bool isDark, required Color cardBg, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.blackBorder : const Color(0xFFE8E8E8),
        ),
      ),
      child: child,
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl,
    bool isDark, {
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
    bool required = true,
    int? maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              color: isDark ? AppTheme.whiteMuted : Colors.grey.shade500,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: ctrl,
            keyboardType: keyboard,
            maxLength: maxLength,
            style: GoogleFonts.outfit(
              color: isDark ? Colors.white : Colors.black87, fontSize: 14),
            validator: validator ?? (required ? (v) => v!.isEmpty ? 'Campo obrigatório' : null : null),
            decoration: InputDecoration(
              hintText: label,
              hintStyle: GoogleFonts.outfit(color: Colors.grey, fontSize: 14),
              border: InputBorder.none,
              isDense: true,
              counterText: '',
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(bool isDark) {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: isDark ? AppTheme.blackBorder : const Color(0xFFE8E8E8),
    );
  }

  InputDecoration _inputDec(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.outfit(color: Colors.grey, fontSize: 14),
      filled: true,
      fillColor: isDark ? AppTheme.blackLight : const Color(0xFFF5F5F5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.facebookBlue, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      isDense: true,
    );
  }
}