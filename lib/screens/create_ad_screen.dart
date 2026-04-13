import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/ad_model.dart';
import '../models/store_model.dart';
import '../providers/user_provider.dart';
import '../services/cloudinary_service.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class _PropertyCostDraft {
  _PropertyCostDraft({
    String name = '',
    String amount = '',
  })  : nameCtrl = TextEditingController(text: name),
        amountCtrl = TextEditingController(text: amount);

  final TextEditingController nameCtrl;
  final TextEditingController amountCtrl;
  String period = PropertyExtraCost.propertyCostPeriodMonthly;
  bool priceOnRequest = false;

  void dispose() {
    nameCtrl.dispose();
    amountCtrl.dispose();
  }
}

class _ListingFlowOption {
  const _ListingFlowOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.type,
    required this.defaultCategory,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final String type;
  final String defaultCategory;
}

class _AdSpecFieldConfig {
  const _AdSpecFieldConfig({
    required this.id,
    required this.label,
    required this.hint,
    this.keyboardType = TextInputType.text,
  });

  final String id;
  final String label;
  final String hint;
  final TextInputType keyboardType;
}

const String _listingFlowAutomotive = 'automotive';
const String _listingFlowProducts = 'products';
const String _listingFlowProperties = 'properties';
const String _listingFlowServices = 'services';
const String _listingFlowJobs = 'jobs';

const List<_ListingFlowOption> _listingFlowOptions = [
  _ListingFlowOption(
    id: _listingFlowAutomotive,
    title: 'Automóveis, peças e acessórios',
    subtitle: 'Carros, motos, vans, ônibus, caminhões...',
    icon: Icons.directions_car_filled_outlined,
    type: AdModel.productType,
    defaultCategory: 'Veiculos',
  ),
  _ListingFlowOption(
    id: _listingFlowProducts,
    title: 'Produtos',
    subtitle: 'Celulares, roupas, móveis, eletro...',
    icon: Icons.inventory_2_outlined,
    type: AdModel.productType,
    defaultCategory: 'Eletronicos',
  ),
  _ListingFlowOption(
    id: _listingFlowProperties,
    title: 'Imóveis',
    subtitle: 'Apartamentos, casas, aluguel de quartos...',
    icon: Icons.home_work_outlined,
    type: AdModel.productType,
    defaultCategory: 'Imoveis',
  ),
  _ListingFlowOption(
    id: _listingFlowServices,
    title: 'Serviços',
    subtitle: 'Domésticos, eventos, mudanças, informática...',
    icon: Icons.handyman_outlined,
    type: AdModel.serviceType,
    defaultCategory: 'Outros servicos',
  ),
  _ListingFlowOption(
    id: _listingFlowJobs,
    title: 'Vaga de emprego',
    subtitle: 'Atendimento, vendas, administrativo...',
    icon: Icons.work_outline_rounded,
    type: AdModel.serviceType,
    defaultCategory: 'Vaga de emprego',
  ),
];

const List<_AdSpecFieldConfig> _genericServiceSpecFields = [
  _AdSpecFieldConfig(
    id: 'service_experience',
    label: 'Tempo de experiência',
    hint: 'Ex: 4 anos',
  ),
  _AdSpecFieldConfig(
    id: 'service_region',
    label: 'Região de atendimento',
    hint: 'Ex: Curitiba e região',
  ),
  _AdSpecFieldConfig(
    id: 'service_schedule',
    label: 'Disponibilidade',
    hint: 'Ex: Segunda a sábado, comercial',
  ),
];

const Map<String, List<_AdSpecFieldConfig>> _categorySpecFieldOptions = {
  'Celulares': [
    _AdSpecFieldConfig(
      id: 'phone_storage',
      label: 'Armazenamento',
      hint: 'Ex: 256 GB',
    ),
    _AdSpecFieldConfig(
      id: 'phone_ram',
      label: 'Memória RAM',
      hint: 'Ex: 8 GB',
    ),
    _AdSpecFieldConfig(
      id: 'phone_battery_health',
      label: 'Saúde da bateria',
      hint: 'Ex: 89%',
      keyboardType: TextInputType.number,
    ),
    _AdSpecFieldConfig(
      id: 'phone_condition',
      label: 'Estado do aparelho',
      hint: 'Ex: Sem marcas, tudo funcionando',
    ),
  ],
  'Notebooks': [
    _AdSpecFieldConfig(
      id: 'notebook_processor',
      label: 'Processador',
      hint: 'Ex: Intel Core i7 12ª geração',
    ),
    _AdSpecFieldConfig(
      id: 'notebook_ram',
      label: 'Memória RAM',
      hint: 'Ex: 16 GB',
    ),
    _AdSpecFieldConfig(
      id: 'notebook_storage',
      label: 'Armazenamento',
      hint: 'Ex: SSD 512 GB',
    ),
    _AdSpecFieldConfig(
      id: 'notebook_screen',
      label: 'Tela',
      hint: 'Ex: 15,6 polegadas Full HD',
    ),
  ],
  'Computadores': [
    _AdSpecFieldConfig(
      id: 'pc_processor',
      label: 'Processador',
      hint: 'Ex: Ryzen 7 5700X',
    ),
    _AdSpecFieldConfig(
      id: 'pc_ram',
      label: 'Memória RAM',
      hint: 'Ex: 32 GB',
    ),
    _AdSpecFieldConfig(
      id: 'pc_storage',
      label: 'Armazenamento',
      hint: 'Ex: SSD 1 TB',
    ),
    _AdSpecFieldConfig(
      id: 'pc_gpu',
      label: 'Placa de vídeo',
      hint: 'Ex: RTX 4060',
    ),
  ],
  'Tablets': [
    _AdSpecFieldConfig(
      id: 'tablet_storage',
      label: 'Armazenamento',
      hint: 'Ex: 128 GB',
    ),
    _AdSpecFieldConfig(
      id: 'tablet_screen',
      label: 'Tela',
      hint: 'Ex: 11 polegadas',
    ),
    _AdSpecFieldConfig(
      id: 'tablet_connectivity',
      label: 'Conectividade',
      hint: 'Ex: Wi‑Fi + 5G',
    ),
  ],
  'TVs': [
    _AdSpecFieldConfig(
      id: 'tv_size',
      label: 'Polegadas',
      hint: 'Ex: 55',
      keyboardType: TextInputType.number,
    ),
    _AdSpecFieldConfig(
      id: 'tv_resolution',
      label: 'Resolução',
      hint: 'Ex: 4K UHD',
    ),
    _AdSpecFieldConfig(
      id: 'tv_panel',
      label: 'Tipo de painel',
      hint: 'Ex: QLED, OLED ou LED',
    ),
  ],
  'Videogames': [
    _AdSpecFieldConfig(
      id: 'console_storage',
      label: 'Armazenamento',
      hint: 'Ex: 1 TB',
    ),
    _AdSpecFieldConfig(
      id: 'console_accessories',
      label: 'Acompanha o quê?',
      hint: 'Ex: 2 controles, headset, jogos',
    ),
    _AdSpecFieldConfig(
      id: 'console_condition',
      label: 'Estado do console',
      hint: 'Ex: Excelente, pouco usado',
    ),
  ],
  'Roupas': [
    _AdSpecFieldConfig(
      id: 'fashion_brand',
      label: 'Marca',
      hint: 'Ex: Zara',
    ),
    _AdSpecFieldConfig(
      id: 'fashion_size',
      label: 'Tamanho',
      hint: 'Ex: M / 40',
    ),
    _AdSpecFieldConfig(
      id: 'fashion_condition',
      label: 'Condição',
      hint: 'Ex: Nova com etiqueta',
    ),
  ],
  'Moveis': [
    _AdSpecFieldConfig(
      id: 'furniture_material',
      label: 'Material',
      hint: 'Ex: MDF, madeira maciça',
    ),
    _AdSpecFieldConfig(
      id: 'furniture_dimensions',
      label: 'Dimensões',
      hint: 'Ex: 1,80 x 0,90 x 0,45 m',
    ),
    _AdSpecFieldConfig(
      id: 'furniture_condition',
      label: 'Estado',
      hint: 'Ex: Muito conservado',
    ),
  ],
  'Vaga de emprego': [
    _AdSpecFieldConfig(
      id: 'job_contract',
      label: 'Regime de contratação',
      hint: 'Ex: CLT, PJ, estágio',
    ),
    _AdSpecFieldConfig(
      id: 'job_schedule',
      label: 'Jornada',
      hint: 'Ex: Segunda a sexta, 8h às 18h',
    ),
    _AdSpecFieldConfig(
      id: 'job_mode',
      label: 'Modalidade',
      hint: 'Ex: Presencial, híbrido ou remoto',
    ),
    _AdSpecFieldConfig(
      id: 'job_benefits',
      label: 'Benefícios',
      hint: 'Ex: VT, VR, comissão, plano de saúde',
    ),
  ],
};

class CreateAdScreen extends StatefulWidget {
  const CreateAdScreen({
    super.key,
    this.initialStoreId,
    this.initialIntent = AdModel.intentSell,
  });

  final String? initialStoreId;
  final String initialIntent;

  @override
  State<CreateAdScreen> createState() => _CreateAdScreenState();
}

