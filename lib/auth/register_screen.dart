import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../services/auth_service.dart';
import '../services/cep_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../store/create_store_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _pageCtrl = PageController();
  int _currentPage = 0;
  bool _isLoading = false;

  // Dados coletados
  String _firstName = '';
  String _lastName = '';
  String _cpf = '';
  String _email = '';
  String _password = '';
  String _phone = '';
  AddressModel _address = AddressModel();
  int _searchRadius = 50;
  double _mapLat = -15.7801;
  double _mapLng = -47.9292;

  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  final _cepService = CepService();

  // Máscaras
  final _cpfMask = MaskTextInputFormatter(mask: '###.###.###-##');
  final _cepMask = MaskTextInputFormatter(mask: '#####-###');
  final _phoneMask = MaskTextInputFormatter(mask: '(##) #####-####');

  final _mapController = MapController();

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
          country: result.country,
        );
      });
      // Geocode para pegar coordenadas
      final coords =
          await _cepService.geocode('${result.city}, ${result.state}, Brasil');
      if (coords != null) {
        setState(() {
          _mapLat = coords.lat;
          _mapLng = coords.lng;
        });
        _mapController.move(LatLng(coords.lat, coords.lng), 13);
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _finishRegistration({required bool createStore}) async {
    setState(() => _isLoading = true);
    try {
      // 1. Cria conta no Firebase Auth
      final result = await _authService.register(
        email: _email,
        password: _password,
      );
      if (!result.success || result.user == null) {
        _showError(result.error ?? 'Erro ao criar conta');
        return;
      }

      // 2. Salva dados no Firestore
      final user = UserModel(
        uid: result.user!.uid,
        firstName: _firstName,
        lastName: _lastName,
        cpf: _cpf,
        email: _email,
        phone: _phone,
        address: _address,
        searchRadius: _searchRadius,
        createdAt: DateTime.now(),
      );
      await _firestoreService.createUser(user);

      // 3. Atualiza provider
      if (mounted) context.read<UserProvider>().setUser(user);

      // 4. Navega para criar loja ou para home
      if (mounted) {
        if (createStore) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => CreateStoreScreen(userId: result.user!.uid),
            ),
          );
        } else {
          Navigator.of(context).popUntil((r) => r.isFirst);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.outfit(color: Colors.white)),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

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
              'Criar conta',
              style: GoogleFonts.outfit(
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Passo ${_currentPage + 1} de 4',
              style: GoogleFonts.outfit(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: _buildProgressBar(),
        ),
      ),
      body: PageView(
        controller: _pageCtrl,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _Step1(
            isDark: isDark,
            cpfMask: _cpfMask,
            onNext: (first, last, cpf) {
              setState(() {
                _firstName = first;
                _lastName = last;
                _cpf = cpf;
              });
              _nextPage();
            },
          ),
          _Step2(
            isDark: isDark,
            phoneMask: _phoneMask,
            onNext: (email, pass, phone) {
              setState(() {
                _email = email;
                _password = pass;
                _phone = phone;
              });
              _nextPage();
            },
          ),
          _Step3(
            isDark: isDark,
            cepMask: _cepMask,
            address: _address,
            mapLat: _mapLat,
            mapLng: _mapLng,
            searchRadius: _searchRadius,
            mapController: _mapController,
            onCepChanged: _fetchCep,
            isLoadingCep: _isLoading,
            onAddressChanged: (addr) => setState(() => _address = addr),
            onRadiusChanged: (r) => setState(() => _searchRadius = r),
            onNext: _nextPage,
          ),
          _Step4(
            isDark: isDark,
            firstName: _firstName,
            isLoading: _isLoading,
            onDecide: (createStore) => _finishRegistration(createStore: createStore),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(4, (i) {
          return Expanded(
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
          );
        }),
      ),
    );
  }
}

// ── PASSO 1 — Nome, Sobrenome, CPF ─────────────────────────────────────────
class _Step1 extends StatefulWidget {
  final bool isDark;
  final MaskTextInputFormatter cpfMask;
  final Function(String, String, String) onNext;

  const _Step1({required this.isDark, required this.cpfMask, required this.onNext});

  @override
  State<_Step1> createState() => _Step1State();
}

