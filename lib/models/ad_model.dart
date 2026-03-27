import 'package:cloud_firestore/cloud_firestore.dart';

class AdModel {
  final String id;
  final String sellerId; // uid do usuário que criou o anúncio
  final String title;
  final String description;
  final double price;
  final String category;
  final String type; // produto, servico
  final List<String> images;
  final List<String> imagePublicIds; // IDs do Cloudinary para deleção
  final String location;
  final String sellerName;
  final String sellerAvatar; // inicial do nome
  final DateTime createdAt;
  final int? km; // apenas para veículos
  final String? storeId; // ID da loja se for um anúncio de loja
  final String? storeName;
  final String? storeLogo;
  final double? oldPrice; // preço anterior (para exibir riscado)
  final int clickCount; // contador de cliques para popularidade

  AdModel({
    required this.id,
    this.sellerId = '',
    required this.title,
    required this.description,
    required this.price,
    required this.category,
    required this.type,
    required this.images,
    this.imagePublicIds = const [],
    required this.location,
    required this.sellerName,
    this.sellerAvatar = '',
    required this.createdAt,
    this.km,
    this.storeId,
    this.storeName,
    this.storeLogo,
    this.oldPrice,
    this.clickCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sellerId': sellerId,
      'title': title,
      'description': description,
      'price': price,
      'category': category,
      'type': type,
      'images': images,
      'imagePublicIds': imagePublicIds,
      'location': location,
      'sellerName': sellerName,
      'sellerAvatar': sellerAvatar,
      'createdAt': Timestamp.fromDate(createdAt),
      'km': km,
      'storeId': storeId,
      'storeName': storeName,
      'storeLogo': storeLogo,
      'oldPrice': oldPrice,
      'clickCount': clickCount,
    };
  }

  factory AdModel.fromMap(Map<String, dynamic> map) {
    return AdModel(
      id: map['id'] ?? '',
      sellerId: map['sellerId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] ?? '',
      type: map['type'] ?? 'produto',
      images: List<String>.from(map['images'] ?? []),
      imagePublicIds: List<String>.from(map['imagePublicIds'] ?? []),
      location: map['location'] ?? '',
      sellerName: map['sellerName'] ?? '',
      sellerAvatar: map['sellerAvatar'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      km: map['km'] as int?,
      storeId: map['storeId'],
      storeName: map['storeName'],
      storeLogo: map['storeLogo'],
      oldPrice: (map['oldPrice'] as num?)?.toDouble(),
      clickCount: (map['clickCount'] as num?)?.toInt() ?? 0,
    );
  }

  AdModel copyWith({
    String? id,
    String? sellerId,
    String? title,
    String? description,
    double? price,
    String? category,
    String? type,
    List<String>? images,
    List<String>? imagePublicIds,
    String? location,
    String? sellerName,
    String? sellerAvatar,
    DateTime? createdAt,
    int? km,
    String? storeId,
    String? storeName,
    String? storeLogo,
    double? oldPrice,
    int? clickCount,
  }) {
    return AdModel(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      type: type ?? this.type,
      images: images ?? this.images,
      imagePublicIds: imagePublicIds ?? this.imagePublicIds,
      location: location ?? this.location,
      sellerName: sellerName ?? this.sellerName,
      sellerAvatar: sellerAvatar ?? this.sellerAvatar,
      createdAt: createdAt ?? this.createdAt,
      km: km ?? this.km,
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      storeLogo: storeLogo ?? this.storeLogo,
      oldPrice: oldPrice ?? this.oldPrice,
      clickCount: clickCount ?? this.clickCount,
    );
  }
}

List<String> categories = [
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
  'Outros',
];

// Dados de exemplo para o feed
List<AdModel> sampleAds = [
  AdModel(
    id: '1',
    title: 'iPhone 14 Pro Max 256GB',
    description: 'Excelente estado, sem arranhões, com caixa original e todos os acessórios. Bateria 98%. Comprado há 8 meses.',
    price: 4500.00,
    category: 'Eletrônicos',
    type: 'produto',
    images: [],
    location: 'Curitiba, PR',
    sellerName: 'Carlos Silva',
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  AdModel(
    id: '2',
    title: 'Consultoria de Design de Interiores',
    description: 'Transforme seu ambiente com uma consultoria personalizada. Projetos 3D e escolha de materiais.',
    price: 350.00,
    category: 'Design',
    type: 'servico',
    images: [],
    location: 'São Paulo, SP',
    sellerName: 'Ana Paula',
    createdAt: DateTime.now().subtract(const Duration(hours: 5)),
  ),
  AdModel(
    id: '3',
    title: 'Honda Civic 2020 Touring',
    description: 'Único dono, todas as revisões na concessionária. Teto solar, bancos em couro, som premium.',
    price: 125000.00,
    category: 'Veículos',
    type: 'produto',
    images: [],
    location: 'Belo Horizonte, MG',
    sellerName: 'Marcos Oliveira',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    km: 35000,
  ),
];