class _CreateAdScreenState extends State<CreateAdScreen> {
  final _pageController = PageController();
  final _cloudinary = CloudinaryService();
  final _firestore = FirestoreService();
  final _storage = StorageService();

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _hourlyPriceCtrl = TextEditingController();
  final _kmCtrl = TextEditingController();
  final _vehicleBrandCtrl = TextEditingController();
  final _vehicleModelCtrl = TextEditingController();
  final _vehicleYearCtrl = TextEditingController();
  final _vehicleOwnerCountCtrl = TextEditingController();
  final _vehicleOptionalCtrl = TextEditingController();
  final _propertyAreaCtrl = TextEditingController();
  final _propertyBedroomsCtrl = TextEditingController();
  final _propertyBathroomsCtrl = TextEditingController();
  final _propertyParkingCtrl = TextEditingController();
  final _condoFeeCtrl = TextEditingController();
  final Map<String, TextEditingController> _specControllers = {};

  int _currentStep = 0;
  bool _isLoading = false;
  String _selectedListingFlow = _listingFlowProducts;
  String _selectedType = AdModel.productType;
  String _selectedCategory = productCategories.first;
  String? _selectedCategoryType;
  String? _customCategoryTypeLabel;
  String _selectedAccount = 'personal';
  String _selectedServicePricing = AdModel.servicePriceFixed;
  String _selectedPropertyOfferType = AdModel.propertyOfferSale;
  String _selectedPropertyExtraMode = AdModel.propertyExtraNone;
  String _selectedPropertyFurnishing = AdModel.propertyFurnishingUnfurnished;
  bool _condoFeeOnRequest = false;
  final List<File> _images = [];
  final List<StoreModel> _availableStores = [];
  final List<String> _selectedVehicleOptionals = [];
  final List<_PropertyCostDraft> _propertyCostDrafts = [];
  String? _selectedVehicleColor;
  String? _selectedVehicleFuelType;
  String? _selectedStoreId;

  bool get _isBuyRequest => widget.initialIntent == AdModel.intentBuy;

  bool get _needsStoreSelection =>
      !_isBuyRequest &&
      _selectedAccount == 'store' &&
      _availableStores.length > 1;

  bool get _needsVehicleDetailsStep =>
      !_isBuyRequest &&
      _selectedType == AdModel.productType &&
      AdModel.normalizeValue(_selectedCategory) == 'veiculos';

  bool get _isPropertyProduct =>
      !_isBuyRequest &&
      _selectedType == AdModel.productType &&
      AdModel.normalizeValue(_selectedCategory) == 'imoveis';

  bool get _isJobCategory =>
      !_isBuyRequest &&
      AdModel.normalizeValue(_selectedCategory) == 'vaga de emprego';

  bool get _showsServicePricingModes =>
      _needsServicePricingStep && !_isJobCategory;

  _ListingFlowOption get _selectedListingFlowOption {
    return _listingFlowOptions.firstWhere(
      (option) => option.id == _selectedListingFlow,
      orElse: () => _listingFlowOptions[1],
    );
  }

  List<String> get _availableCategories {
    final base = _selectedType == AdModel.serviceType
        ? serviceCategories
        : productCategories;
    if (base.contains(_selectedCategory)) return base;
    return [_selectedCategory, ...base];
  }

  List<String> get _availableCategoryTypes {
    final base = List<String>.from(
      categoryTypeOptions[_selectedCategory] ?? const <String>[],
    );
    if (!base.contains('Outro +')) {
      base.add('Outro +');
    }
    return base;
  }

  List<_AdSpecFieldConfig> get _currentSpecConfigs {
    if (_isBuyRequest) return const [];

    final explicitType = _selectedCategoryType;
    if (explicitType != null && explicitType != 'Outro') {
      final specific = _categorySpecFieldOptions[explicitType];
      if (specific != null) return specific;
    }

    final byCategory = _categorySpecFieldOptions[_selectedCategory];
    if (byCategory != null) return byCategory;

    if (_selectedType == AdModel.serviceType) {
      return _genericServiceSpecFields;
    }

    return const [];
  }

  bool get _needsPropertyCostsStep =>
      _isPropertyProduct &&
      _selectedPropertyOfferType == AdModel.propertyOfferRent &&
      _selectedPropertyExtraMode != AdModel.propertyExtraNone;

  bool get _hasPropertyCondo =>
      _selectedPropertyExtraMode == AdModel.propertyExtraCondo ||
      _selectedPropertyExtraMode == AdModel.propertyExtraCondoAndCosts;

  bool get _hasPropertyExtraCosts =>
      _selectedPropertyExtraMode == AdModel.propertyExtraCosts ||
      _selectedPropertyExtraMode == AdModel.propertyExtraCondoAndCosts;

  bool get _needsServicePricingStep =>
      !_isBuyRequest && _selectedType == AdModel.serviceType;

  int get _stepCount {
    if (_isBuyRequest) return 5;
    final base = _needsStoreSelection ? 6 : 5;
    return base +
        (_needsVehicleDetailsStep ? 1 : 0) +
        (_needsPropertyCostsStep ? 1 : 0);
  }

  int get _typeStepIndex => _isBuyRequest ? 0 : (_needsStoreSelection ? 2 : 1);
  int get _infoStepIndex => _typeStepIndex + 1;
  int get _vehicleStepIndex =>
      _needsVehicleDetailsStep ? _infoStepIndex + 1 : -1;
  int get _priceStepIndex => _isBuyRequest
      ? _infoStepIndex + 1
      : (_needsVehicleDetailsStep ? _vehicleStepIndex + 1 : _infoStepIndex + 1);
  int get _propertyCostsStepIndex =>
      _needsPropertyCostsStep ? _priceStepIndex + 1 : -1;
  int get _photosStepIndex => _isBuyRequest
      ? 3
      : (_needsPropertyCostsStep
          ? _propertyCostsStepIndex + 1
          : _priceStepIndex + 1);
  int get _summaryStepIndex => _photosStepIndex + 1;
  bool get _isLastStep => _currentStep == _summaryStepIndex;

  List<Widget> _buildSteps(bool isDark) {
    if (_isBuyRequest) {
      return [
        _stepType(isDark),
        _stepInfo(isDark),
        _stepBudget(isDark),
        _stepPhotos(isDark),
        _stepSummary(isDark),
      ];
    }

    return [
      _stepAccount(isDark),
      if (_needsStoreSelection) _stepStoreSelection(isDark),
      _stepType(isDark),
      _stepInfo(isDark),
      if (_needsVehicleDetailsStep) _stepVehicleDetails(isDark),
      _stepPricing(isDark),
      if (_needsPropertyCostsStep) _stepPropertyCosts(isDark),
      _stepPhotos(isDark),
      _stepSummary(isDark),
    ];
  }

