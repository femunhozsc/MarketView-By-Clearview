import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_model.dart';

class StoreModel {
  final String id;
  final String ownerId;
  final String ownerName;
  final String ownerDocument;
  final String name;
  final String category;
  final String type;
  final String? logo;
  final String? banner;
  final String description;
  final AddressModel address;
  final DateTime createdAt;
  final bool isVerifiedProfile;
  final bool isOfficialProfile;
  final bool isActive;
  final double rating;
  final int totalReviews;
  final bool hasDelivery;
  final bool hasInstallments;
  final String accessUsername;
  final List<String> memberUserIds;
  final List<String> adminUserIds;
  final List<StoreMember> members;
  final StoreAccessInvite? activeInvite;

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
    this.isVerifiedProfile = false,
    this.isOfficialProfile = true,
    this.isActive = true,
    this.rating = 0.0,
    this.totalReviews = 0,
    this.hasDelivery = false,
    this.hasInstallments = false,
    this.accessUsername = '',
    this.memberUserIds = const [],
    this.adminUserIds = const [],
    this.members = const [],
    this.activeInvite,
  });

  bool isAdmin(String userId) => adminUserIds.contains(userId);

  bool isMember(String userId) => memberUserIds.contains(userId);

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
      'isVerifiedProfile': isVerifiedProfile,
      'isOfficialProfile': isOfficialProfile,
      'isActive': isActive,
      'rating': rating,
      'totalReviews': totalReviews,
      'hasDelivery': hasDelivery,
      'hasInstallments': hasInstallments,
      'accessUsername': accessUsername,
      'memberUserIds': memberUserIds,
      'adminUserIds': adminUserIds,
      'members': members.map((member) => member.toMap()).toList(),
      'activeInvite': activeInvite?.toMap(),
    };
  }

  factory StoreModel.fromMap(Map<String, dynamic> map) {
    final ownerId = map['ownerId'] ?? '';
    final legacyStoreId = map['storeId'];
    final members = (map['members'] as List<dynamic>? ?? [])
        .map((item) => StoreMember.fromMap(Map<String, dynamic>.from(item)))
        .toList();
    final memberUserIds = List<String>.from(
      map['memberUserIds'] ??
          members.map((member) => member.userId).toList() ??
          [ownerId],
    );
    final adminUserIds = List<String>.from(
      map['adminUserIds'] ?? [ownerId],
    );

    return StoreModel(
      id: map['id'] ?? legacyStoreId ?? '',
      ownerId: ownerId,
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
      isVerifiedProfile: map['isVerifiedProfile'] ?? false,
      isOfficialProfile: map['isOfficialProfile'] ?? true,
      isActive: map['isActive'] ?? true,
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: map['totalReviews'] ?? 0,
      hasDelivery: map['hasDelivery'] ?? false,
      hasInstallments: map['hasInstallments'] ?? false,
      accessUsername: map['accessUsername'] ?? '',
      memberUserIds: memberUserIds.isEmpty ? [ownerId] : memberUserIds,
      adminUserIds: adminUserIds.isEmpty ? [ownerId] : adminUserIds,
      members: members.isEmpty
          ? [
              StoreMember(
                userId: ownerId,
                name: map['ownerName'] ?? '',
                role: StoreMemberRole.admin,
                joinedAt: (map['createdAt'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
              ),
            ]
          : members,
      activeInvite: map['activeInvite'] == null
          ? null
          : StoreAccessInvite.fromMap(
              Map<String, dynamic>.from(map['activeInvite']),
            ),
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
    bool? isVerifiedProfile,
    bool? isOfficialProfile,
    bool? isActive,
    double? rating,
    int? totalReviews,
    bool? hasDelivery,
    bool? hasInstallments,
    String? accessUsername,
    List<String>? memberUserIds,
    List<String>? adminUserIds,
    List<StoreMember>? members,
    StoreAccessInvite? activeInvite,
    bool clearActiveInvite = false,
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
      isVerifiedProfile: isVerifiedProfile ?? this.isVerifiedProfile,
      isOfficialProfile: isOfficialProfile ?? this.isOfficialProfile,
      isActive: isActive ?? this.isActive,
      rating: rating ?? this.rating,
      totalReviews: totalReviews ?? this.totalReviews,
      hasDelivery: hasDelivery ?? this.hasDelivery,
      hasInstallments: hasInstallments ?? this.hasInstallments,
      accessUsername: accessUsername ?? this.accessUsername,
      memberUserIds: memberUserIds ?? this.memberUserIds,
      adminUserIds: adminUserIds ?? this.adminUserIds,
      members: members ?? this.members,
      activeInvite:
          clearActiveInvite ? null : activeInvite ?? this.activeInvite,
    );
  }
}

enum StoreMemberRole {
  admin,
  member;

  String get value => switch (this) {
        StoreMemberRole.admin => 'admin',
        StoreMemberRole.member => 'member',
      };

  static StoreMemberRole fromValue(String value) {
    return value == 'admin' ? StoreMemberRole.admin : StoreMemberRole.member;
  }
}

class StoreMember {
  final String userId;
  final String name;
  final String? email;
  final String? avatarUrl;
  final StoreMemberRole role;
  final DateTime joinedAt;

  const StoreMember({
    required this.userId,
    required this.name,
    this.email,
    this.avatarUrl,
    required this.role,
    required this.joinedAt,
  });

  bool get isAdmin => role == StoreMemberRole.admin;

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'email': email,
      'avatarUrl': avatarUrl,
      'role': role.value,
      'joinedAt': Timestamp.fromDate(joinedAt),
    };
  }

  factory StoreMember.fromMap(Map<String, dynamic> map) {
    return StoreMember(
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      email: map['email'],
      avatarUrl: map['avatarUrl'],
      role: StoreMemberRole.fromValue(map['role'] ?? 'member'),
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  StoreMember copyWith({
    String? userId,
    String? name,
    String? email,
    String? avatarUrl,
    StoreMemberRole? role,
    DateTime? joinedAt,
  }) {
    return StoreMember(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
}

class StoreAccessInvite {
  final String username;
  final String code;
  final DateTime expiresAt;
  final String createdByUserId;

  const StoreAccessInvite({
    required this.username,
    required this.code,
    required this.expiresAt,
    required this.createdByUserId,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'code': code,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'createdByUserId': createdByUserId,
    };
  }

  factory StoreAccessInvite.fromMap(Map<String, dynamic> map) {
    return StoreAccessInvite(
      username: map['username'] ?? '',
      code: map['code'] ?? '',
      expiresAt: (map['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdByUserId: map['createdByUserId'] ?? '',
    );
  }
}
