import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/community_post_model.dart';
import '../models/store_model.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../services/cloudinary_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import 'community_post_comments_screen.dart';
import 'profile_screen.dart';
import 'seller_profile_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final _firestore = FirestoreService();
  final _cloudinary = CloudinaryService();
  final _postCtrl = TextEditingController();

  _CommunityFeedTab _selectedTab = _CommunityFeedTab.recommended;
  List<_CommunityIdentity> _identities = [];
  File? _selectedImage;
  bool _publishing = false;
  bool _loadingIdentities = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadIdentities();
    });
  }

  @override
  void dispose() {
    _postCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadIdentities() async {
    final user = context.read<UserProvider>().user;
    if (user == null) {
      if (mounted) {
        setState(() {
          _identities = [];
        });
      }
      return;
    }

    setState(() => _loadingIdentities = true);
    try {
      final stores = await _firestore.getStoresForUser(user.uid);
      final identities = <_CommunityIdentity>[
        _CommunityIdentity.user(user),
        ...stores.map(_CommunityIdentity.store),
      ];
      if (!mounted) return;
      setState(() {
        _identities = identities;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingIdentities = false);
      }
    }
  }

  Future<void> _pickPostImage() async {
    final file = await _cloudinary.pickAndCropImage(
      context: context,
      title: 'Ajustar imagem da publicacao',
    );
    if (!mounted || file == null) return;
    setState(() => _selectedImage = file);
  }

  void _removeSelectedImage() {
    if (_selectedImage == null) return;
    setState(() => _selectedImage = null);
  }

  Future<String?> _uploadPostImage(String postId) async {
    if (_selectedImage == null) return null;

    final cloudinaryUrl =
        await _cloudinary.uploadCommunityPostImage(postId, _selectedImage!);
    if (cloudinaryUrl != null && cloudinaryUrl.trim().isNotEmpty) {
      return cloudinaryUrl;
    }

    throw Exception(
      'Nao foi possivel enviar a imagem para o Cloudinary. Verifique a configuracao do upload preset.',
    );
  }

  Future<void> _publishPost() async {
    final user = context.read<UserProvider>().user;
    if (user == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
      return;
    }

    final content = _postCtrl.text.trim();
    if (content.isEmpty || _publishing || _loadingIdentities) return;

    if (_identities.isEmpty) {
      await _loadIdentities();
      if (!mounted || _identities.isEmpty) return;
    }

    if (_identities.length == 1) {
      await _publishWithIdentity(_identities.first);
      return;
    }

    final identity = await showModalBottomSheet<_CommunityIdentity>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _CommunityPublishIdentitySheet(
        isDark: Theme.of(context).brightness == Brightness.dark,
        identities: _identities,
      ),
    );
    if (identity == null) return;

    await _publishWithIdentity(identity);
  }

  Future<void> _publishWithIdentity(_CommunityIdentity identity) async {
    final content = _postCtrl.text.trim();
    if (content.isEmpty) return;

    setState(() => _publishing = true);
    try {
      final postId = DateTime.now().microsecondsSinceEpoch.toString();
      final imageUrl = await _uploadPostImage(postId);
      final type = _selectedImage != null
          ? CommunityPostType.flyer
          : CommunityPostType.promocao;
      final post = CommunityPostModel(
        id: postId,
        authorId: identity.authorId,
        authorType: identity.authorType,
        authorName: identity.name,
        authorAvatar: identity.avatarUrl,
        authorSubtitle: identity.subtitle,
        content: content,
        type: type,
        createdAt: DateTime.now(),
        imageUrl: imageUrl,
        imageLabel: type == CommunityPostType.flyer
            ? 'Encarte'
            : type == CommunityPostType.promocao
                ? 'Promocao'
                : 'Aviso',
        storeId: identity.storeId,
        authorVerified: identity.isVerified,
        authorOfficial: identity.isOfficial,
        likeUserIds: const [],
        likeCount: 0,
        commentCount: 0,
      );
      await _firestore.createCommunityPost(post);
      _postCtrl.clear();
      setState(() {
        _selectedImage = null;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      final message = e.code == 'permission-denied'
          ? 'O Firestore bloqueou a publicacao. Revise as rules de community_posts.'
          : 'Erro do Firestore ao publicar: ${e.message ?? e.code}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao publicar: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _publishing = false);
      }
    }
  }

  void _ensureLoggedIn(VoidCallback action) {
    final user = context.read<UserProvider>().user;
    if (user == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
      return;
    }
    action();
  }

  bool _canDeletePost(CommunityPostModel post, UserModel? user) {
    if (user == null) return false;
    if (post.authorType == CommunityAuthorType.user) {
      return post.authorId == user.uid;
    }

    final storeId = post.storeId?.trim() ?? '';
    if (storeId.isEmpty) return false;
    return user.storeIds.contains(storeId);
  }

  Future<void> _confirmDeletePost(CommunityPostModel post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir publicacao'),
        content: const Text(
          'Tem certeza que deseja excluir esta publicacao? Essa acao nao pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _firestore.deleteCommunityPost(post.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publicacao excluida com sucesso.')),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.code == 'permission-denied'
                ? 'Voce nao tem permissao para excluir esta publicacao.'
                : 'Erro do Firestore ao excluir: ${e.message ?? e.code}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir publicacao: $e')),
      );
    }
  }

  Future<void> _showPostActions(
    BuildContext anchorContext,
    CommunityPostModel post,
    UserModel? user,
  ) async {
    final canDelete = _canDeletePost(post, user);
    if (!canDelete) return;

    final result = await showModalBottomSheet<String>(
      context: anchorContext,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: const Text('Excluir publicacao'),
              textColor: Colors.red,
              iconColor: Colors.red,
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (result == 'delete' && mounted) {
      await _confirmDeletePost(post);
    }
  }

  void _openImageViewer(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CommunityImageViewer(imageUrl: imageUrl),
      ),
    );
  }

  List<CommunityPostModel> _visiblePostsForTab(
    List<CommunityPostModel> posts,
    UserModel? user,
  ) {
    final followingIds = user?.followingSellerIds.toSet() ?? const <String>{};

    if (_selectedTab == _CommunityFeedTab.following) {
      return posts
          .where((post) => followingIds.contains(post.authorId))
          .toList(growable: false);
    }

    if (followingIds.isEmpty) {
      return posts;
    }

    final followed = <CommunityPostModel>[];
    final notFollowed = <CommunityPostModel>[];
    for (final post in posts) {
      if (followingIds.contains(post.authorId)) {
        followed.add(post);
      } else {
        notFollowed.add(post);
      }
    }

    if (followed.isEmpty || notFollowed.isEmpty) {
      return [...notFollowed, ...followed];
    }

    final mixed = <CommunityPostModel>[];
    final maxLength = followed.length > notFollowed.length
        ? followed.length
        : notFollowed.length;
    for (var i = 0; i < maxLength; i++) {
      if (i < notFollowed.length) {
        mixed.add(notFollowed[i]);
      }
      if (i < followed.length) {
        mixed.add(followed[i]);
      }
    }
    return mixed;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.black : const Color(0xFFF3F4F6);
    final user = context.watch<UserProvider>().user;

    return Scaffold(
      backgroundColor: bg,
      body: StreamBuilder<List<CommunityPostModel>>(
        stream: _firestore.streamCommunityPosts(),
        builder: (context, snapshot) {
          final posts = snapshot.data ?? const <CommunityPostModel>[];
          final visiblePosts = _visiblePostsForTab(posts, user);
          return RefreshIndicator(
            onRefresh: _loadIdentities,
            color: AppTheme.facebookBlue,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 90),
              children: [
                _CommunityHeaderCard(
                  isDark: isDark,
                  onNotificationsTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notificacoes da comunidade em breve.'),
                      ),
                    );
                  },
                ),
                _CommunityComposerCard(
                  isDark: isDark,
                  currentUser: user,
                  controller: _postCtrl,
                  selectedImage: _selectedImage,
                  publishing: _publishing,
                  onPickImage: () => _ensureLoggedIn(_pickPostImage),
                  onRemoveImage: _removeSelectedImage,
                  onPreviewImageTap: _selectedImage == null
                      ? null
                      : () => _openImageViewer(_selectedImage!.path),
                  onPublish: _publishPost,
                  onLoginTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  ),
                ),
                _CommunityFeedTabs(
                  isDark: isDark,
                  selectedTab: _selectedTab,
                  onTabSelected: (tab) => setState(() => _selectedTab = tab),
                ),
                if (visiblePosts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: _CommunityEmptyState(
                      isDark: isDark,
                      selectedTab: _selectedTab,
                      hasFollowing: (user?.followingSellerIds.length ?? 0) > 0,
                    ),
                  )
                else
                  ...visiblePosts.map(
                    (post) => _CommunityPostCard(
                      post: post,
                      isDark: isDark,
                      currentUserId: user?.uid ?? '',
                      onAuthorTap: () {
                        if (post.authorType == CommunityAuthorType.store &&
                            (post.storeId?.trim().isNotEmpty ?? false)) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SellerProfileScreen(
                                sellerId: post.authorId,
                                sellerName: post.authorName,
                                storeId: post.storeId,
                              ),
                            ),
                          );
                          return;
                        }

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SellerProfileScreen(
                              sellerId: post.authorId,
                              sellerName: post.authorName,
                            ),
                          ),
                        );
                      },
                      onOpenComments: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CommunityPostCommentsScreen(post: post),
                        ),
                      ),
                      onLikeTap: () => _ensureLoggedIn(
                        () => _firestore.toggleCommunityPostLike(
                          postId: post.id,
                          userId: user!.uid,
                        ),
                      ),
                      onMoreTap: () => _showPostActions(context, post, user),
                      canShowMore: _canDeletePost(post, user),
                      onImageTap: (post.imageUrl?.trim().isNotEmpty ?? false)
                          ? () => _openImageViewer(post.imageUrl!)
                          : null,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CommunityHeaderCard extends StatelessWidget {
  const _CommunityHeaderCard({
    required this.isDark,
    required this.onNotificationsTap,
  });

  final bool isDark;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? AppTheme.blackCard : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      color: cardColor,
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Comunidade',
              style: GoogleFonts.roboto(
                color: textColor,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Material(
            color: isDark ? AppTheme.blackLight : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onNotificationsTap,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.notifications_none_rounded, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityComposerCard extends StatelessWidget {
  const _CommunityComposerCard({
    required this.isDark,
    required this.currentUser,
    required this.controller,
    required this.selectedImage,
    required this.publishing,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.onPreviewImageTap,
    required this.onPublish,
    required this.onLoginTap,
  });

  final bool isDark;
  final UserModel? currentUser;
  final TextEditingController controller;
  final File? selectedImage;
  final bool publishing;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;
  final VoidCallback? onPreviewImageTap;
  final VoidCallback onPublish;
  final VoidCallback onLoginTap;

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? AppTheme.blackCard : Colors.white;
    final borderColor = isDark ? AppTheme.blackBorder : const Color(0xFFE5E7EB);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      color: cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Avatar(
                imageUrl: currentUser?.profilePhoto ?? '',
                label: currentUser?.firstName ?? 'U',
                radius: 17,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  enabled: currentUser != null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Compartilhe uma promocao aqui...',
                    filled: true,
                    fillColor:
                        isDark ? AppTheme.blackLight : const Color(0xFFF3F4F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: const BorderSide(
                        color: AppTheme.facebookBlue,
                        width: 1.2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (currentUser == null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onLoginTap,
                child: const Text('Entrar para publicar'),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            if (selectedImage != null) ...[
              const SizedBox(height: 2),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: onPreviewImageTap,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 360),
                        child: SizedBox(
                          width: double.infinity,
                          child: Image.file(
                            selectedImage!,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Material(
                        color: Colors.red.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(999),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: onRemoveImage,
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                TextButton.icon(
                  onPressed: onPickImage,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.facebookBlue,
                    backgroundColor: AppTheme.facebookBlue.withValues(
                      alpha: isDark ? 0.16 : 0.08,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Adicionar Encarte'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: publishing ? null : onPublish,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF111827),
                  ),
                  child: publishing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Publicar'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CommunityPostCard extends StatelessWidget {
  const _CommunityPostCard({
    required this.post,
    required this.isDark,
    required this.currentUserId,
    required this.onAuthorTap,
    required this.onOpenComments,
    required this.onLikeTap,
    required this.onMoreTap,
    required this.canShowMore,
    required this.onImageTap,
  });

  final CommunityPostModel post;
  final bool isDark;
  final String currentUserId;
  final VoidCallback onAuthorTap;
  final VoidCallback onOpenComments;
  final VoidCallback onLikeTap;
  final VoidCallback onMoreTap;
  final bool canShowMore;
  final VoidCallback? onImageTap;

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? AppTheme.blackCard : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final liked = currentUserId.isNotEmpty && post.isLikedBy(currentUserId);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      color: cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onAuthorTap,
                  child: _Avatar(
                    imageUrl: post.authorAvatar,
                    label: post.authorName,
                    radius: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: onAuthorTap,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                post.authorName,
                                style: GoogleFonts.roboto(
                                  color: textColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (post.authorVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified_rounded,
                                color: AppTheme.facebookBlue,
                                size: 16,
                              ),
                            ],
                            if (post.authorOfficial) ...[
                              const SizedBox(width: 6),
                              _OfficialBadge(isDark: isDark),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_relativeTime(post.createdAt)} • ${post.authorSubtitle}',
                          style: GoogleFonts.roboto(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (canShowMore)
                  IconButton(
                    onPressed: onMoreTap,
                    icon: const Icon(Icons.more_horiz_rounded),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.content,
                  style: GoogleFonts.roboto(
                    color: textColor,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                if (post.authorType == CommunityAuthorType.store &&
                    (post.storeId?.trim().isNotEmpty ?? false)) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: onAuthorTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.facebookBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Ver loja',
                        style: GoogleFonts.roboto(
                          color: AppTheme.facebookBlue,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (post.imageUrl?.trim().isNotEmpty ?? false)
            GestureDetector(
              onTap: onImageTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 520),
                child: SizedBox(
                  width: double.infinity,
                  child: Image.network(
                    post.imageUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      height: 220,
                      color: isDark
                          ? AppTheme.blackLight
                          : const Color(0xFFF3F4F6),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.image_outlined,
                        color: AppTheme.facebookBlue,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: [
                _ActionButton(
                  icon: liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: '${post.likeCount}',
                  color: liked ? Colors.red : Colors.grey.shade600,
                  onTap: onLikeTap,
                ),
                const SizedBox(width: 18),
                _ActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: '${post.commentCount}',
                  color: Colors.grey.shade600,
                  onTap: onOpenComments,
                ),
                const Spacer(),
                _ActionButton(
                  icon: Icons.share_outlined,
                  label: 'Compartilhar',
                  color: Colors.grey.shade600,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Compartilhamento da comunidade em breve.'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _CommunityFeedTab { recommended, following }

class _CommunityFeedTabs extends StatelessWidget {
  const _CommunityFeedTabs({
    required this.isDark,
    required this.selectedTab,
    required this.onTabSelected,
  });

  final bool isDark;
  final _CommunityFeedTab selectedTab;
  final ValueChanged<_CommunityFeedTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? AppTheme.blackCard : Colors.white;
    final inactiveColor = isDark ? Colors.white70 : Colors.black54;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      color: cardColor,
      child: Row(
        children: [
          _CommunityFeedTabButton(
            label: 'Recomendado',
            selected: selectedTab == _CommunityFeedTab.recommended,
            inactiveColor: inactiveColor,
            onTap: () => onTabSelected(_CommunityFeedTab.recommended),
          ),
          const SizedBox(width: 10),
          _CommunityFeedTabButton(
            label: 'Seguindo',
            selected: selectedTab == _CommunityFeedTab.following,
            inactiveColor: inactiveColor,
            onTap: () => onTabSelected(_CommunityFeedTab.following),
          ),
        ],
      ),
    );
  }
}

class _CommunityFeedTabButton extends StatelessWidget {
  const _CommunityFeedTabButton({
    required this.label,
    required this.selected,
    required this.inactiveColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.facebookBlue.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: GoogleFonts.roboto(
            color: selected ? AppTheme.facebookBlue : inactiveColor,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _CommunityPublishIdentitySheet extends StatefulWidget {
  const _CommunityPublishIdentitySheet({
    required this.isDark,
    required this.identities,
  });

  final bool isDark;
  final List<_CommunityIdentity> identities;

  @override
  State<_CommunityPublishIdentitySheet> createState() =>
      _CommunityPublishIdentitySheetState();
}

class _CommunityImageViewer extends StatelessWidget {
  const _CommunityImageViewer({required this.imageUrl});

  final String imageUrl;

  bool get _isLocalFile =>
      imageUrl.startsWith('/') ||
      imageUrl.contains(':\\') ||
      imageUrl.startsWith('file:');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4.5,
          child: _isLocalFile
              ? Image.file(
                  File(imageUrl.replaceFirst('file://', '')),
                  fit: BoxFit.contain,
                )
              : Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 56,
                  ),
                ),
        ),
      ),
    );
  }
}

class _CommunityPublishIdentitySheetState
    extends State<_CommunityPublishIdentitySheet> {
  _CommunityIdentity? _selectedIdentity;

  @override
  void initState() {
    super.initState();
    if (widget.identities.isNotEmpty) {
      _selectedIdentity = widget.identities.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final sheetColor = isDark ? AppTheme.blackCard : Colors.white;
    final borderColor = isDark ? AppTheme.blackBorder : const Color(0xFFE5E7EB);
    final textColor = isDark ? Colors.white : Colors.black87;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: sheetColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Publicar como',
              style: GoogleFonts.roboto(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Escolha o perfil que vai aparecer neste aviso.',
              style: GoogleFonts.roboto(
                color: Colors.grey.shade600,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            ...widget.identities.map(
              (identity) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () => setState(() => _selectedIdentity = identity),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _selectedIdentity?.key == identity.key
                          ? AppTheme.facebookBlue.withValues(
                              alpha: isDark ? 0.18 : 0.08,
                            )
                          : sheetColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _selectedIdentity?.key == identity.key
                            ? AppTheme.facebookBlue
                            : borderColor,
                      ),
                    ),
                    child: Row(
                      children: [
                        _Avatar(
                          imageUrl: identity.avatarUrl,
                          label: identity.name,
                          radius: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      identity.name,
                                      style: GoogleFonts.roboto(
                                        color: textColor,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  if (identity.isVerified) ...[
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.verified_rounded,
                                      color: AppTheme.facebookBlue,
                                      size: 16,
                                    ),
                                  ],
                                  if (identity.isOfficial) ...[
                                    const SizedBox(width: 6),
                                    _OfficialBadge(isDark: isDark),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                identity.subtitle,
                                style: GoogleFonts.roboto(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _selectedIdentity?.key == identity.key
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: _selectedIdentity?.key == identity.key
                              ? AppTheme.facebookBlue
                              : Colors.grey.shade500,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selectedIdentity == null
                    ? null
                    : () => Navigator.pop(context, _selectedIdentity),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF111827),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text('Publicar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.roboto(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityEmptyState extends StatelessWidget {
  const _CommunityEmptyState({
    required this.isDark,
    required this.selectedTab,
    required this.hasFollowing,
  });

  final bool isDark;
  final _CommunityFeedTab selectedTab;
  final bool hasFollowing;

  @override
  Widget build(BuildContext context) {
    final title = selectedTab == _CommunityFeedTab.following
        ? hasFollowing
            ? 'Nenhuma publicacao de perfis seguidos'
            : 'Voce ainda nao segue ninguem'
        : 'A comunidade ainda esta vazia';
    final subtitle = selectedTab == _CommunityFeedTab.following
        ? hasFollowing
            ? 'Quando esses perfis publicarem algo, vai aparecer aqui.'
            : 'Siga pessoas e lojas para acompanhar as novidades nesta aba.'
        : 'Publique avisos, flyers, promocoes e novidades para movimentar a cidade.';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.blackCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.blackBorder : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.campaign_outlined,
            color: AppTheme.facebookBlue,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.roboto(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.roboto(
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.imageUrl,
    required this.label,
    required this.radius,
  });

  final String imageUrl;
  final String label;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fallback = label.isNotEmpty ? label[0].toUpperCase() : 'C';
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.facebookBlue.withValues(alpha: 0.12),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.trim().isNotEmpty
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Text(
                  fallback,
                  style: GoogleFonts.roboto(
                    color: AppTheme.facebookBlue,
                    fontWeight: FontWeight.w900,
                    fontSize: radius,
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                fallback,
                style: GoogleFonts.roboto(
                  color: AppTheme.facebookBlue,
                  fontWeight: FontWeight.w900,
                  fontSize: radius,
                ),
              ),
            ),
    );
  }
}

class _OfficialBadge extends StatelessWidget {
  const _OfficialBadge({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? Colors.white : Colors.black87,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'OFICIAL',
        style: GoogleFonts.roboto(
          color: isDark ? Colors.black87 : Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CommunityIdentity {
  const _CommunityIdentity({
    required this.key,
    required this.authorId,
    required this.authorType,
    required this.name,
    required this.subtitle,
    required this.avatarUrl,
    required this.isVerified,
    required this.isOfficial,
    this.storeId,
  });

  final String key;
  final String authorId;
  final CommunityAuthorType authorType;
  final String name;
  final String subtitle;
  final String avatarUrl;
  final bool isVerified;
  final bool isOfficial;
  final String? storeId;

  factory _CommunityIdentity.user(UserModel user) {
    final subtitle = user.address.city.trim().isNotEmpty
        ? '${user.address.city} - ${user.address.state}'
        : 'Morador da comunidade';
    return _CommunityIdentity(
      key: 'user:${user.uid}',
      authorId: user.uid,
      authorType: CommunityAuthorType.user,
      name: user.fullName.trim().isNotEmpty ? user.fullName : 'Usuario',
      subtitle: subtitle,
      avatarUrl: user.profilePhoto ?? '',
      isVerified: user.isVerifiedProfile,
      isOfficial: user.isOfficialProfile,
    );
  }

  factory _CommunityIdentity.store(StoreModel store) {
    final subtitle = store.address.city.trim().isNotEmpty
        ? store.address.city
        : 'Perfil comercial';
    return _CommunityIdentity(
      key: 'store:${store.id}',
      authorId: store.ownerId,
      authorType: CommunityAuthorType.store,
      name: store.name,
      subtitle: subtitle,
      avatarUrl: store.logo ?? '',
      isVerified: store.isVerifiedProfile,
      isOfficial: store.isOfficialProfile,
      storeId: store.id,
    );
  }
}

String _relativeTime(DateTime value) {
  final diff = DateTime.now().difference(value);
  if (diff.inMinutes < 1) return 'Agora';
  if (diff.inMinutes < 60) return 'Ha ${diff.inMinutes} minutos';
  if (diff.inHours < 24) return 'Ha ${diff.inHours} horas';
  if (diff.inDays < 7) return 'Ha ${diff.inDays} dias';
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}';
}
