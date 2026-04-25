import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import 'support_chat_screen.dart';

class SupportHistoryScreen extends StatelessWidget {
  const SupportHistoryScreen({super.key});

  void _openNewRequest(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SupportChatScreen(createNew: true),
      ),
    );
  }

  void _openExistingRequest(BuildContext context, String chatId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupportChatScreen(chatId: chatId),
      ),
    );
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }

  String _statusLabel(String status, String? outcome) {
    if (status == 'closed') {
      if (outcome == 'resolved') return 'Resolvido';
      if (outcome == 'unresolved') return 'Nao resolvido';
      return 'Finalizado';
    }
    return 'Aberto';
  }

  Color _statusColor(String status, String? outcome) {
    if (status != 'closed') return AppTheme.facebookBlue;
    if (outcome == 'resolved') return AppTheme.success;
    if (outcome == 'unresolved') return AppTheme.error;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.black : AppTheme.lightBg;
    final cardBg = isDark ? AppTheme.blackCard : Colors.white;
    final border = isDark ? AppTheme.blackBorder : const Color(0xFFE8E8E8);
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = isDark ? AppTheme.whiteMuted : Colors.grey.shade500;

    if (user == null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(title: const Text('Suporte')),
        body: Center(
          child: Text(
            'Faca login para falar com o suporte.',
            style: GoogleFonts.roboto(color: textColor),
          ),
        ),
      );
    }

    final stream = FirebaseFirestore.instance
        .collection('support_chats')
        .where('userId', isEqualTo: user.uid)
        .snapshots();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.black : Colors.white,
        elevation: 0,
        title: Text(
          'Suporte',
          style: GoogleFonts.roboto(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: IconThemeData(color: textColor),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: border),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNewRequest(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova solicitacao'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.facebookBlue),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Nao foi possivel carregar seu historico de suporte.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.roboto(color: mutedColor),
                ),
              ),
            );
          }

          final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
            snapshot.data?.docs ?? [],
          )..sort((a, b) {
              final aData = a.data();
              final bData = b.data();
              final aTime = (aData['lastMessageTime'] as Timestamp?) ??
                  (aData['createdAt'] as Timestamp?);
              final bTime = (bData['lastMessageTime'] as Timestamp?) ??
                  (bData['createdAt'] as Timestamp?);
              return (bTime?.millisecondsSinceEpoch ?? 0).compareTo(
                aTime?.millisecondsSinceEpoch ?? 0,
              );
            });

          if (docs.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const SupportChatScreen(createNew: true),
                ),
              );
            });
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.facebookBlue),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final status = data['status'] as String? ?? 'open';
              final outcome = data['resolutionOutcome'] as String?;
              final color = _statusColor(status, outcome);
              final subject =
                  data['subject'] as String? ?? 'Atendimento MarketView';
              final lastMessage = data['lastMessage'] as String? ?? '';
              final lastTime = (data['lastMessageTime'] as Timestamp?) ??
                  (data['createdAt'] as Timestamp?);

              return InkWell(
                onTap: () => _openExistingRequest(context, doc.id),
                borderRadius: BorderRadius.circular(14),
                child: Ink(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          status == 'closed'
                              ? Icons.check_circle_outline_rounded
                              : Icons.support_agent_rounded,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    subject,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.roboto(
                                      color: textColor,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Text(
                                  _formatDate(lastTime),
                                  style: GoogleFonts.roboto(
                                    color: mutedColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              lastMessage.isEmpty
                                  ? 'Solicitacao aberta'
                                  : lastMessage,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.roboto(
                                color: mutedColor,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _statusLabel(status, outcome),
                              style: GoogleFonts.roboto(
                                color: color,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: mutedColor,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