  @override
  void initState() {
    super.initState();
    _priceCtrl.addListener(_formatPriceInput);
    _hourlyPriceCtrl.addListener(_formatHourlyPriceInput);
    _selectedVehicleColor = vehicleColorOptions.first;
    _selectedVehicleFuelType = vehicleFuelOptions.last;
    if (!_isBuyRequest && widget.initialStoreId != null) {
      _selectedAccount = 'store';
      _selectedStoreId = widget.initialStoreId;
    }
    if (!_isBuyRequest) {
      _loadStores();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.removeListener(_formatPriceInput);
    _priceCtrl.dispose();
    _hourlyPriceCtrl.removeListener(_formatHourlyPriceInput);
    _hourlyPriceCtrl.dispose();
    _kmCtrl.dispose();
    _vehicleBrandCtrl.dispose();
    _vehicleModelCtrl.dispose();
    _vehicleYearCtrl.dispose();
    _vehicleOwnerCountCtrl.dispose();
    _vehicleOptionalCtrl.dispose();
    _propertyAreaCtrl.dispose();
    _propertyBedroomsCtrl.dispose();
    _propertyBathroomsCtrl.dispose();
    _propertyParkingCtrl.dispose();
    _condoFeeCtrl.dispose();
    for (final controller in _specControllers.values) {
      controller.dispose();
    }
    for (final draft in _propertyCostDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<void> _loadStores() async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;
    final stores = await _firestore.getStoresForUser(user.uid);
    if (!mounted) return;
    setState(() {
      _availableStores
        ..clear()
        ..addAll(stores);
      if (_selectedStoreId == null && stores.length == 1) {
        _selectedStoreId = stores.first.id;
      }
    });
    _normalizeCurrentStep();
  }

  void _normalizeCurrentStep() {
    final lastStep = _stepCount - 1;
    if (_currentStep <= lastStep) return;
    setState(() => _currentStep = lastStep);
    _pageController.jumpToPage(lastStep);
  }

  void _formatPriceInput() {
    final text = _priceCtrl.text;
    if (text.isEmpty) return;

    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      _priceCtrl.clear();
      return;
    }

    final value = int.parse(digits) / 100;
    final formatted = value.toStringAsFixed(2);
    final parts = formatted.split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    final buffer = StringBuffer();
    var count = 0;
    for (var i = intPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write('.');
      buffer.write(intPart[i]);
      count++;
    }
    final result = '${buffer.toString().split('').reversed.join()},$decPart';
    if (_priceCtrl.text != result) {
      _priceCtrl.value = TextEditingValue(
        text: result,
        selection: TextSelection.collapsed(offset: result.length),
      );
    }
  }

  void _formatHourlyPriceInput() {
    final text = _hourlyPriceCtrl.text;
    if (text.isEmpty) return;

    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      _hourlyPriceCtrl.clear();
      return;
    }

    final value = int.parse(digits) / 100;
    final formatted = value.toStringAsFixed(2);
    final parts = formatted.split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    final buffer = StringBuffer();
    var count = 0;
    for (var i = intPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write('.');
      buffer.write(intPart[i]);
      count++;
    }
    final result = '${buffer.toString().split('').reversed.join()},$decPart';
    if (_hourlyPriceCtrl.text != result) {
      _hourlyPriceCtrl.value = TextEditingValue(
        text: result,
        selection: TextSelection.collapsed(offset: result.length),
      );
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _label(String value) => AdModel.displayLabel(value);

  String _adCreationTypeSubtitle() {
    if (_isBuyRequest) {
      return 'Escolha se sua solicitação é para um produto ou um serviço.';
    }
    return 'Escolha o formato que melhor representa o anúncio e refine a categoria na próxima etapa.';
  }

  String _titleHint() {
    if (_isBuyRequest) {
      return _selectedType == AdModel.serviceType
          ? 'Ex: Preciso de diarista 2x por semana'
          : 'Ex: Procuro notebook para trabalho';
    }

    switch (_selectedListingFlow) {
      case _listingFlowAutomotive:
        return 'Ex: Honda Civic Touring 2020';
      case _listingFlowProperties:
        return 'Ex: Apartamento 2 quartos no Centro';
      case _listingFlowServices:
        return 'Ex: Serviço de mudança residencial';
      case _listingFlowJobs:
        return 'Ex: Vaga para atendente de loja';
      case _listingFlowProducts:
      default:
        return 'Ex: iPhone 14 Pro Max 256GB';
    }
  }

  String _descriptionHint() {
    if (_isBuyRequest) {
      return 'Explique os detalhes, condições ou requisitos do que você procura.';
    }

    if (_isJobCategory) {
      return 'Descreva atividades, requisitos, carga horária, benefícios e diferenciais da vaga.';
    }

    if (_selectedType == AdModel.serviceType) {
      return 'Conte como o serviço funciona, o que está incluso e sua disponibilidade.';
    }

    return 'Conte mais sobre o que está anunciando...';
  }

  String _pricingStepSubtitle() {
    if (_isJobCategory) {
      return 'Informe a faixa salarial ou remuneração oferecida para a vaga.';
    }

    if (_selectedType == AdModel.serviceType) {
      return 'Defina como o serviço será cobrado antes de informar os valores.';
    }

    if (_isPropertyProduct) {
      return 'Informe se o imóvel está para venda ou aluguel e depois defina o valor.';
    }

    return 'Informe o valor principal do seu anúncio.';
  }

  TextEditingController _specControllerFor(String id) {
    return _specControllers.putIfAbsent(id, TextEditingController.new);
  }

  List<AdAttribute> _buildCustomAttributes() {
    return _currentSpecConfigs
        .map((config) => AdAttribute(
              key: config.id,
              label: config.label,
              value: _specControllerFor(config.id).text.trim(),
            ))
        .where((attribute) => attribute.value.isNotEmpty)
        .toList();
  }

  String _locationLabelFromParts(String city, String state) {
    final trimmedCity = city.trim();
    final trimmedState = state.trim();
    if (trimmedCity.isNotEmpty && trimmedState.isNotEmpty) {
      return '$trimmedCity, $trimmedState';
    }
    if (trimmedCity.isNotEmpty) return trimmedCity;
    if (trimmedState.isNotEmpty) return trimmedState;
    return 'Localização não informada';
  }

  bool _validateInfoStep() {
    if (_titleCtrl.text.trim().isEmpty) {
      _showMessage(_isBuyRequest
          ? 'Informe um título para o pedido.'
          : 'Informe um título para o anúncio.');
      return false;
    }
    if (_descCtrl.text.trim().isEmpty) {
      _showMessage(_isBuyRequest
          ? 'Descreva o que você está procurando.'
          : 'Descreva o que você está anunciando.');
      return false;
    }
    if (_availableCategoryTypes.isNotEmpty &&
        (_selectedCategoryType?.trim().isEmpty ?? true)) {
      _showMessage('Selecione o tipo principal dessa categoria.');
      return false;
    }
    return true;
  }

  bool _validateVehicleStep() {
    if (!_needsVehicleDetailsStep) return true;
    if (_vehicleBrandCtrl.text.trim().isEmpty) {
      _showMessage('Informe a marca do veículo.');
      return false;
    }
    if (_vehicleModelCtrl.text.trim().isEmpty) {
      _showMessage('Informe o modelo do veículo.');
      return false;
    }
    if (int.tryParse(_vehicleYearCtrl.text.trim()) == null) {
      _showMessage('Informe um ano válido para o veículo.');
      return false;
    }
    if (int.tryParse(_vehicleOwnerCountCtrl.text.trim()) == null) {
      _showMessage('Informe o número de proprietários.');
      return false;
    }
    return true;
  }

  bool _validatePriceStep() {
    final price = _parseCurrency(_priceCtrl.text);
    if (price == null || price <= 0) {
      _showMessage(_isBuyRequest
          ? 'Informe quanto espera pagar.'
          : 'Informe um preço válido para continuar.');
      return false;
    }
    if (_needsServicePricingStep &&
        _selectedServicePricing == AdModel.servicePriceFixedPlusHourly) {
      final hourlyPrice = _parseCurrency(_hourlyPriceCtrl.text);
      if (hourlyPrice == null || hourlyPrice <= 0) {
        _showMessage('Informe o valor por hora para esse serviço.');
        return false;
      }
    }
    return true;
  }

  bool _validatePropertyCostsStep() {
    if (!_needsPropertyCostsStep) return true;

    if (_hasPropertyCondo && !_condoFeeOnRequest) {
      final condoFee = _parseCurrency(_condoFeeCtrl.text);
      if (condoFee == null || condoFee <= 0) {
        _showMessage('Informe o valor do condomínio para continuar.');
        return false;
      }
    }

    if (_hasPropertyExtraCosts) {
      if (_propertyCostDrafts.isEmpty) {
        _showMessage('Adicione pelo menos um custo extra.');
        return false;
      }

      for (final draft in _propertyCostDrafts) {
        if (draft.nameCtrl.text.trim().isEmpty) {
          _showMessage('Informe o nome de cada custo extra.');
          return false;
        }
        final amount = _parseCurrency(draft.amountCtrl.text);
        if (!draft.priceOnRequest && (amount == null || amount <= 0)) {
          _showMessage('Informe um valor mensal válido para os custos extras.');
          return false;
        }
      }
    }

    return true;
  }

  bool _validateCurrentStep() {
    if (_isBuyRequest) {
      if (_currentStep == _infoStepIndex) {
        return _validateInfoStep();
      }
      if (_currentStep == _priceStepIndex) {
        return _validatePriceStep();
      }
      return true;
    }

    if (_currentStep == 0 &&
        _selectedAccount == 'store' &&
        _availableStores.isEmpty) {
      _showMessage('Você ainda não participa de nenhuma loja.');
      return false;
    }

    if (_needsStoreSelection && _currentStep == 1 && _selectedStoreId == null) {
      _showMessage('Selecione uma loja para continuar.');
      return false;
    }

    if (_currentStep == _infoStepIndex) {
      return _validateInfoStep();
    }

    if (_needsVehicleDetailsStep && _currentStep == _vehicleStepIndex) {
      return _validateVehicleStep();
    }

    if (_currentStep == _priceStepIndex) {
      return _validatePriceStep();
    }

    if (_currentStep == _propertyCostsStepIndex) {
      return _validatePropertyCostsStep();
    }

    return true;
  }

  Future<void> _nextStep() async {
    if (!_validateCurrentStep()) return;
    if (_isLastStep) {
      await _submit();
      return;
    }

    final nextStep = _currentStep + 1;
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    if (!mounted) return;
    setState(() => _currentStep = nextStep);
  }

  Future<void> _prevStep() async {
    if (_currentStep == 0) return;
    await _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    if (!mounted) return;
    setState(() => _currentStep--);
  }

  Future<void> _pickImages() async {
    final remaining = 10 - _images.length;
    if (remaining <= 0) return;

    final files = await _cloudinary.pickImagesFromGallery(
      context,
      max: remaining,
    );
    if (files.isEmpty) return;
    setState(() => _images.addAll(files));
  }

  Future<void> _cropImageAt(int index) async {
    if (index < 0 || index >= _images.length) return;
    final cropped = await _cloudinary.cropImageFreely(
      path: _images[index].path,
      title: _isBuyRequest
          ? 'Cortar foto de referência'
          : 'Cortar foto do anúncio',
    );
    if (cropped == null) return;
    setState(() => _images[index] = cropped);
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      final user = context.read<UserProvider>().user;
      if (user == null) {
        throw Exception('Você precisa estar logado para publicar.');
      }

      StoreModel? selectedStore;
      var sellerName = user.fullName;
      var sellerAvatar = user.profilePhoto ?? '';
      String? storeName;
      String? storeLogo;

      if (!_isBuyRequest && _selectedAccount == 'store') {
        if (_selectedStoreId == null) {
          throw Exception('Selecione a loja do anúncio.');
        }
        selectedStore = _availableStores.cast<StoreModel?>().firstWhere(
              (store) => store?.id == _selectedStoreId,
              orElse: () => null,
            );
        selectedStore ??= await _firestore.getStore(_selectedStoreId!);
        if (selectedStore == null) {
          throw Exception('Loja selecionada não encontrada.');
        }
        sellerName = selectedStore.name;
        sellerAvatar = selectedStore.logo ?? '';
        storeName = selectedStore.name;
        storeLogo = selectedStore.logo;
      }

      final adId = _firestore.createAdDraftId();
      final imageUrls = <String>[];
      final imagePublicIds = <String>[];
      var failedImageUploads = 0;
      for (var i = 0; i < _images.length; i++) {
        final result = await _cloudinary.uploadAdPhotoFull(adId, _images[i], i);
        if (result != null &&
            result['url'] != null &&
            result['publicId'] != null) {
          imageUrls.add(result['url']!);
          imagePublicIds.add(result['publicId']!);
          continue;
        }

        final firebaseUrl = await _storage.uploadAdPhoto(adId, _images[i], i);
        if (firebaseUrl != null && firebaseUrl.trim().isNotEmpty) {
          imageUrls.add(firebaseUrl);
        } else {
          failedImageUploads++;
        }
      }

      final price = _parseCurrency(_priceCtrl.text) ?? 0.0;
      final hourlyPrice = _parseCurrency(_hourlyPriceCtrl.text);

      final location = selectedStore != null
          ? _locationLabelFromParts(
              selectedStore.address.city,
              selectedStore.address.state,
            )
          : _locationLabelFromParts(user.address.city, user.address.state);
      final latitude = selectedStore?.address.lat ?? user.address.lat;
      final longitude = selectedStore?.address.lng ?? user.address.lng;

      final ad = AdModel(
        id: adId,
        sellerId: user.uid,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        price: price,
        category: _selectedCategory,
        categoryType: _selectedCategoryType?.trim().isNotEmpty == true
            ? _selectedCategoryType!.trim()
            : null,
        categoryTypeCustomLabel:
            _customCategoryTypeLabel?.trim().isNotEmpty == true
                ? _customCategoryTypeLabel!.trim()
                : null,
        type: _selectedType,
        intent: widget.initialIntent,
        images: imageUrls,
        imagePublicIds: imagePublicIds,
        location: location,
        sellerName: sellerName,
        sellerAvatar: sellerAvatar,
        storeId: selectedStore?.id,
        storeName: storeName,
        storeLogo: storeLogo,
        sellerUserName: user.fullName,
        sellerUserAvatar: user.profilePhoto,
        createdAt: DateTime.now(),
        lat: latitude,
        lng: longitude,
        km: !_isBuyRequest &&
                AdModel.normalizeValue(_selectedCategory) == 'veiculos'
            ? int.tryParse(_kmCtrl.text.replaceAll('.', ''))
            : null,
        servicePriceType: _selectedType == AdModel.serviceType
            ? _selectedServicePricing
            : AdModel.servicePriceFixed,
        hourlyPrice: _selectedType == AdModel.serviceType ? hourlyPrice : null,
        propertyOfferType:
            _isPropertyProduct ? _selectedPropertyOfferType : null,
        condoFee: _isPropertyProduct &&
                _selectedPropertyOfferType == AdModel.propertyOfferRent &&
                _hasPropertyCondo &&
                !_condoFeeOnRequest
            ? _parseCurrency(_condoFeeCtrl.text)
            : null,
        condoFeeOnRequest:
            _isPropertyProduct && _hasPropertyCondo && _condoFeeOnRequest,
        propertyMonthlyCosts: _isPropertyProduct &&
                _selectedPropertyOfferType == AdModel.propertyOfferRent &&
                _hasPropertyExtraCosts
            ? _buildPropertyExtraCosts()
            : const [],
        propertyArea: _isPropertyProduct
            ? double.tryParse(
                _propertyAreaCtrl.text.trim().replaceAll(',', '.'),
              )
            : null,
        propertyBedrooms: _isPropertyProduct
            ? int.tryParse(_propertyBedroomsCtrl.text.trim())
            : null,
        propertyBathrooms: _isPropertyProduct
            ? int.tryParse(_propertyBathroomsCtrl.text.trim())
            : null,
        propertyParkingSpots: _isPropertyProduct
            ? int.tryParse(_propertyParkingCtrl.text.trim())
            : null,
        propertyFurnishing:
            _isPropertyProduct ? _selectedPropertyFurnishing : null,
        customAttributes: _buildCustomAttributes(),
        vehicleBrand:
            _needsVehicleDetailsStep ? _vehicleBrandCtrl.text.trim() : null,
        vehicleModel:
            _needsVehicleDetailsStep ? _vehicleModelCtrl.text.trim() : null,
        vehicleYear: _needsVehicleDetailsStep
            ? int.tryParse(_vehicleYearCtrl.text.trim())
            : null,
        vehicleOptionals: _needsVehicleDetailsStep
            ? List<String>.from(_selectedVehicleOptionals)
            : const [],
        vehicleColor: _needsVehicleDetailsStep ? _selectedVehicleColor : null,
        vehicleFuelType:
            _needsVehicleDetailsStep ? _selectedVehicleFuelType : null,
        vehicleOwnerCount: _needsVehicleDetailsStep
            ? int.tryParse(_vehicleOwnerCountCtrl.text.trim())
            : null,
      );

      await _firestore.createAd(ad);
      if (!mounted) return;
      context.read<UserProvider>().notifyMarketplaceChanged();
      _showMessage(_isBuyRequest
          ? (failedImageUploads == 0
              ? 'Solicitacao publicada com sucesso!'
              : 'Solicitacao publicada, mas $failedImageUploads imagem(ns) falharam no upload.')
          : (failedImageUploads == 0
              ? 'Anuncio publicado com sucesso!'
              : 'Anuncio publicado, mas $failedImageUploads imagem(ns) falharam no upload.'));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Erro: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.black : AppTheme.lightBg;
    final textColor = isDark ? Colors.white : Colors.black87;
    final steps = _buildSteps(isDark);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.black : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isBuyRequest ? 'Nova solicitação' : 'Novo anúncio',
          style: GoogleFonts.roboto(
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / _stepCount,
            backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppTheme.facebookBlue),
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: steps,
      ),
      bottomNavigationBar: _buildBottomBar(isDark),
    );
  }

