import 'package:cloud_firestore/cloud_firestore.dart';

enum CommunityAuthorType { user, store }

enum CommunityPostType { aviso, flyer, promocao }

CommunityAuthorType communityAuthorTypeFromValue(String value) {
  return value == 'store'
      ? CommunityAuthorType.store
      : CommunityAuthorType.user;
}

CommunityPostType communityPostTypeFromValue(String value) {
  switch (value) {
    case 'flyer':
      return CommunityPostType.flyer;
    case 'promocao':
      return CommunityPostType.promocao;
    default:
      return CommunityPostType.aviso;
  }
}

String communityAuthorTypeValue(CommunityAuthorType type) {
  return switch (type) {
    CommunityAuthorType.user => 'user',
    CommunityAuthorType.store => 'store',
  };
}

String communityPostTypeValue(CommunityPostType type) {
  return switch (type) {
    CommunityPostType.aviso => 'aviso',
    CommunityPostType.flyer => 'flyer',
    CommunityPostType.promocao => 'promocao',
  };
}

class CommunityPostModel {
  const CommunityPostModel({
    required this.id,
    required this.authorId,
    required this.authorType,
    required this.authorName,
    required this.authorAvatar,
    required this.authorSubtitle,
    required this.content,
    required this.type,
    required this.createdAt,
    this.imageUrl,
    this.imageLabel,
    this.storeId,
    this.authorVerified = false,
    this.authorOfficial = false,
    this.likeUserIds = const [],
    this.likeCount = 0,
    this.commentCount = 0,
  });

  final String id;
  final String authorId;
  final CommunityAuthorType authorType;
  final String authorName;
  final String authorAvatar;
  final String authorSubtitle;
  final String content;
  final CommunityPostType type;
  final DateTime createdAt;
  final String? imageUrl;
  final String? imageLabel;
  final String? storeId;
  final bool authorVerified;
  final bool authorOfficial;
  final List<String> likeUserIds;
  final int likeCount;
  final int commentCount;

  bool isLikedBy(String userId) => likeUserIds.contains(userId);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'authorId': authorId,
      'authorType': communityAuthorTypeValue(authorType),
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'authorSubtitle': authorSubtitle,
      'content': content,
      'type': communityPostTypeValue(type),
      'createdAt': Timestamp.fromDate(createdAt),
      'imageUrl': imageUrl,
      'imageLabel': imageLabel,
      'storeId': storeId,
      'authorVerified': authorVerified,
      'authorOfficial': authorOfficial,
      'likeUserIds': likeUserIds,
      'likeCount': likeCount,
      'commentCount': commentCount,
    };
  }

  factory CommunityPostModel.fromMap(Map<String, dynamic> map) {
    return CommunityPostModel(
      id: map['id'] ?? '',
      authorId: map['authorId'] ?? '',
      authorType: communityAuthorTypeFromValue(map['authorType'] ?? 'user'),
      authorName: map['authorName'] ?? '',
      authorAvatar: map['authorAvatar'] ?? '',
      authorSubtitle: map['authorSubtitle'] ?? '',
      content: map['content'] ?? '',
      type: communityPostTypeFromValue(map['type'] ?? 'aviso'),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      imageUrl: map['imageUrl'],
      imageLabel: map['imageLabel'],
      storeId: map['storeId'],
      authorVerified: map['authorVerified'] ?? false,
      authorOfficial: map['authorOfficial'] ?? false,
      likeUserIds: List<String>.from(map['likeUserIds'] ?? const []),
      likeCount: map['likeCount'] ?? 0,
      commentCount: map['commentCount'] ?? 0,
    );
  }
}

class CommunityCommentModel {
  const CommunityCommentModel({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.message,
    required this.createdAt,
    this.authorVerified = false,
    this.authorOfficial = false,
  });

  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final String message;
  final DateTime createdAt;
  final bool authorVerified;
  final bool authorOfficial;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'postId': postId,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
      'authorVerified': authorVerified,
      'authorOfficial': authorOfficial,
    };
  }

  factory CommunityCommentModel.fromMap(Map<String, dynamic> map) {
    return CommunityCommentModel(
      id: map['id'] ?? '',
      postId: map['postId'] ?? '',
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      authorAvatar: map['authorAvatar'] ?? '',
      message: map['message'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      authorVerified: map['authorVerified'] ?? false,
      authorOfficial: map['authorOfficial'] ?? false,
    );
  }
}
