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
  final int searchRadius;
  final bool hasStore;
  final String? storeId;
  final List<String> storeIds;
  final List<String> favoriteAdIds;
  final List<String> favoriteStoreIds;
  final List<String> followingSellerIds;
  final List<String> recentlyViewedAdIds;
  final List<String> pinnedChatIds;
  final Map<String, int> categoryClicks;
  final bool emailVerificationRequired;
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
    this.storeIds = const [],
    this.favoriteAdIds = const [],
    this.favoriteStoreIds = const [],
    this.followingSellerIds = const [],
    this.recentlyViewedAdIds = const [],
    this.pinnedChatIds = const [],
    this.categoryClicks = const {},
    this.emailVerificationRequired = false,
    required this.createdAt,
  });

  String get fullName => '$firstName $lastName'.trim();

  String? get primaryStoreId {
    if (storeId != null && storeId!.isNotEmpty) return storeId;
    if (storeIds.isNotEmpty) return storeIds.first;
    return null;
  }

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
      'storeIds': storeIds,
      'favoriteAdIds': favoriteAdIds,
      'favoriteStoreIds': favoriteStoreIds,
      'followingSellerIds': followingSellerIds,
      'recentlyViewedAdIds': recentlyViewedAdIds,
      'pinnedChatIds': pinnedChatIds,
      'categoryClicks': categoryClicks,
      'emailVerificationRequired': emailVerificationRequired,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final storeIds = List<String>.from(map['storeIds'] ?? []);
    final legacyStoreId = map['storeId'];
    if (legacyStoreId is String &&
        legacyStoreId.isNotEmpty &&
        !storeIds.contains(legacyStoreId)) {
      storeIds.insert(0, legacyStoreId);
    }

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
      hasStore: (map['hasStore'] ?? false) || storeIds.isNotEmpty,
      storeId: (legacyStoreId is String && legacyStoreId.isNotEmpty)
          ? legacyStoreId
          : (storeIds.isNotEmpty ? storeIds.first : null),
      storeIds: storeIds,
      favoriteAdIds: List<String>.from(map['favoriteAdIds'] ?? []),
      favoriteStoreIds: List<String>.from(map['favoriteStoreIds'] ?? []),
      followingSellerIds: List<String>.from(map['followingSellerIds'] ?? []),
      recentlyViewedAdIds: List<String>.from(map['recentlyViewedAdIds'] ?? []),
      pinnedChatIds: List<String>.from(map['pinnedChatIds'] ?? []),
      categoryClicks: Map<String, int>.from(
        (map['categoryClicks'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, (v as num).toInt()),
            ) ??
            {},
      ),
      emailVerificationRequired: map['emailVerificationRequired'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

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
    List<String>? storeIds,
    List<String>? favoriteAdIds,
    List<String>? favoriteStoreIds,
    List<String>? followingSellerIds,
    List<String>? recentlyViewedAdIds,
    List<String>? pinnedChatIds,
    Map<String, int>? categoryClicks,
    bool? emailVerificationRequired,
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
      storeIds: storeIds ?? this.storeIds,
      favoriteAdIds: favoriteAdIds ?? this.favoriteAdIds,
      favoriteStoreIds: favoriteStoreIds ?? this.favoriteStoreIds,
      followingSellerIds: followingSellerIds ?? this.followingSellerIds,
      recentlyViewedAdIds: recentlyViewedAdIds ?? this.recentlyViewedAdIds,
      pinnedChatIds: pinnedChatIds ?? this.pinnedChatIds,
      categoryClicks: categoryClicks ?? this.categoryClicks,
      emailVerificationRequired:
          emailVerificationRequired ?? this.emailVerificationRequired,
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