class _Step1State extends State<_Step1> {
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _cpfCtrl = TextEditingController();
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
            _stepTitle('Seus dados pessoais', widget.isDark)
                .animate().fadeIn().slideY(begin: -0.1, end: 0),
            _stepSubtitle('Informe seu nome completo e CPF.', widget.isDark)
                .animate(delay: 60.ms).fadeIn(),
            const SizedBox(height: 32),

            _field(
              ctrl: _firstCtrl,
              label: 'Nome',
              hint: 'Ex: João',
              isDark: widget.isDark,
              delay: 100,
              validator: (v) => v!.trim().isEmpty ? 'Informe o nome' : null,
            ),
            const SizedBox(height: 16),
            _field(
              ctrl: _lastCtrl,
              label: 'Sobrenome',
              hint: 'Ex: Silva',
              isDark: widget.isDark,
              delay: 160,
              validator: (v) => v!.trim().isEmpty ? 'Informe o sobrenome' : null,
            ),
            const SizedBox(height: 16),
            _field(
              ctrl: _cpfCtrl,
              label: 'CPF',
              hint: '000.000.000-00',
              isDark: widget.isDark,
              delay: 220,
              keyboardType: TextInputType.number,
              inputFormatters: [widget.cpfMask],
              validator: (v) {
                final clean = v!.replaceAll(RegExp(r'\D'), '');
                return clean.length != 11 ? 'CPF inválido' : null;
              },
            ),
            const SizedBox(height: 40),

