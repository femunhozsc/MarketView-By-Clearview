import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

class StoreModel {
  final String id;
  final String ownerId;
  final String ownerName;
  final String ownerDocument; // cnpj ou cpf
  final String name;
  final String category;
  final String type; // produto ou servico
  final String? logo;
  final String? banner;
  final String description;
  final AddressModel address;
  final DateTime createdAt;
  final bool isActive;
  final double rating;
  final int totalReviews;

  StoreModel({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.ownerDocument,
    required this.name,
    required this.category,
    required this.type,
    this.logo,
    this.banner,
    required this.description,
    required this.address,
    required this.createdAt,
    this.isActive = true,
    this.rating = 0.0,
    this.totalReviews = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'ownerDocument': ownerDocument,
      'name': name,
      'category': category,
      'type': type,
      'logo': logo,
      'banner': banner,
      'description': description,
      'address': address.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
      'rating': rating,
      'totalReviews': totalReviews,
    };
  }

  factory StoreModel.fromMap(Map<String, dynamic> map) {
    return StoreModel(
      id: map['id'] ?? '',
      ownerId: map['ownerId'] ?? '',
      ownerName: map['ownerName'] ?? '',
      ownerDocument: map['ownerDocument'] ?? '',
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      type: map['type'] ?? 'produto',
      logo: map['logo'],
      banner: map['banner'],
      description: map['description'] ?? '',
      address: AddressModel.fromMap(map['address'] ?? {}),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: map['isActive'] ?? true,
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: map['totalReviews'] ?? 0,
    );
  }

  StoreModel copyWith({
    String? id,
    String? ownerId,
    String? ownerName,
    String? ownerDocument,
    String? name,
    String? category,
    String? type,
    String? logo,
    String? banner,
    String? description,
    AddressModel? address,
    DateTime? createdAt,
    bool? isActive,
    double? rating,
    int? totalReviews,
  }) {
    return StoreModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      ownerDocument: ownerDocument ?? this.ownerDocument,
      name: name ?? this.name,
      category: category ?? this.category,
      type: type ?? this.type,
      logo: logo ?? this.logo,
      banner: banner ?? this.banner,
      description: description ?? this.description,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      rating: rating ?? this.rating,
      totalReviews: totalReviews ?? this.totalReviews,
    );
  }
}