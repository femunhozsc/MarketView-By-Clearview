import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import 'chat_detail_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
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
          child: Text('Faça login para ver suas mensagens', style: GoogleFonts.outfit(color: textColor)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.black : Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Mensagens',
          style: GoogleFonts.outfit(
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.facebookBlue));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Erro ao carregar mensagens',
                style: GoogleFonts.outfit(color: mutedColor),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          // Ordena localmente por lastMessageTime (evita necessidade de índice composto)
          final sortedDocs = List<QueryDocumentSnapshot>.from(docs)
            ..sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aTime = (aData['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime(2000);
              final bTime = (bData['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime(2000);
              return bTime.compareTo(aTime);
            });

          if (sortedDocs.isEmpty) {
            return _buildEmptyState(isDark, mutedColor);
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: sortedDocs.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: border, indent: 80),
            itemBuilder: (context, index) {
              final data = sortedDocs[index].data() as Map<String, dynamic>;
              // Usa o ID real do documento Firestore (mais confiável que data['id'])
              final chatId = sortedDocs[index].id;
              final lastMessage = data['lastMessage'] ?? '';
              final lastTime = (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now();
              
              final isBuyer = data['buyerId'] == user.uid;
              final otherId = isBuyer 
                  ? (data['sellerId'] ?? '') 
                  : (data['buyerId'] ?? '');

              if (otherId.isEmpty) return const SizedBox.shrink();

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(otherId).get(),
                builder: (context, userSnap) {
                  // Lida com os estados de carregamento e erro do FutureBuilder para mais estabilidade.
                  if (userSnap.connectionState == ConnectionState.waiting) {
                    // Exibe um placeholder (shimmer effect) enquanto carrega os dados do usuário.
                    // Isso evita reconstruções abruptas que podem causar erros de ponteiro.
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isDark ? AppTheme.blackLight : Colors.grey.shade200,
                      ),
                      title: Container(
                        height: 16,
                        width: 120,
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.blackLight : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      subtitle: Container(
                        height: 14,
                        margin: const EdgeInsets.only(top: 4, right: 80),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.blackLight : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  }

                  // Lida com erro ou caso o usuário do chat tenha sido excluído.
                  if (userSnap.hasError || !userSnap.hasData || userSnap.data?.data() == null) {
                    // Não renderiza nada se o outro usuário não for encontrado.
                    return const SizedBox.shrink();
                  }

                  final userData = userSnap.data!.data() as Map<String, dynamic>;
                  final firstName = userData['firstName'] as String? ?? '';
                  final lastName = userData['lastName'] as String? ?? '';
                  final otherName = (firstName.isNotEmpty || lastName.isNotEmpty)
                      ? '$firstName $lastName'.trim()
                      : 'Usuário';
                  final safeFirstChar = otherName.isNotEmpty ? otherName[0].toUpperCase() : 'U';
                  return ListTile(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatDetailScreen(
                          chatId: chatId,
                          otherUserName: otherName,
                          adTitle: data['adTitle'] ?? (data['adId'] != null ? 'Anúncio' : 'Conversa'),
                        ),
                      ),
                    ),
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.facebookBlue.withOpacity(0.1),
                      child: Text(safeFirstChar, style: const TextStyle(color: AppTheme.facebookBlue)),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            otherName,
                            style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(_formatTime(lastTime), style: GoogleFonts.outfit(color: mutedColor, fontSize: 12)),
                      ],
                    ),
                    subtitle: Text(
                      lastMessage.isEmpty ? 'Inicie uma conversa' : lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(color: mutedColor),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color mutedColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 64, color: mutedColor.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'Nenhuma conversa ainda',
            style: GoogleFonts.outfit(color: mutedColor, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
