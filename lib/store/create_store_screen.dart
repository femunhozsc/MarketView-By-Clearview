import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_cropper/image_cropper.dart';
import '../providers/user_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../models/store_model.dart';
import '../models/user_model.dart';
import '../services/cep_service.dart';
import '../services/cloudinary_service.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

const List<String> storeCategories = [
  'Eletrônicos',
  'Veículos',
  'Imóveis',
  'Móveis',
  'Roupas',
  'Esportes',
  'Design',
  'Educação',
  'Saúde',
  'Beleza',
  'Animais',
  'Alimentação',
  'Serviços Gerais',
  'Outros',
];

class CreateStoreScreen extends StatefulWidget {
  final String userId;
  const CreateStoreScreen({super.key, required this.userId});

  @override
  State<CreateStoreScreen> createState() => _CreateStoreScreenState();
}

class _CreateStoreScreenState extends State<CreateStoreScreen> {
  final _pageCtrl = PageController();
  int _currentPage = 0;
  bool _isLoading = false;

  // Dados
  String _storeName = '';
  String _storeCategory = storeCategories[0];
  String _storeType = 'produto';
  bool _hasDelivery = false;
  bool _hasInstallments = false;
  File? _logoFile;
  File? _bannerFile;
  String _description = '';
  String _ownerDocument = '';
  String _ownerName = '';
  AddressModel _address = AddressModel();
  double _mapLat = -15.7801;
  double _mapLng = -47.9292;

  final _cepService = CepService();
  final _firestoreService = FirestoreService();
  final _cloudinary = CloudinaryService();
  final _storage = StorageService();
  final _mapController = MapController();
  final _cepMask = MaskTextInputFormatter(mask: '#####-###');
  final _docMask = MaskTextInputFormatter(
    mask: '###.###.###-###', // Máscara flexível para CPF/CNPJ
    filter: {"#": RegExp(r'[0-9]')},
  );