  Widget _buildBottomBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.blackCard : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.blackBorder : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading ? null : _prevStep,
                child: const Text('Voltar'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: _isLoading ? null : _nextStep,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.facebookBlue,
                minimumSize: const Size.fromHeight(50),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _isLastStep
                          ? (_isBuyRequest
                              ? 'Publicar solicitação'
                              : 'Publicar anúncio')
                          : 'Continuar',
                      style: GoogleFonts.roboto(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepAccount(bool isDark) {
    final user = context.watch<UserProvider>().user;
    final hasStore = _availableStores.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _title('Onde deseja anunciar?', isDark),
        const SizedBox(height: 8),
        _subtitle(
          'Escolha se este anúncio pertence ao seu perfil pessoal ou a uma das suas lojas.',
        ),
        const SizedBox(height: 28),
        _accountOption(
          'personal',
          'Perfil pessoal',
          'Anuncie como ${user?.fullName ?? 'Usuário'}',
          Icons.person_outline_rounded,
          isDark,
          true,
        ),
        const SizedBox(height: 14),
        _accountOption(
          'store',
          'Minhas lojas',
          hasStore
              ? 'Escolha a loja que vai representar o anúncio'
              : 'Você precisa criar ou entrar em uma loja primeiro',
          Icons.store_outlined,
          isDark,
          hasStore,
        ),
      ],
    );
  }

