import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import 'chat_detail_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _firestore = FirestoreService();
  Future<List<Map<String, dynamic>>>? _pendingReviewsFuture;
  String? _pendingReviewsUid;

  void _ensurePendingReviewsLoaded(String uid) {
    if (_pendingReviewsUid == uid && _pendingReviewsFuture != null) return;
    _pendingReviewsUid = uid;
    _pendingReviewsFuture = _firestore.getPendingReviewRequests(uid);
  }

  void _refreshPendingReviews(String uid) {
    setState(() {
      _pendingReviewsUid = uid;
      _pendingReviewsFuture = _firestore.getPendingReviewRequests(uid);
    });
  }

  bool _isDirectChat(String chatId, String adId) {
    return chatId.startsWith('direct_') || adId.startsWith('direct_');
  }

  String _firstNameOnly(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'Usuario';
    return parts.first;
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) {
      final h = time.hour.toString().padLeft(2, '0');
      final m = time.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    if (diff.inDays == 1) return 'Ontem';
    return '${time.day}/${time.month}';
  }

  double _measureTextWidth(
    BuildContext context,
    String text,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();
    return painter.width;
  }

  String _truncateTextToWidth(
    BuildContext context,
    String text,
    TextStyle style,
    double maxWidth,
  ) {
    if (text.isEmpty || maxWidth <= 0) return '';
    if (_measureTextWidth(context, text, style) <= maxWidth) return text;

    const ellipsis = '...';
    final ellipsisWidth = _measureTextWidth(context, ellipsis, style);
    if (ellipsisWidth >= maxWidth) return ellipsis;

    var result = text;
    while (result.isNotEmpty &&
        _measureTextWidth(context, '$result$ellipsis', style) > maxWidth) {
      result = result.substring(0, result.length - 1).trimRight();
    }

    if (result.isEmpty) return ellipsis;
    return '$result$ellipsis';
  }

  Widget _buildAdaptiveChatTitle(
    BuildContext context, {
    required String productTitle,
    required String fullName,
    required String firstName,
    required Color textColor,
    required Color mutedColor,
  }) {
    final titleStyle = GoogleFonts.roboto(
      color: textColor,
      fontWeight: FontWeight.w700,
    );
    final separatorStyle = GoogleFonts.roboto(
      color: mutedColor,
      fontWeight: FontWeight.w700,
    );
    const separator = ' | ';

    return LayoutBuilder(
      builder: (context, constraints) {
        final fullNameWidth = _measureTextWidth(context, fullName, titleStyle);
        final firstNameWidth =
            _measureTextWidth(context, firstName, titleStyle);
        final separatorWidth =
            _measureTextWidth(context, separator, separatorStyle);

        final canUseFullName =
            fullNameWidth + separatorWidth + 18 <= constraints.maxWidth;
        final chosenName = canUseFullName ? fullName : firstName;
        final chosenNameWidth = canUseFullName ? fullNameWidth : firstNameWidth;
        final titleMaxWidth =
            (constraints.maxWidth - chosenNameWidth - separatorWidth)
                .clamp(0.0, constraints.maxWidth);
        final fittedTitle = _truncateTextToWidth(
          context,
          productTitle,
          titleStyle,
          titleMaxWidth,
        );

        return RichText(
          maxLines: 1,
          overflow: TextOverflow.clip,
          text: TextSpan(
            children: [
              TextSpan(text: fittedTitle, style: titleStyle),
              TextSpan(text: separator, style: separatorStyle),
              TextSpan(text: chosenName, style: titleStyle),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.facebookBlue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Avaliar',
        style: GoogleFonts.roboto(
          color: AppTheme.facebookBlue,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.black : AppTheme.lightBg;
    final border = isDark ? AppTheme.blackBorder : const Color(0xFFE8E8E8);
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = isDark ? AppTheme.whiteMuted : Colors.grey.shade500;
    final user = Provider.of<UserProvider>(context).user;

    if (user == null) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(
          child: Text(
            'Faca login para ver suas mensagens',
            style: GoogleFonts.roboto(color: textColor),
          ),
        ),
      );
    }

    _ensurePendingReviewsLoaded(user.uid);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.black : Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Mensagens',
          style: GoogleFonts.roboto(
            color: textColor,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: border),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _pendingReviewsFuture,
        builder: (context, pendingSnapshot) {
          final pendingRequests =
              pendingSnapshot.data ?? const <Map<String, dynamic>>[];
          final pendingByChatId = <String, Map<String, dynamic>>{
            for (final request in pendingRequests)
              if ((request['chatId'] as String? ?? '').trim().isNotEmpty)
                (request['chatId'] as String).trim(): request,
          };

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chats')
                .where('participants', arrayContains: user.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppTheme.facebookBlue),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Erro ao carregar mensagens',
                    style: GoogleFonts.roboto(color: mutedColor),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              final sortedDocs = List<QueryDocumentSnapshot>.from(docs)
                ..sort((a, b) {
                  final aNeedsReview = pendingByChatId.containsKey(a.id);
                  final bNeedsReview = pendingByChatId.containsKey(b.id);
                  if (aNeedsReview != bNeedsReview) {
                    return aNeedsReview ? -1 : 1;
                  }

                  final aPinned = user.pinnedChatIds.contains(a.id);
                  final bPinned = user.pinnedChatIds.contains(b.id);
                  if (aPinned != bPinned) return aPinned ? -1 : 1;

                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime =
                      (aData['lastMessageTime'] as Timestamp?)?.toDate() ??
                          DateTime(2000);
                  final bTime =
                      (bData['lastMessageTime'] as Timestamp?)?.toDate() ??
                          DateTime(2000);
                  return bTime.compareTo(aTime);
                });

              if (sortedDocs.isEmpty) {
                return _buildEmptyState(mutedColor);
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: sortedDocs.length,
                separatorBuilder: (context, index) =>
                    Divider(height: 1, color: border, indent: 80),
                itemBuilder: (context, index) {
                  final data = sortedDocs[index].data() as Map<String, dynamic>;
                  final chatId = sortedDocs[index].id;
                  final lastMessage = data['lastMessage'] ?? '';
                  final lastTime =
                      (data['lastMessageTime'] as Timestamp?)?.toDate() ??
                          DateTime.now();
                  final adId = (data['adId'] as String? ?? '').trim();
                  final isDirectChat = _isDirectChat(chatId, adId);
                  final isPinned = user.pinnedChatIds.contains(chatId);
                  final needsReview = pendingByChatId.containsKey(chatId);

                  final isBuyer = data['buyerId'] == user.uid;
                  final otherId =
                      isBuyer ? (data['sellerId'] ?? '') : (data['buyerId'] ?? '');

                  if (otherId.isEmpty) return const SizedBox.shrink();

                  return FutureBuilder<List<DocumentSnapshot?>>(
                    future: Future.wait([
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(otherId)
                          .get(),
                      adId.isNotEmpty && !isDirectChat
                          ? FirebaseFirestore.instance
                              .collection('ads')
                              .doc(adId)
                              .get()
                          : Future.value(null),
                    ]),
                    builder: (context, userSnap) {
                      if (userSnap.connectionState == ConnectionState.waiting) {
                        return ListTile(
                          tileColor: isDark ? AppTheme.black : Colors.white,
                          leading: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppTheme.blackLight
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          title: Container(
                            height: 16,
                            width: 120,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppTheme.blackLight
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          subtitle: Container(
                            height: 14,
                            margin: const EdgeInsets.only(top: 4, right: 80),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppTheme.blackLight
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      }

                      if (userSnap.hasError ||
                          !userSnap.hasData ||
                          userSnap.data == null ||
                          userSnap.data!.isEmpty ||
                          userSnap.data!.first?.data() == null) {
                        return const SizedBox.shrink();
                      }

                      final userData =
                          userSnap.data!.first!.data() as Map<String, dynamic>;
                      final adSnapshot =
                          userSnap.data!.length > 1 ? userSnap.data![1] : null;
                      final adData = adSnapshot?.data() as Map<String, dynamic>?;
                      final profilePhoto =
                          (userData['profilePhoto'] as String? ?? '').trim();
                      final firstName = userData['firstName'] as String? ?? '';
                      final lastName = userData['lastName'] as String? ?? '';
                      final adTitle = (data['adTitle'] as String? ?? '').trim();
                      final adImages =
                          (adData?['images'] as List<dynamic>? ?? const [])
                              .whereType<String>()
                              .where((value) => value.trim().isNotEmpty)
                              .toList();
                      final otherName =
                          (firstName.isNotEmpty || lastName.isNotEmpty)
                              ? '$firstName $lastName'.trim()
                              : 'Usuario';
                      final userFirstName = _firstNameOnly(otherName);
                      final productTitle =
                          adTitle.isNotEmpty ? adTitle : 'Conversa';
                      final adImageUrl = adImages.isNotEmpty ? adImages.first : '';

                      return ListTile(
                        tileColor: isDark ? AppTheme.black : Colors.white,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatDetailScreen(
                              chatId: chatId,
                              otherUserId: otherId,
                              otherUserName: otherName,
                              adId:
                                  !isDirectChat && adId.isNotEmpty ? adId : null,
                              sellerId: (data['sellerId'] as String?)
                                          ?.trim()
                                          .isNotEmpty ==
                                      true
                                  ? (data['sellerId'] as String).trim()
                                  : null,
                              adPrice: (adData?['price'] as num?)?.toDouble(),
                              adIntent: adData?['intent'] as String?,
                              adTitle: isDirectChat ? '' : productTitle,
                            ),
                          ),
                        ).then((_) => _refreshPendingReviews(user.uid)),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 56,
                            height: 56,
                            color: isDark
                                ? AppTheme.blackLight
                                : const Color(0xFFF1F3F5),
                            child: isDirectChat
                                ? (profilePhoto.isNotEmpty
                                    ? Image.network(
                                        profilePhoto,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Center(
                                          child: Text(
                                            userFirstName[0].toUpperCase(),
                                            style: GoogleFonts.roboto(
                                              color: AppTheme.facebookBlue,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 20,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          userFirstName[0].toUpperCase(),
                                          style: GoogleFonts.roboto(
                                            color: AppTheme.facebookBlue,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 20,
                                          ),
                                        ),
                                      ))
                                : (adImageUrl.isNotEmpty
                                    ? Image.network(
                                        adImageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Icon(
                                          Icons.image_rounded,
                                          color: mutedColor,
                                        ),
                                      )
                                    : Icon(
                                        Icons.image_rounded,
                                        color: mutedColor,
                                      )),
                          ),
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: isDirectChat
                                  ? Text(
                                      otherName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.roboto(
                                        color: textColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  : _buildAdaptiveChatTitle(
                                      context,
                                      productTitle: productTitle,
                                      fullName: otherName,
                                      firstName: userFirstName,
                                      textColor: textColor,
                                      mutedColor: mutedColor,
                                    ),
                            ),
                            if (needsReview) ...[
                              const SizedBox(width: 6),
                              _buildReviewChip(),
                            ],
                            if (isPinned) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.push_pin_rounded,
                                size: 15,
                                color: AppTheme.facebookBlue,
                              ),
                            ],
                            const SizedBox(width: 8),
                            Text(
                              _formatTime(lastTime),
                              style: GoogleFonts.roboto(
                                color: mutedColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Row(
                          children: [
                            Expanded(
                              child: Text(
                                lastMessage.isEmpty
                                    ? 'Inicie uma conversa'
                                    : lastMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.roboto(color: mutedColor),
                              ),
                            ),
                            if (needsReview) ...[
                              const SizedBox(width: 8),
                              Text(
                                'Voce ainda precisa avaliar',
                                style: GoogleFonts.roboto(
                                  color: AppTheme.facebookBlue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(Color mutedColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 64,
            color: mutedColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhuma conversa ainda',
            style: GoogleFonts.roboto(color: mutedColor, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
