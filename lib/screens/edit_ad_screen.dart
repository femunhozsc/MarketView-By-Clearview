import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/ad_model.dart';
import '../providers/user_provider.dart';
import '../services/cloudinary_service.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class _PropertyCostDraft {
  _PropertyCostDraft({
    String name = '',
    String amount = '',
    this.period = PropertyExtraCost.propertyCostPeriodMonthly,
  })  : nameCtrl = TextEditingController(text: name),
        amountCtrl = TextEditingController(text: amount);

  final TextEditingController nameCtrl;
  final TextEditingController amountCtrl;
  String period;
  bool priceOnRequest = false;

  void dispose() {
    nameCtrl.dispose();
    amountCtrl.dispose();
  }
}

class EditAdScreen extends StatefulWidget {
  const EditAdScreen({super.key, required this.ad});

  final AdModel ad;

  @override
  State<EditAdScreen> createState() => _EditAdScreenState();
}

class _EditAdScreenState extends State<EditAdScreen> {
  final _pageController = PageController();
  final _cloudinary = CloudinaryService();
  final _firestore = FirestoreService();
  final _storage = StorageService();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _hourlyPriceCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _kmCtrl;
  late final TextEditingController _vehicleBrandCtrl;
  late final TextEditingController _vehicleModelCtrl;
  late final TextEditingController _vehicleYearCtrl;
  late final TextEditingController _vehicleOwnerCountCtrl;
  late final TextEditingController _vehicleOptionalCtrl;
  late final TextEditingController _propertyAreaCtrl;
  late final TextEditingController _propertyBedroomsCtrl;
  late final TextEditingController _propertyBathroomsCtrl;
  late final TextEditingController _propertyParkingCtrl;
  late final TextEditingController _condoFeeCtrl;
  final _newImages = <File>[];
  final _existingImages = <String>[];
  final _existingPublicIds = <String>[];
  final _imagesToDelete = <String>[];
  final _selectedVehicleOptionals = <String>[];
  final _propertyCostDrafts = <_PropertyCostDraft>[];
  int _currentStep = 0;
  bool _isLoading = false;
  late String _selectedCategory;
  String? _selectedCategoryType;
  String? _customCategoryTypeLabel;
  late String _selectedType;
  late String _selectedServicePricing;
  late String _selectedPropertyOfferType;
  late String _selectedPropertyExtraMode;
  late String _selectedPropertyFurnishing;
  bool _condoFeeOnRequest = false;
  String? _selectedVehicleColor;
  String? _selectedVehicleFuelType;

  bool get _isBuyRequest => widget.ad.isWantedAd;
  bool get _isVehicleProduct =>
      !_isBuyRequest &&
      _selectedType == AdModel.productType &&
      AdModel.normalizeValue(_selectedCategory) == 'veiculos';

  bool get _isPropertyProduct =>
      !_isBuyRequest &&
      _selectedType == AdModel.productType &&
      AdModel.normalizeValue(_selectedCategory) == 'imoveis';

  bool get _hasPropertyCondo =>
      _selectedPropertyExtraMode == AdModel.propertyExtraCondo ||
      _selectedPropertyExtraMode == AdModel.propertyExtraCondoAndCosts;