  Widget _accountOption(
    String value,
    String title,
    String subtitle,
    IconData icon,
    bool isDark,
    bool enabled,
  ) {
    final selected = _selectedAccount == value;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled
            ? () => setState(() {
                  _selectedAccount = value;
                  if (value == 'personal') _selectedStoreId = null;
                })
            : null,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.facebookBlue.withValues(alpha: 0.08)
                : (isDark ? AppTheme.blackLight : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppTheme.facebookBlue
                  : (isDark ? AppTheme.blackBorder : Colors.grey.shade200),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 30,
                color: selected ? AppTheme.facebookBlue : Colors.grey,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.roboto(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.roboto(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.facebookBlue,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepStoreSelection(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _title('Escolha a loja', isDark),
        const SizedBox(height: 8),
        _subtitle('Selecione em qual loja o anúncio será publicado.'),
        const SizedBox(height: 24),
        ..._availableStores.map(
          (store) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => setState(() => _selectedStoreId = store.id),
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _selectedStoreId == store.id
                      ? AppTheme.facebookBlue.withValues(alpha: 0.08)
                      : (isDark ? AppTheme.blackLight : Colors.white),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedStoreId == store.id
                        ? AppTheme.facebookBlue
                        : (isDark
                            ? AppTheme.blackBorder
                            : Colors.grey.shade200),
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor:
                          AppTheme.facebookBlue.withValues(alpha: 0.10),
                      backgroundImage:
                          store.logo != null ? NetworkImage(store.logo!) : null,
                      child: store.logo == null
                          ? Text(
                              store.name[0].toUpperCase(),
                              style: GoogleFonts.roboto(
                                color: AppTheme.facebookBlue,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            store.name,
                            style: GoogleFonts.roboto(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _label(store.category),
                            style: GoogleFonts.roboto(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_selectedStoreId == store.id)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppTheme.facebookBlue,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _stepType(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _title(
          _isBuyRequest
              ? 'O que você está procurando?'
              : 'O que você quer anunciar?',
          isDark,
        ),
        const SizedBox(height: 8),
        _subtitle(_adCreationTypeSubtitle()),
        const SizedBox(height: 28),
        if (_isBuyRequest) ...[
          _typeOption(
            AdModel.productType,
            _isBuyRequest ? 'Produto que preciso' : 'Item/Bem',
            Icons.inventory_2_outlined,
            isDark,
          ),
          const SizedBox(height: 14),
          _typeOption(
            AdModel.serviceType,
            _isBuyRequest ? 'Serviço que preciso' : 'Serviço',
            Icons.handyman_outlined,
            isDark,
          ),
        ] else
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 14.0;
              final compactWidth = (constraints.maxWidth - spacing) / 2;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: _listingFlowOptions.map((option) {
                  final isWide = option.id == _listingFlowJobs;
                  return SizedBox(
                    width: isWide ? constraints.maxWidth : compactWidth,
                    child: _listingFlowCard(
                      option: option,
                      isDark: isDark,
                      isWide: isWide,
                    ),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }

  Widget _typeOption(String value, String label, IconData icon, bool isDark) {
    final selected = _selectedType == value;
    return InkWell(
      onTap: () => _handleTypeChange(value),
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.facebookBlue.withValues(alpha: 0.08)
              : (isDark ? AppTheme.blackLight : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppTheme.facebookBlue
                : (isDark ? AppTheme.blackBorder : Colors.grey.shade200),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? AppTheme.facebookBlue : Colors.grey),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.roboto(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listingFlowCard({
    required _ListingFlowOption option,
    required bool isDark,
    required bool isWide,
  }) {
    final selected = _selectedListingFlow == option.id;
    final borderColor = selected
        ? AppTheme.facebookBlue
        : (isDark ? AppTheme.blackBorder : Colors.grey.shade200);
    final backgroundColor = selected
        ? AppTheme.facebookBlue.withValues(alpha: 0.10)
        : (isDark ? AppTheme.blackLight : Colors.white);

    return InkWell(
      onTap: () => _handleListingFlowChange(option.id),
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: EdgeInsets.all(isWide ? 18 : 16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? AppTheme.facebookBlue.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
              blurRadius: selected ? 18 : 10,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: isWide ? 116 : 150),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.facebookBlue.withValues(alpha: 0.16)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      option.icon,
                      color: selected
                          ? AppTheme.facebookBlue
                          : Colors.grey.shade600,
                      size: 24,
                    ),
                  ),
                  const Spacer(),
                  AnimatedOpacity(
                    opacity: selected ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppTheme.facebookBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                option.title,
                style: GoogleFonts.roboto(
                  fontSize: isWide ? 18 : 17,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                option.subtitle,
                maxLines: isWide ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.roboto(
                  fontSize: 12.5,
                  height: 1.35,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepInfo(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _title(
          _isBuyRequest ? 'Detalhes do pedido' : 'Detalhes do anúncio',
          isDark,
        ),
        const SizedBox(height: 24),
        _field(
          _titleCtrl,
          _isBuyRequest ? 'Título do pedido' : 'Título',
          _titleHint(),
          isDark,
        ),
        const SizedBox(height: 18),
        _field(
          _descCtrl,
          _isBuyRequest ? 'O que você precisa?' : 'Descrição',
          _descriptionHint(),
          isDark,
          maxLines: 4,
        ),
        const SizedBox(height: 18),
        _categoryDropdown(isDark),
        if (_availableCategoryTypes.isNotEmpty) ...[
          const SizedBox(height: 18),
          _optionDropdown(
            title: 'Tipo',
            value: _selectedCategoryType,
            selectedLabel: _customCategoryTypeLabel,
            options: _availableCategoryTypes,
            isDark: isDark,
            onChanged: _handleCategoryTypeChange,
          ),
        ],
        if (_currentSpecConfigs.isNotEmpty) ...[
          const SizedBox(height: 18),
          _dynamicSpecSection(isDark),
        ],
        if (_isPropertyProduct) ...[
          const SizedBox(height: 18),
          _field(
            _propertyAreaCtrl,
            'Área (m²)',
            'Ex: 72',
            isDark,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _field(
                  _propertyBedroomsCtrl,
                  'Quartos',
                  'Ex: 3',
                  isDark,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  _propertyBathroomsCtrl,
                  'Banheiros',
                  'Ex: 2',
                  isDark,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _field(
            _propertyParkingCtrl,
            'Vagas de garagem',
            'Ex: 1',
            isDark,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 18),
          _selectableChips(
            title: 'Mobília',
            options: propertyFurnishingLabels.values.toList(),
            selectedValues: {
              propertyFurnishingLabels[_selectedPropertyFurnishing] ??
                  'Não mobiliado',
            },
            onTap: (value) {
              final selected = propertyFurnishingLabels.entries.firstWhere(
                (entry) => entry.value == value,
                orElse: () => const MapEntry(
                  AdModel.propertyFurnishingUnfurnished,
                  'Não mobiliado',
                ),
              );
              setState(() => _selectedPropertyFurnishing = selected.key);
            },
            allowWrapScroll: true,
          ),
        ],
      ],
    );
  }

  Widget _stepVehicleDetails(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _title('Ficha do veículo', isDark),
        const SizedBox(height: 8),
        _subtitle(
          'Preencha os dados do carro para o anúncio ficar mais completo e confiável.',
        ),
        const SizedBox(height: 24),
        _field(_kmCtrl, 'Quilometragem (KM)', 'Ex: 50.000', isDark,
            keyboardType: TextInputType.number),
        const SizedBox(height: 18),
        _field(_vehicleBrandCtrl, 'Marca', 'Ex: Honda', isDark),
        const SizedBox(height: 18),
        _field(_vehicleModelCtrl, 'Modelo', 'Ex: Civic Touring', isDark),
        const SizedBox(height: 18),
        _field(_vehicleYearCtrl, 'Ano', 'Ex: 2020', isDark,
            keyboardType: TextInputType.number),
        const SizedBox(height: 18),
        _field(
            _vehicleOwnerCountCtrl, 'Número de proprietários', 'Ex: 1', isDark,
            keyboardType: TextInputType.number),
        const SizedBox(height: 18),
        _selectableChips(
          title: 'Cor do carro',
          options: vehicleColorOptions,
          selectedValues: {
            if (_selectedVehicleColor != null) _selectedVehicleColor!,
          },
          onTap: (value) => _selectVehicleColor(value),
        ),
        const SizedBox(height: 18),
        _selectableChips(
          title: 'Tipo de combustível',
          options: vehicleFuelOptions,
          selectedValues: {
            if (_selectedVehicleFuelType != null) _selectedVehicleFuelType!,
          },
          onTap: (value) => _selectVehicleFuel(value),
        ),
        const SizedBox(height: 18),
        _selectableChips(
          title: 'Opcionais',
          options: vehicleOptionalSuggestions,
          selectedValues: _selectedVehicleOptionals.toSet(),
          onTap: _handleVehicleOptionalTap,
          allowWrapScroll: true,
        ),
      ],
    );
  }

  Widget _dynamicSpecSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Especificações extras',
          style: GoogleFonts.roboto(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Esses detalhes ajudam o anúncio a ficar mais completo e confiável.',
          style: GoogleFonts.roboto(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 14),
        ..._currentSpecConfigs.asMap().entries.map((entry) {
          final config = entry.value;
          return Padding(
            padding: EdgeInsets.only(
              bottom: entry.key == _currentSpecConfigs.length - 1 ? 0 : 18,
            ),
            child: _field(
              _specControllerFor(config.id),
              config.label,
              config.hint,
              isDark,
              keyboardType: config.keyboardType,
            ),
          );
        }),
      ],
    );
  }

  Widget _stepPricing(bool isDark) {
    if (_isBuyRequest) {
      return _stepBudget(isDark);
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _title('Preço do anúncio', isDark),
        const SizedBox(height: 8),
        _subtitle(_pricingStepSubtitle()),
        if (_isPropertyProduct) ...[
          const SizedBox(height: 24),
          _selectableChips(
            title: 'Negócio',
            options: propertyOfferTypeLabels.values.toList(),
            selectedValues: {
              propertyOfferTypeLabels[_selectedPropertyOfferType] ?? 'Venda',
            },
            onTap: (value) {
              final selected = propertyOfferTypeLabels.entries.firstWhere(
                (entry) => entry.value == value,
                orElse: () =>
                    const MapEntry(AdModel.propertyOfferSale, 'Venda'),
              );
              _handlePropertyOfferTypeChange(selected.key);
            },
            allowWrapScroll: true,
          ),
          if (_selectedPropertyOfferType == AdModel.propertyOfferRent) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.blackLight : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      propertyExtraModeLabels[_selectedPropertyExtraMode] ??
                          'Apenas aluguel',
                      style: GoogleFonts.roboto(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _showPropertyExtraModeDialog,
                    child: const Text('Alterar'),
                  ),
                ],
              ),
            ),
          ],
        ],
        if (_showsServicePricingModes) ...[
          const SizedBox(height: 24),
          _selectableChips(
            title: 'Modelo de cobrança',
            options: servicePricingModes
                .map((mode) => servicePricingModeLabels[mode] ?? mode)
                .toList(),
            selectedValues: {
              servicePricingModeLabels[_selectedServicePricing] ??
                  _selectedServicePricing,
            },
            onTap: (value) {
              final selectedEntry = servicePricingModeLabels.entries.firstWhere(
                (entry) => entry.value == value,
                orElse: () => MapEntry(AdModel.servicePriceFixed, value),
              );
              setState(() => _selectedServicePricing = selectedEntry.key);
            },
            allowWrapScroll: true,
          ),
        ],
        const SizedBox(height: 24),
        _field(
          _priceCtrl,
          _priceLabel(),
          '0,00',
          isDark,
          keyboardType: TextInputType.number,
        ),
        if (_showsServicePricingModes &&
            _selectedServicePricing == AdModel.servicePriceFixedPlusHourly) ...[
          const SizedBox(height: 18),
          _field(
            _hourlyPriceCtrl,
            'Valor por hora adicional (R\$)',
            '0,00',
            isDark,
            keyboardType: TextInputType.number,
          ),
        ],
      ],
    );
  }

  Widget _stepPropertyCosts(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _title(
          _hasPropertyCondo && _hasPropertyExtraCosts
              ? 'Condomínio e custos extras'
              : _hasPropertyCondo
                  ? 'Condomínio do imóvel'
                  : 'Custos extras do aluguel',
          isDark,
        ),
        const SizedBox(height: 8),
        _subtitle(
          _hasPropertyCondo && _hasPropertyExtraCosts
              ? 'Informe o valor do condomínio e adicione os custos extras mensais.'
              : _hasPropertyCondo
                  ? 'Informe o valor mensal do condomínio para salvar no anúncio.'
                  : 'Adicione todos os custos extras mensais e seus valores.',
        ),
        const SizedBox(height: 24),
        if (_hasPropertyCondo) ...[
          _field(
            _condoFeeCtrl,
            'Valor do condomínio (R\$)',
            '0,00 ou marque A combinar',
            isDark,
            keyboardType: TextInputType.number,
            enabled: !_condoFeeOnRequest,
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _condoFeeOnRequest,
            onChanged: (value) => setState(() {
              _condoFeeOnRequest = value ?? false;
              if (_condoFeeOnRequest) {
                _condoFeeCtrl.clear();
              }
            }),
            contentPadding: EdgeInsets.zero,
            title: const Text('A combinar'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (_hasPropertyExtraCosts) const SizedBox(height: 18),
        ],
        if (_hasPropertyExtraCosts) ...[
          ..._propertyCostDrafts.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:
                          isDark ? AppTheme.blackLight : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Custo extra ${entry.key + 1}',
                                style: GoogleFonts.roboto(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (_propertyCostDrafts.length > 1)
                              IconButton(
                                onPressed: () =>
                                    _removePropertyCostDraft(entry.value),
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                          ],
                        ),
                        _field(
                          entry.value.nameCtrl,
                          'Nome do custo',
                          'Ex: IPTU',
                          isDark,
                        ),
                        const SizedBox(height: 14),
                        _field(
                          entry.value.amountCtrl,
                          'Valor (R\$)',
                          '0,00 ou marque A combinar',
                          isDark,
                          keyboardType: TextInputType.number,
                          enabled: !entry.value.priceOnRequest,
                        ),
                        const SizedBox(height: 12),
                        CheckboxListTile(
                          value: entry.value.priceOnRequest,
                          onChanged: (value) => setState(() {
                            entry.value.priceOnRequest = value ?? false;
                            if (entry.value.priceOnRequest) {
                              entry.value.amountCtrl.clear();
                            }
                          }),
                          contentPadding: EdgeInsets.zero,
                          title: const Text('A combinar'),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        const SizedBox(height: 14),
                        _optionDropdown(
                          title: 'Cobrança',
                          value: entry.value.period,
                          options: propertyCostPeriodLabels.keys.toList(),
                          isDark: isDark,
                          displayLabelBuilder: (value) =>
                              propertyCostPeriodLabels[value] ?? value,
                          onChanged: (value) async {
                            setState(() {
                              entry.value.period = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          OutlinedButton.icon(
            onPressed: _addPropertyCostDraft,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Adicionar custo extra'),
          ),
        ],
      ],
    );
  }

  Widget _stepBudget(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _title('Quanto espera pagar?', isDark),
        const SizedBox(height: 8),
        _subtitle(
          'Esse valor aparece no pedido para ajudar quem for te atender a entender sua faixa esperada.',
        ),
        const SizedBox(height: 28),
        _field(
          _priceCtrl,
          'Quanto espera pagar (R\$)',
          '0,00',
          isDark,
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _stepPhotos(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _title(
          _isBuyRequest ? 'Fotos de referência' : 'Fotos do anúncio',
          isDark,
        ),
        const SizedBox(height: 8),
        _subtitle(
          _isBuyRequest
              ? 'Adicione até 10 imagens para mostrar referência do que procura.'
              : 'Adicione até 10 fotos pela galeria.',
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ..._images.asMap().entries.map(
                  (entry) => GestureDetector(
                    onTap: () => _cropImageAt(entry.key),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            entry.value,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: InkWell(
                            onTap: () =>
                                setState(() => _images.removeAt(entry.key)),
                            child: const CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.black54,
                              child: Icon(Icons.close, size: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            if (_images.length < 10)
              InkWell(
                onTap: _pickImages,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.blackLight : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          isDark ? AppTheme.blackBorder : Colors.grey.shade300,
                    ),
                  ),
                  child: Icon(
                    _isBuyRequest
                        ? Icons.add_photo_alternate_outlined
                        : Icons.add_a_photo_outlined,
                    color: AppTheme.facebookBlue,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _stepSummary(bool isDark) {
    final selectedStore = _availableStores.cast<StoreModel?>().firstWhere(
          (store) => store?.id == _selectedStoreId,
          orElse: () => null,
        );
    final user = context.watch<UserProvider>().user;
    final displayLocation = selectedStore != null
        ? _locationLabelFromParts(
            selectedStore.address.city,
            selectedStore.address.state,
          )
        : _locationLabelFromParts(
            user?.address.city ?? '',
            user?.address.state ?? '',
          );
    final previewPrice = _parseCurrency(_priceCtrl.text) ?? 0;
    final previewHourlyPrice = _parseCurrency(_hourlyPriceCtrl.text);
    final previewAd = AdModel(
      id: 'preview',
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      price: previewPrice,
      category: _selectedCategory,
      categoryType: _selectedCategoryType?.trim().isNotEmpty == true
          ? _selectedCategoryType!.trim()
          : null,
      categoryTypeCustomLabel:
          _customCategoryTypeLabel?.trim().isNotEmpty == true
              ? _customCategoryTypeLabel!.trim()
              : null,
      type: _selectedType,
      intent: widget.initialIntent,
      images: const [],
      location: displayLocation,
      sellerName: selectedStore?.name ?? user?.fullName ?? '',
      createdAt: DateTime.now(),
      servicePriceType: _selectedServicePricing,
      hourlyPrice: previewHourlyPrice,
      propertyOfferType: _isPropertyProduct ? _selectedPropertyOfferType : null,
      condoFee: _hasPropertyCondo && !_condoFeeOnRequest
          ? _parseCurrency(_condoFeeCtrl.text)
          : null,
      condoFeeOnRequest: _hasPropertyCondo && _condoFeeOnRequest,
      propertyMonthlyCosts:
          _hasPropertyExtraCosts ? _buildPropertyExtraCosts() : const [],
      propertyArea: double.tryParse(
        _propertyAreaCtrl.text.trim().replaceAll(',', '.'),
      ),
      propertyBedrooms: int.tryParse(_propertyBedroomsCtrl.text.trim()),
      propertyBathrooms: int.tryParse(_propertyBathroomsCtrl.text.trim()),
      propertyParkingSpots: int.tryParse(_propertyParkingCtrl.text.trim()),
      propertyFurnishing:
          _isPropertyProduct ? _selectedPropertyFurnishing : null,
      customAttributes: _buildCustomAttributes(),
      km: int.tryParse(_kmCtrl.text.replaceAll('.', '')),
      vehicleBrand: _vehicleBrandCtrl.text.trim(),
      vehicleModel: _vehicleModelCtrl.text.trim(),
      vehicleYear: int.tryParse(_vehicleYearCtrl.text.trim()),
      vehicleOptionals: List<String>.from(_selectedVehicleOptionals),
      vehicleColor: _selectedVehicleColor,
      vehicleFuelType: _selectedVehicleFuelType,
      vehicleOwnerCount: int.tryParse(_vehicleOwnerCountCtrl.text.trim()),
    );

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _title(
          _isBuyRequest ? 'Resumo do pedido' : 'Resumo do anúncio',
          isDark,
        ),
        const SizedBox(height: 24),
        if (!_isBuyRequest)
          _summaryRow(
            'Perfil de publicação',
            _selectedAccount == 'store'
                ? (selectedStore?.name ?? 'Loja selecionada')
                : 'Perfil pessoal',
            isDark,
          ),
        _summaryRow('Categoria', previewAd.displayCategoryLabel, isDark),
        if (previewAd.displayCategoryTypeLabel.isNotEmpty)
          _summaryRow('Subtipo', previewAd.displayCategoryTypeLabel, isDark),
        _summaryRow(
          'Tipo',
          _isBuyRequest
              ? (_selectedType == AdModel.serviceType ? 'Serviço' : 'Item/Bem')
              : _selectedListingFlowOption.title,
          isDark,
        ),
        _summaryRow(
          _isBuyRequest ? 'Quanto espera pagar' : 'Preço',
          _priceCtrl.text.isEmpty
              ? 'Não informado'
              : previewAd.displayPriceLabel,
          isDark,
        ),
        if (!_isBuyRequest && _showsServicePricingModes)
          _summaryRow(
            'Cobrança',
            previewAd.displayServicePriceTypeLabel,
            isDark,
          ),
        _summaryRow(
          'Localização',
          selectedStore != null
              ? '$displayLocation (da loja)'
              : '$displayLocation (da conta)',
          isDark,
        ),
        if (_isPropertyProduct)
          ...previewAd.propertyDetailEntries
              .where((entry) => entry.key != 'Subtipo')
              .map(
                (entry) => _summaryRow(entry.key, entry.value, isDark),
              ),
        if (_needsVehicleDetailsStep)
          ...previewAd.vehicleDetailEntries.map(
            (entry) => _summaryRow(entry.key, entry.value, isDark),
          ),
        if (previewAd.customAttributeEntries.isNotEmpty)
          ...previewAd.customAttributeEntries.map(
            (entry) => _summaryRow(entry.key, entry.value, isDark),
          ),
        if (_images.isNotEmpty)
          _summaryRow(
            _isBuyRequest ? 'Referências' : 'Fotos',
            '${_images.length} ${_images.length == 1 ? 'imagem' : 'imagens'}',
            isDark,
          ),
      ],
    );
  }

  Widget _summaryRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.roboto(color: Colors.grey)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.roboto(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double? _parseCurrency(String raw) {
    final normalized = raw.trim().replaceAll('.', '').replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  List<PropertyExtraCost> _buildPropertyExtraCosts() {
    return _propertyCostDrafts
        .map(
          (draft) => PropertyExtraCost(
            name: draft.nameCtrl.text.trim(),
            monthlyValue: _parseCurrency(draft.amountCtrl.text) ?? 0,
            billingPeriod: draft.period,
            priceOnRequest: draft.priceOnRequest,
          ),
        )
        .where(
          (cost) => cost.name.isNotEmpty && cost.monthlyValue > 0,
        )
        .toList();
  }

  void _addPropertyCostDraft() {
    setState(() => _propertyCostDrafts.add(_PropertyCostDraft()));
  }

  void _removePropertyCostDraft(_PropertyCostDraft draft) {
    setState(() => _propertyCostDrafts.remove(draft));
    draft.dispose();
  }

  void _resetPropertyFields() {
    _propertyAreaCtrl.clear();
    _propertyBedroomsCtrl.clear();
    _propertyBathroomsCtrl.clear();
    _propertyParkingCtrl.clear();
    _condoFeeCtrl.clear();
    _condoFeeOnRequest = false;
    _selectedPropertyOfferType = AdModel.propertyOfferSale;
    _selectedPropertyExtraMode = AdModel.propertyExtraNone;
    _selectedPropertyFurnishing = AdModel.propertyFurnishingUnfurnished;
    for (final draft in _propertyCostDrafts) {
      draft.dispose();
    }
    _propertyCostDrafts.clear();
  }

  Future<String?> _askPropertyExtraMode() async {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tem custos extras fora o aluguel?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                AdModel.propertyExtraCondoAndCosts,
              ),
              child: const Text('Possui condomínio e custos extras'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                AdModel.propertyExtraCosts,
              ),
              child: const Text('Possui custos extras'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                AdModel.propertyExtraCondo,
              ),
              child: const Text('Possui condomínio'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                AdModel.propertyExtraNone,
              ),
              child: const Text('Apenas aluguel'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _promptCategoryTypeName() async {
    final controller =
        TextEditingController(text: _customCategoryTypeLabel ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nome do tipo'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Digite o nome do tipo',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    final normalized = result?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    return normalized;
  }

  Future<void> _showPropertyExtraModeDialog() async {
    final result = await _askPropertyExtraMode();
    if (result == null || !mounted) return;

    setState(() {
      _selectedPropertyExtraMode = result;
      if (result != AdModel.propertyExtraCondo &&
          result != AdModel.propertyExtraCondoAndCosts) {
        _condoFeeCtrl.clear();
        _condoFeeOnRequest = false;
      }
      if (result != AdModel.propertyExtraCosts &&
          result != AdModel.propertyExtraCondoAndCosts) {
        for (final draft in _propertyCostDrafts) {
          draft.dispose();
        }
        _propertyCostDrafts.clear();
      } else if (_propertyCostDrafts.isEmpty) {
        _propertyCostDrafts.add(_PropertyCostDraft());
      }
    });
    _normalizeCurrentStep();
  }

  Future<void> _handlePropertyOfferTypeChange(String value) async {
    if (value == _selectedPropertyOfferType) return;

    setState(() => _selectedPropertyOfferType = value);

    if (value == AdModel.propertyOfferRent) {
      await _showPropertyExtraModeDialog();
      return;
    }

    setState(() {
      _selectedPropertyExtraMode = AdModel.propertyExtraNone;
      _condoFeeCtrl.clear();
      _condoFeeOnRequest = false;
      for (final draft in _propertyCostDrafts) {
        draft.dispose();
      }
      _propertyCostDrafts.clear();
    });
    _normalizeCurrentStep();
  }

  Future<void> _handleCategoryTypeChange(String value) async {
    if (value == 'Outro +') {
      final custom = await _promptCategoryTypeName();
      if (custom == null || !mounted) return;
      setState(() {
        _selectedCategoryType = 'Outro';
        _customCategoryTypeLabel = custom;
      });
      return;
    }

    setState(() {
      _selectedCategoryType = value;
      _customCategoryTypeLabel = null;
    });
  }

  void _toggleVehicleOptional(String value) {
    setState(() {
      if (_selectedVehicleOptionals.contains(value)) {
        _selectedVehicleOptionals.remove(value);
      } else {
        _selectedVehicleOptionals.add(value);
      }
    });
  }

  Future<void> _selectVehicleColor(String value) async {
    if (value == 'Outro +') {
      final custom = await _promptCustomVehicleValue(
        title: 'Outra cor',
        hint: 'Digite a cor do veículo',
      );
      if (custom == null) return;
      setState(() => _selectedVehicleColor = custom);
      return;
    }
    setState(() => _selectedVehicleColor = value);
  }

  Future<void> _selectVehicleFuel(String value) async {
    if (value == 'Outro +') {
      final custom = await _promptCustomVehicleValue(
        title: 'Outro combustível',
        hint: 'Digite o tipo de combustível',
      );
      if (custom == null) return;
      setState(() => _selectedVehicleFuelType = custom);
      return;
    }
    setState(() => _selectedVehicleFuelType = value);
  }

  Future<void> _handleVehicleOptionalTap(String value) async {
    if (value == 'Outro +') {
      final custom = await _promptCustomVehicleValue(
        title: 'Outro opcional',
        hint: 'Digite um opcional',
      );
      if (custom == null) return;
      _toggleVehicleOptional(custom);
      return;
    }
    _toggleVehicleOptional(value);
  }

  Future<String?> _promptCustomVehicleValue({
    required String title,
    required String hint,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    final normalized = result?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    return normalized;
  }

  void _syncListingFlowFromSelection() {
    if (_isBuyRequest) return;

    final normalizedCategory = AdModel.normalizeValue(_selectedCategory);
    if (_selectedType == AdModel.serviceType) {
      _selectedListingFlow = normalizedCategory == 'vaga de emprego'
          ? _listingFlowJobs
          : _listingFlowServices;
      return;
    }

    if (normalizedCategory == 'veiculos') {
      _selectedListingFlow = _listingFlowAutomotive;
      return;
    }
    if (normalizedCategory == 'imoveis') {
      _selectedListingFlow = _listingFlowProperties;
      return;
    }

    _selectedListingFlow = _listingFlowProducts;
  }

  void _handleListingFlowChange(String flowId) {
    final option = _listingFlowOptions.firstWhere(
      (entry) => entry.id == flowId,
      orElse: () => _listingFlowOptions[1],
    );
    _handleTypeChange(
      option.type,
      preferredCategory: option.defaultCategory,
      listingFlowId: option.id,
      forcePreferredCategory: true,
    );
  }

  void _handleTypeChange(
    String value, {
    String? preferredCategory,
    String? listingFlowId,
    bool forcePreferredCategory = false,
  }) {
    setState(() {
      _selectedType = value;
      final allowedCategories =
          value == AdModel.serviceType ? serviceCategories : productCategories;
      final resolvedPreferredCategory = preferredCategory;
      final canUsePreferredCategory = resolvedPreferredCategory != null &&
          allowedCategories.contains(resolvedPreferredCategory);
      if (canUsePreferredCategory &&
          (forcePreferredCategory ||
              !allowedCategories.contains(_selectedCategory))) {
        _selectedCategory = resolvedPreferredCategory;
      } else if (!allowedCategories.contains(_selectedCategory)) {
        _selectedCategory = allowedCategories.first;
      }
      _selectedCategoryType = null;
      _customCategoryTypeLabel = null;
      if (_selectedType != AdModel.serviceType) {
        _selectedServicePricing = AdModel.servicePriceFixed;
        _hourlyPriceCtrl.clear();
      }
      if (!_needsVehicleDetailsStep) {
        _kmCtrl.clear();
        _vehicleBrandCtrl.clear();
        _vehicleModelCtrl.clear();
        _vehicleYearCtrl.clear();
        _vehicleOwnerCountCtrl.clear();
        _vehicleOptionalCtrl.clear();
        _selectedVehicleOptionals.clear();
        _selectedVehicleColor = vehicleColorOptions.first;
        _selectedVehicleFuelType = vehicleFuelOptions.last;
      }
      if (!_isPropertyProduct) {
        _resetPropertyFields();
      }
      if (!_isBuyRequest) {
        if (listingFlowId != null) {
          _selectedListingFlow = listingFlowId;
        } else {
          _syncListingFlowFromSelection();
        }
      }
    });
    _normalizeCurrentStep();
  }

  void _handleCategoryChange(String value) {
    setState(() {
      _selectedCategory = value;
      _selectedCategoryType = null;
      _customCategoryTypeLabel = null;
      if (!_needsVehicleDetailsStep) {
        _kmCtrl.clear();
        _vehicleBrandCtrl.clear();
        _vehicleModelCtrl.clear();
        _vehicleYearCtrl.clear();
        _vehicleOwnerCountCtrl.clear();
        _vehicleOptionalCtrl.clear();
        _selectedVehicleOptionals.clear();
        _selectedVehicleColor = vehicleColorOptions.first;
        _selectedVehicleFuelType = vehicleFuelOptions.last;
      }
      if (!_isPropertyProduct) {
        _resetPropertyFields();
      }
      _syncListingFlowFromSelection();
    });
    _normalizeCurrentStep();
  }

  Widget _selectableChips({
    required String title,
    required List<String> options,
    required Set<String> selectedValues,
    required ValueChanged<String> onTap,
    bool allowWrapScroll = false,
  }) {
    final chips = options
        .map(
          (option) => Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 8),
            child: FilterChip(
              label: Text(_label(option)),
              selected: selectedValues.contains(option),
              onSelected: (_) => onTap(option),
              selectedColor: AppTheme.facebookBlue.withValues(alpha: 0.18),
              checkmarkColor: AppTheme.facebookBlue,
            ),
          ),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.roboto(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        allowWrapScroll
            ? Wrap(children: chips)
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: chips),
              ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String hint,
    bool isDark, {
    int maxLines = 1,
    TextInputType? keyboardType,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.roboto(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: GoogleFonts.roboto(
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: isDark ? AppTheme.blackLight : Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _categoryDropdown(bool isDark) {
    return _selectionField(
      title: 'Categoria',
      valueLabel: _label(_selectedCategory),
      isDark: isDark,
      leading: _sheetOptionIcon(_selectedCategory),
      onTap: () async {
        final selected = await _showSelectionSheet(
          title: 'Escolha a categoria',
          subtitle: 'Selecione a categoria principal do anúncio.',
          options: _availableCategories,
          selectedValue: _selectedCategory,
          isDark: isDark,
          leadingBuilder: _sheetOptionIcon,
        );
        if (selected == null || !mounted) return;
        _handleCategoryChange(selected);
      },
    );
  }

  Widget _optionDropdown({
    required String title,
    required String? value,
    String? selectedLabel,
    required List<String> options,
    required bool isDark,
    required Future<void> Function(String value) onChanged,
    String Function(String value)? displayLabelBuilder,
  }) {
    if (options.isEmpty) return const SizedBox.shrink();

    final displayValue = value == 'Outro' ? 'Outro +' : value;
    final selectedValue = displayValue != null && options.contains(displayValue)
        ? displayValue
        : null;
    final currentLabel = selectedLabel?.trim().isNotEmpty == true
        ? selectedLabel!.trim()
        : selectedValue != null
            ? displayLabelBuilder?.call(selectedValue) ?? _label(selectedValue)
            : 'Selecionar';

    return _selectionField(
      title: title,
      valueLabel: currentLabel,
      isDark: isDark,
      onTap: () async {
        final nextValue = await _showSelectionSheet(
          title: 'Escolha $title',
          subtitle: 'Veja todas as opções e selecione a que combina melhor.',
          options: options,
          selectedValue: selectedValue,
          isDark: isDark,
          displayLabelBuilder: displayLabelBuilder,
        );
        if (nextValue == null || !mounted) return;
        await onChanged(nextValue);
      },
    );
  }

  Widget _selectionField({
    required String title,
    required String valueLabel,
    required bool isDark,
    required VoidCallback onTap,
    Widget? leading,
  }) {
    final fillColor = isDark ? AppTheme.blackLight : Colors.grey.shade100;
    final borderColor = isDark ? AppTheme.blackBorder : Colors.grey.shade200;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.roboto(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  if (leading != null) ...[
                    leading,
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      valueLabel,
                      style: GoogleFonts.roboto(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget? _sheetOptionIcon(String value) {
    switch (AdModel.normalizeValue(value)) {
      case 'eletronicos':
        return _selectionBadge(Icons.devices_rounded);
      case 'veiculos':
        return _selectionBadge(Icons.directions_car_rounded);
      case 'imoveis':
        return _selectionBadge(Icons.home_work_rounded);
      case 'moveis':
        return _selectionBadge(Icons.chair_rounded);
      case 'roupas':
        return _selectionBadge(Icons.checkroom_rounded);
      case 'esportes':
        return _selectionBadge(Icons.sports_soccer_rounded);
      case 'animais':
      case 'servicos pet':
        return _selectionBadge(Icons.pets_rounded);
      case 'assistencia tecnica':
        return _selectionBadge(Icons.build_circle_rounded);
      case 'aulas e cursos':
        return _selectionBadge(Icons.school_rounded);
      case 'beleza e estetica':
        return _selectionBadge(Icons.content_cut_rounded);
      case 'consultoria':
        return _selectionBadge(Icons.support_agent_rounded);
      case 'design e marketing':
        return _selectionBadge(Icons.campaign_rounded);
      case 'eventos':
        return _selectionBadge(Icons.celebration_rounded);
      case 'fretes e mudancas':
        return _selectionBadge(Icons.local_shipping_rounded);
      case 'limpeza':
        return _selectionBadge(Icons.cleaning_services_rounded);
      case 'reformas e manutencao':
        return _selectionBadge(Icons.handyman_rounded);
      case 'saude e bem-estar':
        return _selectionBadge(Icons.health_and_safety_rounded);
      case 'vaga de emprego':
        return _selectionBadge(Icons.work_outline_rounded);
      case 'outros servicos':
        return _selectionBadge(Icons.miscellaneous_services_rounded);
      case 'outro +':
      case 'outro':
        return _selectionBadge(Icons.add_circle_outline_rounded);
      default:
        return null;
    }
  }

  Widget _selectionBadge(IconData icon) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: AppTheme.facebookBlue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 18, color: AppTheme.facebookBlue),
    );
  }

  Future<String?> _showSelectionSheet({
    required String title,
    required List<String> options,
    required bool isDark,
    String? subtitle,
    String? selectedValue,
    String Function(String value)? displayLabelBuilder,
    Widget? Function(String value)? leadingBuilder,
  }) {
    final backgroundColor = isDark ? AppTheme.blackCard : Colors.white;
    final mutedColor = isDark ? Colors.white70 : Colors.black54;

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: backgroundColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        final maxHeight = MediaQuery.of(sheetContext).size.height * 0.72;

        return SafeArea(
          top: false,
          child: SizedBox(
            height: maxHeight,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.roboto(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                style: GoogleFonts.roboto(color: mutedColor),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemCount: options.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final option = options[index];
                      final selected = option == selectedValue;
                      final display =
                          displayLabelBuilder?.call(option) ?? _label(option);
                      final leading = leadingBuilder?.call(option);

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(sheetContext, option),
                          borderRadius: BorderRadius.circular(18),
                          child: Ink(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppTheme.facebookBlue
                                      .withValues(alpha: 0.12)
                                  : (isDark
                                      ? AppTheme.blackLight
                                      : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: selected
                                    ? AppTheme.facebookBlue
                                    : (isDark
                                        ? AppTheme.blackBorder
                                        : Colors.grey.shade200),
                                width: selected ? 1.6 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                if (leading != null) ...[
                                  leading,
                                  const SizedBox(width: 12),
                                ],
                                Expanded(
                                  child: Text(
                                    display,
                                    style: GoogleFonts.roboto(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                                if (selected)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppTheme.facebookBlue,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _priceLabel() {
    if (_isPropertyProduct) {
      return _selectedPropertyOfferType == AdModel.propertyOfferRent
          ? 'Valor do aluguel (R\$)'
          : 'Valor de venda (R\$)';
    }
    if (_isJobCategory) return 'Salário / remuneração (R\$)';
    if (_selectedType != AdModel.serviceType) return 'Preço (R\$)';
    if (_selectedServicePricing == AdModel.servicePriceHourly) {
      return 'Valor por hora (R\$)';
    }
    if (_selectedServicePricing == AdModel.servicePriceDaily) {
      return 'Valor por diária (R\$)';
    }
    if (_selectedServicePricing == AdModel.servicePriceFixedPlusHourly) {
      return 'Valor fixo inicial (R\$)';
    }
    return 'Preço fixo (R\$)';
  }

  Widget _title(String text, bool isDark) {
    return Text(
      text,
      style: GoogleFonts.roboto(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: isDark ? Colors.white : Colors.black87,
      ),
    );
  }

  Widget _subtitle(String text) {
    return Text(
      text,
      style: GoogleFonts.roboto(color: Colors.grey),
    );
  }
}
