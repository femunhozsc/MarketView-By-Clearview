import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

class ReviewsScreen extends StatefulWidget {
  final String userId;
  final String title;
  final bool allowReply;

  const ReviewsScreen({
    super.key,
    required this.userId,
    required this.title,
    this.allowReply = false,
  });

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  final _firestore = FirestoreService();
  bool _loading = true;
  List<Map<String, dynamic>> _reviews = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() => _loading = true);
    }
    try {
      final reviews = await _firestore.getReviewsForUser(widget.userId);
      if (!mounted) return;
      setState(() {
        _reviews = reviews;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível carregar as avaliações agora.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _replyToReview(Map<String, dynamic> review) async {
    final controller =
        TextEditingController(text: review['response'] as String? ?? '');
    final response = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Responder avaliação'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Escreva sua resposta',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    await Future.delayed(const Duration(milliseconds: 250));
    controller.dispose();
    if (response == null || response.isEmpty) return;
    await _firestore.replyToReview(review['id'] as String, response);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.black : AppTheme.lightBg;
    final textColor = isDark ? Colors.white : Colors.black87;
    final canReply = widget.allowReply;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.black : Colors.white,
        title: Text(widget.title),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.facebookBlue))
          : _reviews.isEmpty
              ? Center(
                  child: Text('Nenhuma avaliação ainda.',
                      style: GoogleFonts.roboto(color: textColor)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _reviews.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final review = _reviews[index];
                    final rating = (review['rating'] as num?)?.toDouble() ?? 0;
                    final author = review['authorName'] as String? ?? 'Usuário';
                    final comment = review['comment'] as String? ?? '';
                    final response = review['response'] as String? ?? '';
                    final strengths = List<String>.from(
                      review['strengths'] as List<dynamic>? ?? const [],
                    );

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.blackCard : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? AppTheme.blackBorder
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(author,
                              style: GoogleFonts.roboto(
                                  color: textColor,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Row(
                            children: List.generate(
                              5,
                              (star) => Icon(
                                star < rating.round()
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: Colors.amber,
                                size: 18,
                              ),
                            ),
                          ),
                          if (comment.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(comment,
                                style: GoogleFonts.roboto(
                                    color: textColor, height: 1.4)),
                          ],
                          if (strengths.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: strengths
                                  .map(
                                    (strength) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.facebookBlue
                                            .withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        strength,
                                        style: GoogleFonts.roboto(
                                          color: textColor,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                          if (response.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.facebookBlue
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text('Resposta: $response',
                                  style: GoogleFonts.roboto(color: textColor)),
                            ),
                          ] else if (canReply) ...[
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () => _replyToReview(review),
                              child: const Text('Responder avaliação'),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