  void _nextPage() {
    if (_currentPage < 3) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
      setState(() => _currentPage++);
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
      setState(() => _currentPage--);
    }
  }

  Future<void> _fetchCep(String cep) async {
    if (cep.replaceAll(RegExp(r'\D'), '').length != 8) return;
    setState(() => _isLoading = true);
    final result = await _cepService.fetchAddress(cep);
    if (result != null) {
      setState(() {
        _address = _address.copyWith(
          cep: result.cep,
          street: result.street,
          neighborhood: result.neighborhood,
          city: result.city,
          state: result.state,
        );
      });
      final coords = await _cepService.geocode(
          '${result.street}, ${result.neighborhood}, ${result.city}, ${result.state}, Brasil');
      if (coords != null) {
        setState(() {
          _mapLat = coords.lat;
          _mapLng = coords.lng;
        });
        _mapController.move(LatLng(coords.lat, coords.lng), 14);
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _finishStore() async {
    setState(() => _isLoading = true);
    try {
      // Cria documento da loja
      final tempId = DateTime.now().millisecondsSinceEpoch.toString();
      final store = StoreModel(
        id: tempId,
        ownerId: widget.userId,
        ownerName: _ownerName,
        ownerDocument: _ownerDocument,
        name: _storeName,
        category: _storeCategory,
        type: _storeType,
        hasDelivery: _hasDelivery,
        hasInstallments: _hasInstallments,
        description: _description,
        address: _address,
        createdAt: DateTime.now(),
      );

      final storeId = await _firestoreService.createStore(store);

      final logoUrl = await _uploadStoreImage(
        storeId: storeId,
        file: _logoFile,
        kind: _StoreImageKind.logo,
      );
      final bannerUrl = await _uploadStoreImage(
        storeId: storeId,
        file: _bannerFile,
        kind: _StoreImageKind.banner,
      );

      final updates = <String, dynamic>{};
      if (logoUrl != null && logoUrl.isNotEmpty) updates['logo'] = logoUrl;
      if (bannerUrl != null && bannerUrl.isNotEmpty) {
        updates['banner'] = bannerUrl;
      }
      if (updates.isNotEmpty) {
        await _firestoreService.updateStore(storeId, updates);
      }

      final savedStore = await _firestoreService.getStore(storeId);
      final hasSavedLogo =
          savedStore?.logo != null && savedStore!.logo!.trim().isNotEmpty;
      final hasSavedBanner =
          savedStore?.banner != null && savedStore!.banner!.trim().isNotEmpty;

      await _firestoreService.addStoreToUser(widget.userId, storeId);

      if (!mounted) return;
      // Atualiza o provider local para refletir que o usuário agora tem uma loja
      final userProvider = context.read<UserProvider>();
      await userProvider.refresh();
      if (!mounted) return;
      userProvider.notifyMarketplaceChanged();

      final uploadFailures = <String>[];
      if (_logoFile != null && !hasSavedLogo) {
        uploadFailures.add('logomarca');
      }
      if (_bannerFile != null && !hasSavedBanner) {
        uploadFailures.add('banner');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            uploadFailures.isEmpty
                ? 'Loja criada com sucesso! 🎉'
                : 'Loja criada, mas houve falha ao salvar: ${uploadFailures.join(' e ')}.',
            style: GoogleFonts.roboto(color: Colors.white),
          ),
          backgroundColor:
              uploadFailures.isEmpty ? AppTheme.success : AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.of(context).popUntil((r) => r.isFirst);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _uploadStoreImage({
    required String storeId,
    required File? file,
    required _StoreImageKind kind,
  }) async {
    if (file == null) return null;

    final cloudinaryUrl = kind == _StoreImageKind.logo
        ? await _cloudinary.uploadStoreLogo(storeId, file)
        : await _cloudinary.uploadStoreBanner(storeId, file);
    if (cloudinaryUrl != null && cloudinaryUrl.trim().isNotEmpty) {
      return cloudinaryUrl;
    }

    final firebaseUrl = kind == _StoreImageKind.logo
        ? await _storage.uploadStoreLogo(storeId, file)
        : await _storage.uploadStoreBanner(storeId, file);
    if (firebaseUrl != null && firebaseUrl.trim().isNotEmpty) {
      return firebaseUrl;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    final titles = ['Sobre a loja', 'Visual da loja', 'Detalhes', 'Endereço'];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: GestureDetector(
          onTap: _currentPage == 0 ? () => Navigator.pop(context) : _prevPage,
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.blackLight : const Color(0xFFF0F2F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _currentPage == 0
                  ? Icons.close_rounded
                  : Icons.arrow_back_rounded,
              color: textColor,
              size: 22,
            ),
          ),
        ),
        title: Column(
          children: [
            Text(
              'Criar Loja — ${titles[_currentPage]}',
              style: GoogleFonts.roboto(
                  color: textColor, fontWeight: FontWeight.w700, fontSize: 16),
            ),
            Text(
              'Passo ${_currentPage + 1} de 4',
              style: GoogleFonts.roboto(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: List.generate(
                  4,
                  (i) => Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 4,
                          margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                          decoration: BoxDecoration(
                            color: i <= _currentPage
                                ? AppTheme.facebookBlue
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      )),
            ),
          ),
        ),
      ),
      body: PageView(
        controller: _pageCtrl,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // PASSO 1 — Nome, Categoria, Tipo
          _StoreStep1(
            isDark: isDark,
            initialName: _storeName,
            initialCategory: _storeCategory,
            initialType: _storeType,
            initialHasDelivery: _hasDelivery,
            initialHasInstallments: _hasInstallments,
            onNext: (name, cat, type, hasDelivery, hasInstallments) {
              setState(() {
                _storeName = name;
                _storeCategory = cat;
                _storeType = type;
                _hasDelivery = hasDelivery;
                _hasInstallments = hasInstallments;
              });
              _nextPage();
            },
          ),

          // PASSO 2 — Logo, Banner
          _StoreStep2(
            isDark: isDark,
            logoFile: _logoFile,
            bannerFile: _bannerFile,
            onLogoChanged: (f) => setState(() => _logoFile = f),
            onBannerChanged: (f) => setState(() => _bannerFile = f),
            onNext: _nextPage,
          ),

          // PASSO 3 — Descrição, CNPJ, Nome dono
          _StoreStep3(
            isDark: isDark,
            docMask: _docMask,
            onNext: (desc, doc, name) {
              setState(() {
                _description = desc;
                _ownerDocument = doc;
                _ownerName = name;
              });
              _nextPage();
            },
          ),

          // PASSO 4 — Endereço + Mapa
          _StoreStep4(
            isDark: isDark,
            cepMask: _cepMask,
            address: _address,
            mapLat: _mapLat,
            mapLng: _mapLng,
            mapController: _mapController,
            isLoading: _isLoading,
            onCepChanged: _fetchCep,
            onAddressChanged: (a) => setState(() => _address = a),
            onFinish: _finishStore,
          ),
        ],
      ),
    );
  }
}

// ── PASSO 1 — Nome, categoria, tipo ────────────────────────────────────────
enum _StoreImageKind {
  logo,
  banner,
}

class _StoreStep1 extends StatefulWidget {
  final bool isDark;
  final String initialName;
  final String initialCategory;
  final String initialType;
  final bool initialHasDelivery;
  final bool initialHasInstallments;
  final Function(String, String, String, bool, bool) onNext;

  const _StoreStep1({
    required this.isDark,
    required this.initialName,
    required this.initialCategory,
    required this.initialType,
    required this.initialHasDelivery,
    required this.initialHasInstallments,
    required this.onNext,
  });

  @override
  State<_StoreStep1> createState() => _StoreStep1State();
}

class _StoreStep1State extends State<_StoreStep1> {
  final _nameCtrl = TextEditingController();
  late String _category;
  late String _type;
  late bool _hasDelivery;
  late bool _hasInstallments;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.initialName;
    _category = widget.initialCategory;
    _type = widget.initialType;
    _hasDelivery = widget.initialHasDelivery;
    _hasInstallments = widget.initialHasInstallments;
  }

  @override
  Widget build(BuildContext context) {
    final border =
        widget.isDark ? AppTheme.blackBorder : const Color(0xFFE8E8E8);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _stepTitle('Identidade da loja', widget.isDark).animate().fadeIn(),
            _stepSubtitle(
                    'Como se chama sua loja e o que ela vende?', widget.isDark)
                .animate(delay: 60.ms)
                .fadeIn(),
            const SizedBox(height: 28),

            _field(
              ctrl: _nameCtrl,
              label: 'Nome da loja',
              hint: 'Ex: Tech Store Curitiba',
              isDark: widget.isDark,
              delay: 100,
              validator: (v) => v!.trim().isEmpty ? 'Informe o nome' : null,
            ),
            const SizedBox(height: 20),

            // Categoria
            Text(
              'Categoria',
              style: GoogleFonts.roboto(
                color: widget.isDark
                    ? AppTheme.whiteSecondary
                    : Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: widget.isDark
                    ? AppTheme.blackLight
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _category,
                  isExpanded: true,
                  dropdownColor:
                      widget.isDark ? AppTheme.blackLight : Colors.white,
                  style: GoogleFonts.roboto(
                    color: widget.isDark ? Colors.white : Colors.black87,
                    fontSize: 14,
                  ),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Colors.grey),
                  items: storeCategories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v!),
                ),
              ),
            ).animate(delay: 160.ms).fadeIn(),

            const SizedBox(height: 20),

            // Tipo
            Text(
              'O que sua loja vende?',
              style: GoogleFonts.roboto(
                color: widget.isDark
                    ? AppTheme.whiteSecondary
                    : Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _typeBtn(
                    'produto', 'Produtos', Icons.inventory_2_outlined, border),
                const SizedBox(width: 10),
                _typeBtn(
                    'servico', 'Serviços', Icons.handyman_outlined, border),
                const SizedBox(width: 10),
                _typeBtn('ambos', 'Ambos', Icons.all_inclusive_rounded, border),
              ],
            ).animate(delay: 220.ms).fadeIn(),

            const SizedBox(height: 20),
            _toggleTile(
              title: 'A loja oferece entrega?',
              value: _hasDelivery,
              onChanged: (value) => setState(() => _hasDelivery = value),
            ).animate(delay: 250.ms).fadeIn(),
            const SizedBox(height: 10),
            _toggleTile(
              title: 'A loja aceita parcelamento?',
              value: _hasInstallments,
              onChanged: (value) => setState(() => _hasInstallments = value),
            ).animate(delay: 280.ms).fadeIn(),

            const SizedBox(height: 40),
            _nextButton(
              label: 'Continuar',
              isDark: widget.isDark,
              delay: 300,
              onTap: () {
                if (_formKey.currentState!.validate()) {
                  widget.onNext(
                    _nameCtrl.text.trim(),
                    _category,
                    _type,
                    _hasDelivery,
                    _hasInstallments,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeBtn(String value, String label, IconData icon, Color border) {
    final isSelected = _type == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.facebookBlue.withValues(alpha: 0.1)
                : (widget.isDark
                    ? AppTheme.blackLight
                    : const Color(0xFFF5F5F5)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.facebookBlue : border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected ? AppTheme.facebookBlue : Colors.grey,
                  size: 20),
              const SizedBox(height: 4),
              Text(label,
                  style: GoogleFonts.roboto(
                    color: isSelected ? AppTheme.facebookBlue : Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggleTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: widget.isDark ? AppTheme.blackLight : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.roboto(
                color: widget.isDark ? Colors.white : Colors.black87,
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

// ── PASSO 2 — Logo + Banner ─────────────────────────────────────────────────
class _StoreStep2 extends StatelessWidget {
  final bool isDark;
  final File? logoFile;
  final File? bannerFile;
  final Function(File?) onLogoChanged;
  final Function(File?) onBannerChanged;
  final VoidCallback onNext;

  const _StoreStep2({
    required this.isDark,
    required this.logoFile,
    required this.bannerFile,
    required this.onLogoChanged,
    required this.onBannerChanged,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final cloudinary = CloudinaryService();
    final bg = isDark ? AppTheme.blackLight : const Color(0xFFF5F5F5);
    final border = isDark ? AppTheme.blackBorder : const Color(0xFFE8E8E8);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _stepTitle('Visual da loja', isDark).animate().fadeIn(),
          _stepSubtitle(
            'Adicione a logomarca e um banner para sua página.',
            isDark,
          ).animate(delay: 60.ms).fadeIn(),
          const SizedBox(height: 32),

          // Logo
          Text(
            'Logomarca',
            style: GoogleFonts.roboto(
              color: isDark ? AppTheme.whiteSecondary : Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final file = await cloudinary.pickAndCropImage(
                context: context,
                aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
                title: 'Recortar Logo da Loja',
              );
              onLogoChanged(file);
            },
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
                image: logoFile != null
                    ? DecorationImage(
                        image: FileImage(logoFile!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: logoFile == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_photo_alternate_outlined,
                            color: AppTheme.facebookBlue, size: 32),
                        const SizedBox(height: 6),
                        Text(
                          'Adicionar\nlogo',
                          style: GoogleFonts.roboto(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  : null,
            ),
          ).animate(delay: 100.ms).fadeIn(),

          const SizedBox(height: 24),

          // Banner
          Text(
            'Banner da loja',
            style: GoogleFonts.roboto(
              color: isDark ? AppTheme.whiteSecondary : Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final file = await cloudinary.pickAndCropImage(
                context: context,
                aspectRatio: const CropAspectRatio(ratioX: 3, ratioY: 1),
                title: 'Recortar Banner da Loja',
              );
              onBannerChanged(file);
            },
            child: Container(
              width: double.infinity,
              height: 160,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
                image: bannerFile != null
                    ? DecorationImage(
                        image: FileImage(bannerFile!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: bannerFile == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.panorama_outlined,
                            color: AppTheme.facebookBlue, size: 40),
                        const SizedBox(height: 8),
                        Text(
                          'Adicionar banner (recomendado: 1200x400)',
                          style: GoogleFonts.roboto(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
          ).animate(delay: 160.ms).fadeIn(),

          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.facebookBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppTheme.facebookBlue, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Imagens são opcionais, mas deixam sua loja muito mais atrativa!',
                    style: GoogleFonts.roboto(
                      color: AppTheme.facebookBlue,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ).animate(delay: 200.ms).fadeIn(),

          const SizedBox(height: 40),
          _nextButton(
            label: 'Continuar',
            isDark: isDark,
            delay: 260,
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

// ── PASSO 3 — Descrição, Documento, Nome do dono ───────────────────────────
class _StoreStep3 extends StatefulWidget {
  final bool isDark;
  final MaskTextInputFormatter docMask;
  final Function(String, String, String) onNext;

  const _StoreStep3({
    required this.isDark,
    required this.docMask,
    required this.onNext,
  });

  @override
  State<_StoreStep3> createState() => _StoreStep3State();
}

class _StoreStep3State extends State<_StoreStep3> {
  final _descCtrl = TextEditingController();
  final _docCtrl = TextEditingController();
  final _ownerCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _stepTitle('Detalhes da loja', widget.isDark).animate().fadeIn(),
            _stepSubtitle(
              'Essas informações aparecem na página pública da sua loja.',
              widget.isDark,
            ).animate(delay: 60.ms).fadeIn(),
            const SizedBox(height: 28),

            // Descrição
            _field(
              ctrl: _descCtrl,
              label: 'Descrição da loja',
              hint:
                  'Conte um pouco sobre sua loja, o que você vende, diferenciais...',
              isDark: widget.isDark,
              delay: 100,
              maxLines: 4,
              validator: (v) =>
                  v!.trim().isEmpty ? 'Informe a descrição' : null,
            ),
            const SizedBox(height: 16),

            // CNPJ/CPF com lógica de máscara dinâmica
            _field(
              ctrl: _docCtrl,
              label: 'CNPJ ou CPF do responsável',
              hint: '000.000.000-00 ou 00.000.000/0000-00',
              isDark: widget.isDark,
              delay: 160,
              keyboardType: TextInputType.number,
              inputFormatters: [widget.docMask],
              onChanged: (v) {
                final clean = v.replaceAll(RegExp(r'\D'), '');
                if (clean.length <= 11) {
                  widget.docMask.updateMask(mask: '###.###.###-##');
                } else {
                  widget.docMask.updateMask(mask: '##.###.###/####-##');
                }
              },
              validator: (v) {
                final clean = v!.replaceAll(RegExp(r'\D'), '');
                if (clean.length != 11 && clean.length != 14) {
                  return 'Documento deve ter 11 (CPF) ou 14 (CNPJ) dígitos';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Nome do dono
            _field(
              ctrl: _ownerCtrl,
              label: 'Nome completo do responsável',
              hint: 'Nome do proprietário ou representante',
              isDark: widget.isDark,
              delay: 220,
              validator: (v) => v!.trim().isEmpty ? 'Informe o nome' : null,
            ),

            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.security_rounded,
                      color: Colors.amber, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Seus dados são protegidos e não serão compartilhados publicamente.',
                      style: GoogleFonts.roboto(
                          color: Colors.amber.shade800, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ).animate(delay: 280.ms).fadeIn(),

            const SizedBox(height: 40),
            _nextButton(
              label: 'Continuar',
              isDark: widget.isDark,
              delay: 320,
              onTap: () {
                if (_formKey.currentState!.validate()) {
                  widget.onNext(
                    _descCtrl.text.trim(),
                    _docCtrl.text,
                    _ownerCtrl.text.trim(),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── PASSO 4 — Endereço + Mapa ───────────────────────────────────────────────
class _StoreStep4 extends StatefulWidget {
  final bool isDark;
  final MaskTextInputFormatter cepMask;
  final AddressModel address;
  final double mapLat;
  final double mapLng;
  final MapController mapController;
  final bool isLoading;
  final Function(String) onCepChanged;
  final Function(AddressModel) onAddressChanged;
  final VoidCallback onFinish;

  const _StoreStep4({
    required this.isDark,
    required this.cepMask,
    required this.address,
    required this.mapLat,
    required this.mapLng,
    required this.mapController,
    required this.isLoading,
    required this.onCepChanged,
    required this.onAddressChanged,
    required this.onFinish,
  });

  @override
  State<_StoreStep4> createState() => _StoreStep4State();
}

class _StoreStep4State extends State<_StoreStep4> {
  late final TextEditingController _cepCtrl;
  late final TextEditingController _streetCtrl;
  late final TextEditingController _numberCtrl;
  late final TextEditingController _complementCtrl;
  late final TextEditingController _neighborhoodCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _stateCtrl;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _cepCtrl = TextEditingController(text: widget.address.cep);
    _streetCtrl = TextEditingController(text: widget.address.street);
    _numberCtrl = TextEditingController(text: widget.address.number);
    _complementCtrl = TextEditingController(text: widget.address.complement);
    _neighborhoodCtrl =
        TextEditingController(text: widget.address.neighborhood);
    _cityCtrl = TextEditingController(text: widget.address.city);
    _stateCtrl = TextEditingController(text: widget.address.state);
  }

  @override
  void didUpdateWidget(_StoreStep4 old) {
    super.didUpdateWidget(old);
    _streetCtrl.text = widget.address.street;
    _neighborhoodCtrl.text = widget.address.neighborhood;
    _cityCtrl.text = widget.address.city;
    _stateCtrl.text = widget.address.state;
  }

  void _sync() {
    widget.onAddressChanged(widget.address.copyWith(
      cep: _cepCtrl.text,
      street: _streetCtrl.text,
      number: _numberCtrl.text,
      complement: _complementCtrl.text,
      neighborhood: _neighborhoodCtrl.text,
      city: _cityCtrl.text,
      state: _stateCtrl.text,
      lat: widget.mapLat,
      lng: widget.mapLng,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _stepTitle('Endereço da loja', widget.isDark).animate().fadeIn(),
            _stepSubtitle('Onde os clientes podem te encontrar?', widget.isDark)
                .animate(delay: 60.ms)
                .fadeIn(),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: _field(
                    ctrl: _cepCtrl,
                    label: 'CEP',
                    hint: '00000-000',
                    isDark: widget.isDark,
                    delay: 100,
                    keyboardType: TextInputType.number,
                    inputFormatters: [widget.cepMask],
                    onChanged: widget.onCepChanged,
                    validator: (v) {
                      final c = v!.replaceAll(RegExp(r'\D'), '');
                      return c.length != 8 ? 'CEP inválido' : null;
                    },
                  ),
                ),
                if (widget.isLoading) ...[
                  const SizedBox(width: 12),
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.facebookBlue),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            _field(
                ctrl: _streetCtrl,
                label: 'Rua',
                hint: 'Nome da rua',
                isDark: widget.isDark,
                delay: 140,
                onChanged: (_) => _sync()),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  flex: 2,
                  child: _field(
                      ctrl: _numberCtrl,
                      label: 'Número',
                      hint: 'Nº',
                      isDark: widget.isDark,
                      delay: 160,
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                      onChanged: (_) => _sync())),
              const SizedBox(width: 12),
              Expanded(
                  flex: 3,
                  child: _field(
                      ctrl: _complementCtrl,
                      label: 'Complemento',
                      hint: 'Sala, Loja...',
                      isDark: widget.isDark,
                      delay: 170,
                      onChanged: (_) => _sync())),
            ]),
            const SizedBox(height: 12),
            _field(
                ctrl: _neighborhoodCtrl,
                label: 'Bairro',
                hint: 'Bairro',
                isDark: widget.isDark,
                delay: 180,
                onChanged: (_) => _sync()),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  flex: 3,
                  child: _field(
                      ctrl: _cityCtrl,
                      label: 'Cidade',
                      hint: 'Cidade',
                      isDark: widget.isDark,
                      delay: 190,
                      onChanged: (_) => _sync())),
              const SizedBox(width: 12),
              Expanded(
                  flex: 2,
                  child: _field(
                      ctrl: _stateCtrl,
                      label: 'Estado',
                      hint: 'UF',
                      isDark: widget.isDark,
                      delay: 200,
                      onChanged: (_) => _sync())),
            ]),
            const SizedBox(height: 16),

            // Mapa
            Text('Localização no mapa',
                style: GoogleFonts.roboto(
                    color: widget.isDark
                        ? AppTheme.whiteSecondary
                        : Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 250, // Aumentado para melhor visualização
                decoration: BoxDecoration(
                  border: Border.all(
                      color: widget.isDark
                          ? AppTheme.blackBorder
                          : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: FlutterMap(
                  mapController: widget.mapController,
                  options: MapOptions(
                    initialCenter: LatLng(widget.mapLat, widget.mapLng),
                    initialZoom: 15,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag
                          .all, // Garante que o mapa seja interativo
                    ),
                    onTap: (tapPosition, point) {
                      widget.onAddressChanged(widget.address.copyWith(
                        lat: point.latitude,
                        lng: point.longitude,
                      ));
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.clearviewdev.marketview',
                    ),
                    MarkerLayer(markers: [
                      Marker(
                        point: LatLng(widget.mapLat, widget.mapLng),
                        width: 50,
                        height: 50,
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: Colors.red, // Cor mais visível para o marcador
                          size: 45,
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ).animate(delay: 220.ms).fadeIn(),

            const SizedBox(height: 40),

            // Botão finalizar
            GestureDetector(
              onTap: widget.isLoading
                  ? null
                  : () {
                      if (_formKey.currentState!.validate()) {
                        _sync();
                        widget.onFinish();
                      }
                    },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppTheme.facebookBlue,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.facebookBlue.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: widget.isLoading
                    ? const Center(
                        child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5)))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: Colors.white, size: 22),
                          const SizedBox(width: 8),
                          Text('Criar minha loja!',
                              style: GoogleFonts.roboto(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
              ),
            ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.2, end: 0),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── FUNÇÕES AUXILIARES (criadas localmente) ──────────────────────────────────
Widget _stepTitle(String text, bool isDark) {
  return Text(
    text,
    style: GoogleFonts.roboto(
      color: isDark ? Colors.white : Colors.black87,
      fontSize: 22,
      fontWeight: FontWeight.w800,
    ),
  );
}

Widget _stepSubtitle(String text, bool isDark) {
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      text,
      style: GoogleFonts.roboto(
        color: Colors.grey,
        fontSize: 14,
        height: 1.4,
      ),
    ),
  );
}

Widget _field({
  required TextEditingController ctrl,
  required String label,
  required String hint,
  required bool isDark,
  required int delay,
  TextInputType? keyboardType,
  List<dynamic>? inputFormatters,
  bool obscure = false,
  Widget? suffix,
  int maxLines = 1,
  String? Function(String?)? validator,
  Function(String)? onChanged,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: GoogleFonts.roboto(
          color: isDark ? AppTheme.whiteSecondary : Colors.grey.shade600,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 6),
      TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters?.cast(),
        obscureText: obscure,
        maxLines: maxLines,
        onChanged: onChanged,
        validator: validator,
        style: GoogleFonts.roboto(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.roboto(color: Colors.grey, fontSize: 14),
          suffixIcon: suffix,
          filled: true,
          fillColor: isDark ? AppTheme.blackLight : const Color(0xFFF5F5F5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppTheme.facebookBlue, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.error, width: 1),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    ],
  )
      .animate(delay: Duration(milliseconds: delay))
      .fadeIn()
      .slideY(begin: 0.1, end: 0);
}

Widget _nextButton({
  required String label,
  required bool isDark,
  required int delay,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.facebookBlue,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppTheme.facebookBlue.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        label,
        style: GoogleFonts.roboto(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        textAlign: TextAlign.center,
      ),
    ),
  )
      .animate(delay: Duration(milliseconds: delay))
      .fadeIn()
      .slideY(begin: 0.2, end: 0);
}