            _nextButton(
              label: 'Continuar',
              isDark: widget.isDark,
              delay: 300,
              onTap: () {
                if (_formKey.currentState!.validate()) {
                  widget.onNext(
                    _firstCtrl.text.trim(),
                    _lastCtrl.text.trim(),
                    _cpfCtrl.text,
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

// ── PASSO 2 — Email, Senha, Telefone ───────────────────────────────────────
class _Step2 extends StatefulWidget {
  final bool isDark;
  final MaskTextInputFormatter phoneMask;
  final Function(String, String, String) onNext;

  const _Step2({required this.isDark, required this.phoneMask, required this.onNext});

  @override
  State<_Step2> createState() => _Step2State();
}

class _Step2State extends State<_Step2> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _showPass = false;
  bool _showConfirm = false;

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
            _stepTitle('Acesso e contato', widget.isDark).animate().fadeIn(),
            _stepSubtitle('Esses dados serão usados para entrar no app.', widget.isDark)
                .animate(delay: 60.ms).fadeIn(),
            const SizedBox(height: 32),

            _field(
              ctrl: _emailCtrl,
              label: 'E-mail',
              hint: 'seu@email.com',
              isDark: widget.isDark,
              delay: 100,
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
                  !v!.contains('@') ? 'E-mail inválido' : null,
            ),
            const SizedBox(height: 16),
            _field(
              ctrl: _passCtrl,
              label: 'Senha',
              hint: 'Mínimo 6 caracteres',
              isDark: widget.isDark,
              delay: 160,
              obscure: !_showPass,
              suffix: IconButton(
                icon: Icon(
                  _showPass ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: Colors.grey,
                  size: 20,
                ),
                onPressed: () => setState(() => _showPass = !_showPass),
              ),
              validator: (v) =>
                  v!.length < 6 ? 'Mínimo 6 caracteres' : null,
            ),
            const SizedBox(height: 16),
            _field(
              ctrl: _confirmCtrl,
              label: 'Confirmar senha',
              hint: 'Digite a senha novamente',
              isDark: widget.isDark,
              delay: 200,
              obscure: !_showConfirm,
              suffix: IconButton(
                icon: Icon(
                  _showConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: Colors.grey,
                  size: 20,
                ),
                onPressed: () => setState(() => _showConfirm = !_showConfirm),
              ),
              validator: (v) =>
                  v != _passCtrl.text ? 'As senhas não coincidem' : null,
            ),
            const SizedBox(height: 16),
            _field(
              ctrl: _phoneCtrl,
              label: 'Telefone / WhatsApp',
              hint: '(00) 00000-0000',
              isDark: widget.isDark,
              delay: 240,
              keyboardType: TextInputType.phone,
              inputFormatters: [widget.phoneMask],
              validator: (v) {
                final clean = v!.replaceAll(RegExp(r'\D'), '');
                return clean.length < 10 ? 'Telefone inválido' : null;
              },
            ),
            const SizedBox(height: 40),

            _nextButton(
              label: 'Continuar',
              isDark: widget.isDark,
              delay: 320,
              onTap: () {
                if (_formKey.currentState!.validate()) {
                  widget.onNext(
                    _emailCtrl.text.trim(),
                    _passCtrl.text,
                    _phoneCtrl.text,
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

// ── PASSO 3 — Endereço + Mapa + Raio ──────────────────────────────────────
class _Step3 extends StatefulWidget {
  final bool isDark;
  final MaskTextInputFormatter cepMask;
  final AddressModel address;
  final double mapLat;
  final double mapLng;
  final int searchRadius;
  final MapController mapController;
  final Function(String) onCepChanged;
  final bool isLoadingCep;
  final Function(AddressModel) onAddressChanged;
  final Function(int) onRadiusChanged;
  final VoidCallback onNext;

  const _Step3({
    required this.isDark,
    required this.cepMask,
    required this.address,
    required this.mapLat,
    required this.mapLng,
    required this.searchRadius,
    required this.mapController,
    required this.onCepChanged,
    required this.isLoadingCep,
    required this.onAddressChanged,
    required this.onRadiusChanged,
    required this.onNext,
  });

  @override
  State<_Step3> createState() => _Step3State();
}

class _Step3State extends State<_Step3> {
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
    _neighborhoodCtrl = TextEditingController(text: widget.address.neighborhood);
    _cityCtrl = TextEditingController(text: widget.address.city);
    _stateCtrl = TextEditingController(text: widget.address.state);
  }

  @override
  void didUpdateWidget(_Step3 old) {
    super.didUpdateWidget(old);
    if (widget.address != old.address) {
      _streetCtrl.text = widget.address.street;
      _neighborhoodCtrl.text = widget.address.neighborhood;
      _cityCtrl.text = widget.address.city;
      _stateCtrl.text = widget.address.state;
    }
  }

  void _syncAddress() {
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
    final border = widget.isDark ? AppTheme.blackBorder : const Color(0xFFE8E8E8);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _stepTitle('Sua localização', widget.isDark).animate().fadeIn(),
            _stepSubtitle(
              'Digite seu CEP e preencheremos o endereço automaticamente.',
              widget.isDark,
            ).animate(delay: 60.ms).fadeIn(),
            const SizedBox(height: 24),

            // CEP com loading
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
                      final clean = v!.replaceAll(RegExp(r'\D'), '');
                      return clean.length != 8 ? 'CEP inválido' : null;
                    },
                  ),
                ),
                if (widget.isLoadingCep) ...[
                  const SizedBox(width: 12),
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.facebookBlue,
                    ),
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
              onChanged: (_) => _syncAddress(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _field(
                    ctrl: _numberCtrl,
                    label: 'Número',
                    hint: 'Nº',
                    isDark: widget.isDark,
                    delay: 160,
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.isEmpty ? 'Informe o número' : null,
                    onChanged: (_) => _syncAddress(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: _field(
                    ctrl: _complementCtrl,
                    label: 'Complemento',
                    hint: 'Apto, Bloco...',
                    isDark: widget.isDark,
                    delay: 170,
                    onChanged: (_) => _syncAddress(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _field(
              ctrl: _neighborhoodCtrl,
              label: 'Bairro',
              hint: 'Nome do bairro',
              isDark: widget.isDark,
              delay: 180,
              onChanged: (_) => _syncAddress(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _field(
                    ctrl: _cityCtrl,
                    label: 'Cidade',
                    hint: 'Sua cidade',
                    isDark: widget.isDark,
                    delay: 190,
                    onChanged: (_) => _syncAddress(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _field(
                    ctrl: _stateCtrl,
                    label: 'Estado',
                    hint: 'UF',
                    isDark: widget.isDark,
                    delay: 200,
                    onChanged: (_) => _syncAddress(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Mapa OpenStreetMap (gratuito)
            Text(
              'Sua localização no mapa',
              style: GoogleFonts.outfit(
                color: widget.isDark ? AppTheme.whiteSecondary : Colors.grey.shade600,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 200,
                child: FlutterMap(
                  mapController: widget.mapController,
                  options: MapOptions(
                    initialCenter: LatLng(widget.mapLat, widget.mapLng),
                    initialZoom: 13,
                    onTap: (_, latlng) {
                      widget.onAddressChanged(widget.address.copyWith(
                        lat: latlng.latitude,
                        lng: latlng.longitude,
                      ));
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.clearviewdev.marketview',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(widget.mapLat, widget.mapLng),
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_pin,
                            color: AppTheme.facebookBlue,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ).animate(delay: 220.ms).fadeIn(),

            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: widget.isDark
                    ? AppTheme.blackLight
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: border),
              ),
              child: Text(
                '📍 Toque no mapa para ajustar sua localização exata',
                style: GoogleFonts.outfit(
                  color: Colors.grey,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 24),

            // Raio de busca
            Text(
              'Raio de busca — ${widget.searchRadius} km',
              style: GoogleFonts.outfit(
                color: widget.isDark ? Colors.white : Colors.black87,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ).animate(delay: 260.ms).fadeIn(),
            Text(
              'Ver anúncios em um raio de ${widget.searchRadius}km da sua localização',
              style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
            ),
            Slider(
              value: widget.searchRadius.toDouble(),
              min: 5,
              max: 500,
              divisions: 99,
              activeColor: AppTheme.facebookBlue,
              label: '${widget.searchRadius} km',
              onChanged: (v) => widget.onRadiusChanged(v.toInt()),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('5 km', style: GoogleFonts.outfit(color: Colors.grey, fontSize: 11)),
                Text('500 km', style: GoogleFonts.outfit(color: Colors.grey, fontSize: 11)),
              ],
            ),

            const SizedBox(height: 40),
            _nextButton(
              label: 'Continuar',
              isDark: widget.isDark,
              delay: 300,
              onTap: () {
                if (_formKey.currentState!.validate()) {
                  _syncAddress();
                  widget.onNext();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── PASSO 4 — Criar loja? ──────────────────────────────────────────────────
class _Step4 extends StatelessWidget {
  final bool isDark;
  final String firstName;
  final bool isLoading;
  final Function(bool) onDecide;

  const _Step4({
    required this.isDark,
    required this.firstName,
    required this.isLoading,
    required this.onDecide,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppTheme.facebookBlue.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.store_rounded,
              color: AppTheme.facebookBlue,
              size: 48,
            ),
          ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),

          const SizedBox(height: 24),

          Text(
            'Bem-vindo, $firstName! 🎉',
            style: GoogleFonts.outfit(
              color: textColor,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ).animate(delay: 100.ms).fadeIn(),

          const SizedBox(height: 12),

          Text(
            'Você gostaria de criar uma loja agora?\nCom uma loja você pode anunciar produtos e serviços com uma página personalizada.',
            style: GoogleFonts.outfit(
              color: Colors.grey,
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ).animate(delay: 180.ms).fadeIn(),

          const Spacer(),

          // Criar loja agora
          GestureDetector(
            onTap: isLoading ? null : () => onDecide(true),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.facebookBlue,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.store_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Criar loja agora',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ).animate(delay: 280.ms).fadeIn().slideY(begin: 0.2, end: 0),

          const SizedBox(height: 12),

          // Agora não
          GestureDetector(
            onTap: isLoading ? null : () => onDecide(false),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.blackLight : const Color(0xFFF0F2F5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? AppTheme.blackBorder
                      : const Color(0xFFE0E0E0),
                ),
              ),
              child: Text(
                isLoading ? 'Aguarde...' : 'Agora não',
                style: GoogleFonts.outfit(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ).animate(delay: 340.ms).fadeIn().slideY(begin: 0.2, end: 0),

          const SizedBox(height: 12),

          Text(
            'Você pode criar sua loja a qualquer momento\nnas configurações do seu perfil',
            style: GoogleFonts.outfit(color: Colors.grey, fontSize: 11),
            textAlign: TextAlign.center,
          ).animate(delay: 400.ms).fadeIn(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Helpers compartilhados ──────────────────────────────────────────────────
Widget _stepTitle(String text, bool isDark) {
  return Text(
    text,
    style: GoogleFonts.outfit(
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
      style: GoogleFonts.outfit(
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
        style: GoogleFonts.outfit(
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
        style: GoogleFonts.outfit(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.outfit(color: Colors.grey, fontSize: 14),
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
  ).animate(delay: Duration(milliseconds: delay)).fadeIn().slideY(begin: 0.1, end: 0);
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
            color: AppTheme.facebookBlue.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        textAlign: TextAlign.center,
      ),
    ),
  ).animate(delay: Duration(milliseconds: delay)).fadeIn().slideY(begin: 0.2, end: 0);
}