  bool get _hasPropertyExtraCosts =>
      _selectedPropertyExtraMode == AdModel.propertyExtraCosts ||
      _selectedPropertyExtraMode == AdModel.propertyExtraCondoAndCosts;

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

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.ad.title);
    _descCtrl = TextEditingController(text: widget.ad.description);
    _priceCtrl = TextEditingController(
      text: widget.ad.price.toStringAsFixed(2).replaceAll('.', ','),
    )..addListener(_formatPriceInput);
    _hourlyPriceCtrl = TextEditingController(
      text:
          widget.ad.hourlyPrice?.toStringAsFixed(2).replaceAll('.', ',') ?? '',
    )..addListener(_formatHourlyPriceInput);
    _locationCtrl = TextEditingController(text: widget.ad.location);
    _kmCtrl = TextEditingController(text: widget.ad.km?.toString() ?? '');
    _vehicleBrandCtrl =
        TextEditingController(text: widget.ad.vehicleBrand ?? '');
    _vehicleModelCtrl =
        TextEditingController(text: widget.ad.vehicleModel ?? '');
    _vehicleYearCtrl =
        TextEditingController(text: widget.ad.vehicleYear?.toString() ?? '');
    _vehicleOwnerCountCtrl = TextEditingController(
        text: widget.ad.vehicleOwnerCount?.toString() ?? '');
    _vehicleOptionalCtrl = TextEditingController();
    _propertyAreaCtrl = TextEditingController(
      text: widget.ad.propertyArea == null
          ? ''
          : widget.ad.propertyArea!
              .toStringAsFixed(
                widget.ad.propertyArea ==
                        widget.ad.propertyArea!.roundToDouble()
                    ? 0
                    : 1,
              )
              .replaceAll('.', ','),
    );
    _propertyBedroomsCtrl = TextEditingController(
      text: widget.ad.propertyBedrooms?.toString() ?? '',
    );
    _propertyBathroomsCtrl = TextEditingController(
      text: widget.ad.propertyBathrooms?.toString() ?? '',
    );
    _propertyParkingCtrl = TextEditingController(
      text: widget.ad.propertyParkingSpots?.toString() ?? '',
    );
    _condoFeeCtrl = TextEditingController(
      text: widget.ad.condoFee == null
          ? ''
          : widget.ad.condoFee!.toStringAsFixed(2).replaceAll('.', ','),
    );
    _selectedCategory = widget.ad.category;
    _selectedCategoryType = widget.ad.categoryType;
    _customCategoryTypeLabel = widget.ad.categoryTypeCustomLabel;
    _selectedType = widget.ad.type;
    _selectedServicePricing = widget.ad.servicePriceType;
    _selectedPropertyOfferType =
        widget.ad.propertyOfferType ?? AdModel.propertyOfferSale;
    _selectedPropertyExtraMode =
        widget.ad.condoFee != null && widget.ad.propertyMonthlyCosts.isNotEmpty
            ? AdModel.propertyExtraCondoAndCosts
            : widget.ad.condoFee != null
                ? AdModel.propertyExtraCondo
                : widget.ad.propertyMonthlyCosts.isNotEmpty
                    ? AdModel.propertyExtraCosts
                    : AdModel.propertyExtraNone;
    _condoFeeOnRequest = widget.ad.condoFeeOnRequest;
    _selectedPropertyFurnishing =
        widget.ad.propertyFurnishing ?? AdModel.propertyFurnishingUnfurnished;
    _selectedVehicleColor = widget.ad.vehicleColor ?? vehicleColorOptions.first;
    _selectedVehicleFuelType =
        widget.ad.vehicleFuelType ?? vehicleFuelOptions.last;
    _selectedVehicleOptionals.addAll(widget.ad.vehicleOptionals);
    for (final cost in widget.ad.propertyMonthlyCosts) {
      _propertyCostDrafts.add(
        _PropertyCostDraft(
          name: cost.name,
          amount: cost.monthlyValue.toStringAsFixed(2).replaceAll('.', ','),
          period: cost.billingPeriod,
        )..priceOnRequest = cost.priceOnRequest,
      );
    }
    _existingImages.addAll(widget.ad.images);
    _existingPublicIds.addAll(widget.ad.imagePublicIds);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl
      ..removeListener(_formatPriceInput)
      ..dispose();
    _hourlyPriceCtrl
      ..removeListener(_formatHourlyPriceInput)
      ..dispose();
    _locationCtrl.dispose();
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
    for (final draft in _propertyCostDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  void _formatPriceInput() => _formatCurrencyController(_priceCtrl);
  void _formatHourlyPriceInput() => _formatCurrencyController(_hourlyPriceCtrl);

  void _formatCurrencyController(TextEditingController controller) {
    final digits = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return;
    final value = int.parse(digits) / 100;
    final formatted = value.toStringAsFixed(2).split('.');
    final buffer = StringBuffer();
    var count = 0;
    for (var i = formatted[0].length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write('.');
      buffer.write(formatted[0][i]);
      count++;
    }
    final result =
        '${buffer.toString().split('').reversed.join()},${formatted[1]}';
    if (controller.text != result) {
      controller.value = TextEditingValue(
        text: result,
        selection: TextSelection.collapsed(offset: result.length),
      );
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _label(String value) => AdModel.displayLabel(value);

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

  void _handleTypeChange(String value) {
    setState(() {
      _selectedType = value;
      final allowedCategories =
          value == AdModel.serviceType ? serviceCategories : productCategories;
      if (!allowedCategories.contains(_selectedCategory)) {
        _selectedCategory = allowedCategories.first;
      }
      _selectedCategoryType = null;
      _customCategoryTypeLabel = null;
      if (_selectedType != AdModel.serviceType) {
        _selectedServicePricing = AdModel.servicePriceFixed;
        _hourlyPriceCtrl.clear();
      }
      if (!_isVehicleProduct) {
        _resetVehicleFields();
      }
      if (!_isPropertyProduct) {
        _resetPropertyFields();
      }
    });
  }

  void _handleCategoryChange(String value) {
    setState(() {
      _selectedCategory = value;
      _selectedCategoryType = null;
      _customCategoryTypeLabel = null;
      if (!_isVehicleProduct) {
        _resetVehicleFields();
      }
      if (!_isPropertyProduct) {
        _resetPropertyFields();
      }
    });
  }

  void _resetVehicleFields() {
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
        .where((cost) => cost.name.isNotEmpty && cost.monthlyValue > 0)
        .toList();
  }

  void _addPropertyCostDraft() {
    setState(() => _propertyCostDrafts.add(_PropertyCostDraft()));
  }

  void _removePropertyCostDraft(_PropertyCostDraft draft) {
    setState(() => _propertyCostDrafts.remove(draft));
    draft.dispose();
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
      for (final draft in _propertyCostDrafts) {
        draft.dispose();
      }
      _propertyCostDrafts.clear();
    });
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

  bool _validateInfo() {
    if (_titleCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty) {
      _showMessage('Preencha título e descrição do anúncio.');
      return false;
    }
    if (_availableCategoryTypes.isNotEmpty &&
        (_selectedCategoryType?.trim().isEmpty ?? true)) {
      _showMessage('Selecione o tipo principal dessa categoria.');
      return false;
    }
    final price = _parseCurrency(_priceCtrl.text);
    if (price == null || price <= 0) {
      _showMessage('Informe um preço válido.');
      return false;
    }
    if (_selectedType == AdModel.serviceType &&
        _selectedServicePricing == AdModel.servicePriceFixedPlusHourly) {
      final hourly = _parseCurrency(_hourlyPriceCtrl.text);
      if (hourly == null || hourly <= 0) {
        _showMessage('Informe o valor por hora adicional.');
        return false;
      }
    }
    if (_isVehicleProduct &&
        (_vehicleBrandCtrl.text.trim().isEmpty ||
            _vehicleModelCtrl.text.trim().isEmpty ||
            int.tryParse(_vehicleYearCtrl.text.trim()) == null ||
            int.tryParse(_vehicleOwnerCountCtrl.text.trim()) == null)) {
      _showMessage('Complete a ficha do veículo.');
      return false;
    }
    if (_isPropertyProduct &&
        _selectedPropertyOfferType == AdModel.propertyOfferRent) {
      if (_hasPropertyCondo && !_condoFeeOnRequest) {
        final condo = _parseCurrency(_condoFeeCtrl.text);
        if (condo == null || condo <= 0) {
          _showMessage('Informe o valor do condomínio.');
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
            _showMessage('Informe o nome de todos os custos extras.');
            return false;
          }
          final amount = _parseCurrency(draft.amountCtrl.text);
          if (!draft.priceOnRequest && (amount == null || amount <= 0)) {
            _showMessage(
                'Informe um valor mensal válido para os custos extras.');
            return false;
          }
        }
      }
    }
    return true;
  }

  Future<void> _pickImages() async {
    final remaining = 10 - (_existingImages.length + _newImages.length);
    if (remaining <= 0) return;
    final files =
        await _cloudinary.pickImagesFromGallery(context, max: remaining);
    if (files.isEmpty || !mounted) return;
    setState(() => _newImages.addAll(files));
  }

  Future<void> _cropNewImageAt(int index) async {
    if (index < 0 || index >= _newImages.length) return;
    final cropped = await _cloudinary.cropImageFreely(
      path: _newImages[index].path,
      title: 'Cortar foto do anúncio',
    );
    if (cropped == null || !mounted) return;
    setState(() => _newImages[index] = cropped);
  }

  Future<void> _removeExistingImage(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover foto?'),
        content: const Text('Esta foto será removida do anúncio.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() {
      if (index < _existingPublicIds.length) {
        _imagesToDelete.add(_existingPublicIds[index]);
        _existingPublicIds.removeAt(index);
      }
      _existingImages.removeAt(index);
    });
  }

  Future<void> _nextStep() async {
    if (_currentStep == 0 && !_validateInfo()) return;
    if (_currentStep >= 2) {
      await _submit();
      return;
    }
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    if (!mounted) return;
    setState(() => _currentStep++);
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

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      final user = context.read<UserProvider>().user;
      if (user == null) throw Exception('Você precisa estar logado.');
      if (_imagesToDelete.isNotEmpty) {
        await _cloudinary.deleteImages(_imagesToDelete);
      }

      final newImageUrls = <String>[];
      final newPublicIds = <String>[];
      var failedImageUploads = 0;
      for (int i = 0; i < _newImages.length; i++) {
        final result =
            await _cloudinary.uploadAdPhotoFull(widget.ad.id, _newImages[i], i);
        if (result != null &&
            result['url'] != null &&
            result['publicId'] != null) {
          newImageUrls.add(result['url']!);
          newPublicIds.add(result['publicId']!);
          continue;
        }
        final firebaseUrl =
            await _storage.uploadAdPhoto(widget.ad.id, _newImages[i], i);
        if (firebaseUrl != null && firebaseUrl.trim().isNotEmpty) {
          newImageUrls.add(firebaseUrl);
        } else {
          failedImageUploads++;
        }
      }

      final newPrice = _parseCurrency(_priceCtrl.text) ?? widget.ad.price;
      final hourlyPrice = _parseCurrency(_hourlyPriceCtrl.text);

      await _firestore.updateAd(widget.ad.id, {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'price': newPrice,
        'oldPrice': !_isBuyRequest && newPrice != widget.ad.price
            ? widget.ad.price
            : null,
        'category': _selectedCategory,
        'categoryType': _selectedCategoryType?.trim().isNotEmpty == true
            ? _selectedCategoryType!.trim()
            : null,
        'categoryTypeCustomLabel':
            _customCategoryTypeLabel?.trim().isNotEmpty == true
                ? _customCategoryTypeLabel!.trim()
                : null,
        'type': _selectedType,
        'servicePriceType': _selectedType == AdModel.serviceType
            ? _selectedServicePricing
            : AdModel.servicePriceFixed,
        'hourlyPrice':
            _selectedType == AdModel.serviceType ? hourlyPrice : null,
        'propertyOfferType':
            _isPropertyProduct ? _selectedPropertyOfferType : null,
        'condoFee': _isPropertyProduct &&
                _selectedPropertyOfferType == AdModel.propertyOfferRent &&
                _hasPropertyCondo &&
                !_condoFeeOnRequest
            ? _parseCurrency(_condoFeeCtrl.text)
            : null,
        'condoFeeOnRequest':
            _isPropertyProduct && _hasPropertyCondo && _condoFeeOnRequest,
        'propertyMonthlyCosts': _isPropertyProduct &&
                _selectedPropertyOfferType == AdModel.propertyOfferRent &&
                _hasPropertyExtraCosts
            ? _buildPropertyExtraCosts().map((cost) => cost.toMap()).toList()
            : const [],
        'propertyArea': _isPropertyProduct
            ? double.tryParse(
                _propertyAreaCtrl.text.trim().replaceAll(',', '.'),
              )
            : null,
        'propertyBedrooms': _isPropertyProduct
            ? int.tryParse(_propertyBedroomsCtrl.text.trim())
            : null,
        'propertyBathrooms': _isPropertyProduct
            ? int.tryParse(_propertyBathroomsCtrl.text.trim())
            : null,
        'propertyParkingSpots': _isPropertyProduct
            ? int.tryParse(_propertyParkingCtrl.text.trim())
            : null,
        'propertyFurnishing':
            _isPropertyProduct ? _selectedPropertyFurnishing : null,
        'customAttributes':
            widget.ad.customAttributes.map((item) => item.toMap()).toList(),
        'images': [..._existingImages, ...newImageUrls],
        'imagePublicIds': [..._existingPublicIds, ...newPublicIds],
        'location': _locationCtrl.text.trim().isNotEmpty
            ? _locationCtrl.text.trim()
            : widget.ad.location,
        'km': _isVehicleProduct
            ? int.tryParse(_kmCtrl.text.replaceAll('.', ''))
            : null,
        'vehicleBrand':
            _isVehicleProduct ? _vehicleBrandCtrl.text.trim() : null,
        'vehicleModel':
            _isVehicleProduct ? _vehicleModelCtrl.text.trim() : null,
        'vehicleYear': _isVehicleProduct
            ? int.tryParse(_vehicleYearCtrl.text.trim())
            : null,
        'vehicleOptionals': _isVehicleProduct
            ? List<String>.from(_selectedVehicleOptionals)
            : const [],
        'vehicleColor': _isVehicleProduct ? _selectedVehicleColor : null,
        'vehicleFuelType': _isVehicleProduct ? _selectedVehicleFuelType : null,
        'vehicleOwnerCount': _isVehicleProduct
            ? int.tryParse(_vehicleOwnerCountCtrl.text.trim())
            : null,
        'lat': user.address.lat ?? widget.ad.lat,
        'lng': user.address.lng ?? widget.ad.lng,
        'updatedAt': DateTime.now(),
      });

      if (!mounted) return;
      final successMessage = failedImageUploads == 0
          ? 'Anuncio atualizado com sucesso!'
          : 'Anuncio atualizado, mas $failedImageUploads imagem(ns) falharam no upload.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: AppTheme.facebookBlue,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: AppTheme.error),
      );
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
        title: Text(
          'Editar anúncio',
          style:
              GoogleFonts.roboto(color: textColor, fontWeight: FontWeight.w700),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / 3,
            backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppTheme.facebookBlue),
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _stepInfo(isDark),
          _stepPhotos(isDark),
          _stepSummary(isDark)
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
                      _currentStep == 2 ? 'Salvar alteracoes' : 'Continuar',
                      style: GoogleFonts.roboto(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepInfo(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _title('Detalhes do anúncio', isDark),
        const SizedBox(height: 24),
        _field(
          _titleCtrl,
          'Título',
          _selectedType == AdModel.serviceType
              ? 'Serviço que você quer anunciar'
              : 'Ex: Marca produto e Modelo',
          isDark,
        ),
        const SizedBox(height: 18),
        _field(_descCtrl, 'Descrição', 'Conte mais sobre o anúncio...', isDark,
            maxLines: 4),
        const SizedBox(height: 18),
        _chipSection(
          title: 'Tipo',
          options: const ['Item/Bem', 'Serviço'],
          selectedValues: {
            _selectedType == AdModel.serviceType ? 'Serviço' : 'Item/Bem',
          },
          onTap: (value) => _handleTypeChange(
            value == 'Serviço' ? AdModel.serviceType : AdModel.productType,
          ),
        ),
        const SizedBox(height: 18),
        Text('Categoria',
            style: GoogleFonts.roboto(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _categoryDropdown(isDark),
        if (_availableCategoryTypes.isNotEmpty) ...[
          const SizedBox(height: 18),
          _optionDropdown(
            title: 'Tipo',
            value: _selectedCategoryType,
            options: _availableCategoryTypes,
            isDark: isDark,
            onChanged: _handleCategoryTypeChange,
          ),
        ],
        if (_selectedType == AdModel.serviceType) ...[
          const SizedBox(height: 18),
          _chipSection(
            title: 'Modelo de cobrança',
            options: servicePricingModes
                .map((mode) => servicePricingModeLabels[mode] ?? mode)
                .toList(),
            selectedValues: {
              servicePricingModeLabels[_selectedServicePricing] ??
                  _selectedServicePricing,
            },
            onTap: (value) {
              final entry = servicePricingModeLabels.entries.firstWhere(
                (item) => item.value == value,
                orElse: () =>
                    const MapEntry(AdModel.servicePriceFixed, 'Valor fixo'),
              );
              setState(() => _selectedServicePricing = entry.key);
            },
          ),
        ],
        if (_isPropertyProduct) ...[
          const SizedBox(height: 18),
          _chipSection(
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
          ),
        ],
        const SizedBox(height: 18),
        _field(_priceCtrl, _priceLabel(), '0,00', isDark,
            keyboardType: TextInputType.number),
        if (_selectedType == AdModel.serviceType &&
            _selectedServicePricing == AdModel.servicePriceFixedPlusHourly) ...[
          const SizedBox(height: 18),
          _field(_hourlyPriceCtrl, 'Valor por hora adicional (R\$)', '0,00',
              isDark,
              keyboardType: TextInputType.number),
        ],
        const SizedBox(height: 18),
        _field(_locationCtrl, 'Localização', 'Cidade, Estado', isDark),
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
          _chipSection(
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
          ),
          if (_selectedPropertyOfferType == AdModel.propertyOfferRent) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.blackLight : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      propertyExtraModeLabels[_selectedPropertyExtraMode] ??
                          'Apenas aluguel',
                      style: GoogleFonts.roboto(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: _showPropertyExtraModeDialog,
                    child: const Text('Alterar'),
                  ),
                ],
              ),
            ),
            if (_hasPropertyCondo) ...[
              const SizedBox(height: 18),
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
                  if (_condoFeeOnRequest) _condoFeeCtrl.clear();
                }),
                contentPadding: EdgeInsets.zero,
                title: const Text('A combinar'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
            if (_hasPropertyExtraCosts) ...[
              const SizedBox(height: 18),
              ..._propertyCostDrafts.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.blackLight
                              : Colors.grey.shade100,
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
                                    icon: const Icon(
                                        Icons.delete_outline_rounded),
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
                              onChanged: (value) => setState(() {
                                entry.value.period = value;
                              }),
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
        ],
        if (_isVehicleProduct) ...[
          const SizedBox(height: 18),
          _field(_kmCtrl, 'Quilometragem (KM)', 'Ex: 50000', isDark,
              keyboardType: TextInputType.number),
          const SizedBox(height: 18),
          _field(_vehicleBrandCtrl, 'Marca', 'Ex: Honda', isDark),
          const SizedBox(height: 18),
          _field(_vehicleModelCtrl, 'Modelo', 'Ex: Civic Touring', isDark),
          const SizedBox(height: 18),
          _field(_vehicleYearCtrl, 'Ano', 'Ex: 2020', isDark,
              keyboardType: TextInputType.number),
          const SizedBox(height: 18),
          _field(_vehicleOwnerCountCtrl, 'Número de proprietários', 'Ex: 1',
              isDark,
              keyboardType: TextInputType.number),
          const SizedBox(height: 18),
          _chipSection(
            title: 'Cor do carro',
            options: vehicleColorOptions,
            selectedValues: {
              if (_selectedVehicleColor != null) _selectedVehicleColor!,
            },
            onTap: (value) => _selectVehicleColor(value),
          ),
          const SizedBox(height: 18),
          _chipSection(
            title: 'Tipo de combustível',
            options: vehicleFuelOptions,
            selectedValues: {
              if (_selectedVehicleFuelType != null) _selectedVehicleFuelType!,
            },
            onTap: (value) => _selectVehicleFuel(value),
          ),
          const SizedBox(height: 18),
          _chipSection(
            title: 'Opcionais',
            options: vehicleOptionalSuggestions,
            selectedValues: _selectedVehicleOptionals.toSet(),
            onTap: _handleVehicleOptionalTap,
          ),
        ],
      ],
    );
  }

  Widget _stepPhotos(bool isDark) {
    final totalImages = _existingImages.length + _newImages.length;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _title('Fotos do anúncio', isDark),
        const SizedBox(height: 8),
        Text(
          'Adicione ou remova fotos. Toque nas novas imagens para cortar.',
          style: GoogleFonts.roboto(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ..._existingImages.asMap().entries.map((entry) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        entry.value,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 100,
                          height: 100,
                          color: isDark
                              ? AppTheme.blackLight
                              : Colors.grey.shade200,
                          child: const Icon(Icons.image_not_supported),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removeExistingImage(entry.key),
                        child: const CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.black54,
                          child: Icon(Icons.close, size: 14),
                        ),
                      ),
                    ),
                  ],
                )),
            ..._newImages.asMap().entries.map((entry) => GestureDetector(
                  onTap: () => _cropNewImageAt(entry.key),
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
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _newImages.removeAt(entry.key)),
                          child: const CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.black54,
                            child: Icon(Icons.close, size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
            if (totalImages < 10)
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
                  child: const Icon(
                    Icons.add_a_photo_outlined,
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
    final price = _parseCurrency(_priceCtrl.text) ?? widget.ad.price;
    final hourlyPrice = _parseCurrency(_hourlyPriceCtrl.text);
    final previewAd = AdModel(
      id: widget.ad.id,
      sellerId: widget.ad.sellerId,
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
      intent: widget.ad.intent,
      images: widget.ad.images,
      location: _locationCtrl.text.trim(),
      sellerName: widget.ad.sellerName,
      sellerAvatar: widget.ad.sellerAvatar,
      createdAt: widget.ad.createdAt,
      servicePriceType: _selectedServicePricing,
      hourlyPrice: hourlyPrice,
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
      customAttributes: widget.ad.customAttributes,
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
        _title('Resumo do anúncio', isDark),
        const SizedBox(height: 24),
        Text(
          _titleCtrl.text,
          style: GoogleFonts.roboto(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          previewAd.displayPriceLabel,
          style: GoogleFonts.roboto(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF4A4A4A),
          ),
        ),
        const Divider(height: 36),
        _summaryRow('Categoria', previewAd.displayCategoryLabel, isDark),
        if (previewAd.displayCategoryTypeLabel.isNotEmpty)
          _summaryRow('Subtipo', previewAd.displayCategoryTypeLabel, isDark),
        _summaryRow('Tipo', previewAd.displayTypeLabel, isDark),
        if (_selectedType == AdModel.serviceType)
          _summaryRow(
              'Cobrança', previewAd.displayServicePriceTypeLabel, isDark),
        _summaryRow('Localização', _locationCtrl.text.trim(), isDark),
        if (_isPropertyProduct)
          ...previewAd.propertyDetailEntries
              .where((entry) => entry.key != 'Subtipo')
              .map((entry) => _summaryRow(entry.key, entry.value, isDark)),
        if (_isVehicleProduct)
          ...previewAd.vehicleDetailEntries
              .map((entry) => _summaryRow(entry.key, entry.value, isDark)),
        if (previewAd.customAttributeEntries.isNotEmpty)
          ...previewAd.customAttributeEntries
              .map((entry) => _summaryRow(entry.key, entry.value, isDark)),
      ],
    );
  }

  Widget _summaryRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.roboto(color: Colors.grey)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.roboto(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
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
        Text(_label(label),
            style: GoogleFonts.roboto(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style:
              GoogleFonts.roboto(color: isDark ? Colors.white : Colors.black87),
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

  Widget _chipSection({
    required String title,
    required List<String> options,
    required Set<String> selectedValues,
    required ValueChanged<String> onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.roboto(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Wrap(
          children: options
              .map(
                (option) => Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 8),
                  child: FilterChip(
                    label: Text(_label(option)),
                    selected: selectedValues.contains(option),
                    onSelected: (_) => onTap(option),
                    selectedColor:
                        AppTheme.facebookBlue.withValues(alpha: 0.18),
                    checkmarkColor: AppTheme.facebookBlue,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _categoryDropdown(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.blackLight : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          isExpanded: true,
          dropdownColor: isDark ? AppTheme.blackCard : Colors.white,
          items: _availableCategories
              .map(
                (item) =>
                    DropdownMenuItem(value: item, child: Text(_label(item))),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            _handleCategoryChange(value);
          },
        ),
      ),
    );
  }

  Widget _optionDropdown({
    required String title,
    required String? value,
    required List<String> options,
    required bool isDark,
    required ValueChanged<String> onChanged,
    String Function(String value)? displayLabelBuilder,
  }) {
    if (options.isEmpty) return const SizedBox.shrink();

    final displayValue = value == 'Outro' ? 'Outro +' : value;
    final selectedValue = displayValue != null && options.contains(displayValue)
        ? displayValue
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_label(title),
            style: GoogleFonts.roboto(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.blackLight : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedValue,
              hint: const Text('Selecionar'),
              isExpanded: true,
              dropdownColor: isDark ? AppTheme.blackCard : Colors.white,
              items: options
                  .map(
                    (option) => DropdownMenuItem(
                      value: option,
                      child: Text(
                        displayLabelBuilder?.call(option) ?? _label(option),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (nextValue) {
                if (nextValue == null) return;
                onChanged(nextValue);
              },
            ),
          ),
        ),
      ],
    );
  }

  String _priceLabel() {
    if (_isPropertyProduct) {
      return _selectedPropertyOfferType == AdModel.propertyOfferRent
          ? 'Valor do aluguel (R\$)'
          : 'Valor de venda (R\$)';
    }
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
}
