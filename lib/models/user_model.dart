import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String firstName;
  final String lastName;
  final String cpf;
  final String email;
  final String phone;
  final String? profilePhoto;
  final AddressModel address;
  final int searchRadius; // km
  final bool hasStore;
  final String? storeId;
  final List<String> favoriteAdIds;
  final Map<String, int> categoryClicks; // Rastreamento de interesses
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.cpf,
    required this.email,
    required this.phone,
    this.profilePhoto,
    required this.address,
    this.searchRadius = 50,
    this.hasStore = false,
    this.storeId,
    this.favoriteAdIds = const [],
    this.categoryClicks = const {},
    required this.createdAt,
  });

  String get fullName => '$firstName $lastName';

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'firstName': firstName,
      'lastName': lastName,
      'cpf': cpf,
      'email': email,
      'phone': phone,
      'profilePhoto': profilePhoto,
      'address': address.toMap(),
      'searchRadius': searchRadius,
      'hasStore': hasStore,
      'storeId': storeId,
      'favoriteAdIds': favoriteAdIds,
      'categoryClicks': categoryClicks,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      cpf: map['cpf'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      profilePhoto: map['profilePhoto'],
      address: AddressModel.fromMap(map['address'] ?? {}),
      searchRadius: map['searchRadius'] ?? 50,
      hasStore: map['hasStore'] ?? false,
      storeId: map['storeId'],
      favoriteAdIds: List<String>.from(map['favoriteAdIds'] ?? []),
      categoryClicks: Map<String, int>.from(
        (map['categoryClicks'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, (v as num).toInt()),
        ) ?? {},
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Retorna categorias ordenadas por número de cliques (mais interessado primeiro)
  List<String> get topCategories {
    if (categoryClicks.isEmpty) return [];
    final sorted = categoryClicks.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => e.key).toList();
  }

  UserModel copyWith({
    String? firstName,
    String? lastName,
    String? cpf,
    String? email,
    String? phone,
    String? profilePhoto,
    AddressModel? address,
    int? searchRadius,
    bool? hasStore,
    String? storeId,
    List<String>? favoriteAdIds,
    Map<String, int>? categoryClicks,
  }) {
    return UserModel(
      uid: uid,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      cpf: cpf ?? this.cpf,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      address: address ?? this.address,
      searchRadius: searchRadius ?? this.searchRadius,
      hasStore: hasStore ?? this.hasStore,
      storeId: storeId ?? this.storeId,
      favoriteAdIds: favoriteAdIds ?? this.favoriteAdIds,
      categoryClicks: categoryClicks ?? this.categoryClicks,
      createdAt: createdAt,
    );
  }
}

class AddressModel {
  final String cep;
  final String street;
  final String number;
  final String complement;
  final String neighborhood;
  final String city;
  final String state;
  final String country;
  final double? lat;
  final double? lng;

  AddressModel({
    this.cep = '',
    this.street = '',
    this.number = '',
    this.complement = '',
    this.neighborhood = '',
    this.city = '',
    this.state = '',
    this.country = 'Brasil',
    this.lat,
    this.lng,
  });

  String get formatted =>
      '$street, $number${complement.isNotEmpty ? ' - $complement' : ''}, $neighborhood, $city - $state';

  Map<String, dynamic> toMap() {
    return {
      'cep': cep,
      'street': street,
      'number': number,
      'complement': complement,
      'neighborhood': neighborhood,
      'city': city,
      'state': state,
      'country': country,
      'lat': lat,
      'lng': lng,
    };
  }

  factory AddressModel.fromMap(Map<String, dynamic> map) {
    return AddressModel(
      cep: map['cep'] ?? '',
      street: map['street'] ?? '',
      number: map['number'] ?? '',
      complement: map['complement'] ?? '',
      neighborhood: map['neighborhood'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      country: map['country'] ?? 'Brasil',
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
    );
  }

  AddressModel copyWith({
    String? cep,
    String? street,
    String? number,
    String? complement,
    String? neighborhood,
    String? city,
    String? state,
    String? country,
    double? lat,
    double? lng,
  }) {
    return AddressModel(
      cep: cep ?? this.cep,
      street: street ?? this.street,
      number: number ?? this.number,
      complement: complement ?? this.complement,
      neighborhood: neighborhood ?? this.neighborhood,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
    );
  }
}