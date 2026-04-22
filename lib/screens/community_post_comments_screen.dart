import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/community_post_model.dart';
import '../providers/user_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import 'profile_screen.dart';

class CommunityPostCommentsScreen extends StatefulWidget {
  const CommunityPostCommentsScreen({
    super.key,
    required this.post,
  });

  final CommunityPostModel post;

  @override
  State<CommunityPostCommentsScreen> createState() =>
      _CommunityPostCommentsScreenState();
}

class _CommunityPostCommentsScreenState
    extends State<CommunityPostCommentsScreen> {
  final _firestore = FirestoreService();
  final _messageCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final user = context.read<UserProvider>().user;
    if (user == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
      return;
    }

    final message = _messageCtrl.text.trim();
    if (message.isEmpty) return;

    setState(() => _sending = true);
    try {
      final commentId = DateTime.now().microsecondsSinceEpoch.toString();
      final comment = CommunityCommentModel(
        id: commentId,
        postId: widget.post.id,
        authorId: user.uid,
        authorName: user.fullName.trim().isNotEmpty ? user.fullName : 'Usuario',
        authorAvatar: user.profilePhoto ?? '',
        message: message,
        createdAt: DateTime.now(),
        authorVerified: user.isVerifiedProfile,
        authorOfficial: user.isOfficialProfile,
      );
      await _firestore.addCommunityComment(comment);
      _messageCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar comentario: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.black : const Color(0xFFF3F4F6);
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardColor = isDark ? AppTheme.blackCard : Colors.white;
    final borderColor = isDark ? AppTheme.blackBorder : const Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardColor,
        surfaceTintColor: cardColor,
        elevation: 0,
        title: Text(
          'Comentarios',
          style: GoogleFonts.roboto(
            color: textColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<CommunityCommentModel>>(
              stream: _firestore.streamCommunityComments(widget.post.id),
              builder: (context, snapshot) {
                final comments =
                    snapshot.data ?? const <CommunityCommentModel>[];
                if (comments.isEmpty) {
                  return Center(
                    child: Text(
                      'Seja o primeiro a comentar.',
                      style: GoogleFonts.roboto(color: Colors.grey.shade600),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: comments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CommunityAvatar(
                            imageUrl: comment.authorAvatar,
                            label: comment.authorName,
                            radius: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        comment.authorName,
                                        style: GoogleFonts.roboto(
                                          color: textColor,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    if (comment.authorVerified) ...[
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.verified_rounded,
                                        color: AppTheme.facebookBlue,
                                        size: 16,
                                      ),
                                    ],
                                    if (comment.authorOfficial) ...[
                                      const SizedBox(width: 6),
                                      _OfficialBadge(isDark: isDark),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _relativeTime(comment.createdAt),
                                  style: GoogleFonts.roboto(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  comment.message,
                                  style: GoogleFonts.roboto(
                                    color: textColor,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: BoxDecoration(
              color: cardColor,
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageCtrl,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Escreva um comentario...',
                      filled: true,
                      fillColor: isDark
                          ? AppTheme.blackLight
                          : const Color(0xFFF3F4F6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _sending ? null : _sendComment,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.facebookBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Enviar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityAvatar extends StatelessWidget {
  const _CommunityAvatar({
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
              errorBuilder: (_, __, ___) => _AvatarLetter(
                letter: fallback,
                radius: radius,
              ),
            )
          : _AvatarLetter(letter: fallback, radius: radius),
    );
  }
}

class _AvatarLetter extends StatelessWidget {
  const _AvatarLetter({
    required this.letter,
    required this.radius,
  });

  final String letter;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        letter,
        style: GoogleFonts.roboto(
          color: AppTheme.facebookBlue,
          fontWeight: FontWeight.w900,
          fontSize: radius,
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

String _relativeTime(DateTime value) {
  final diff = DateTime.now().difference(value);
  if (diff.inMinutes < 1) return 'Agora';
  if (diff.inMinutes < 60) return 'Ha ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Ha ${diff.inHours} h';
  if (diff.inDays < 7) return 'Ha ${diff.inDays} d';
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}';
}
