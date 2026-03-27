import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

class ChatDetailScreen extends StatefulWidget {
  final String chatId;
  final String otherUserName;
  final String adTitle;

  const ChatDetailScreen({
    super.key,
    required this.chatId,
    required this.otherUserName,
    required this.adTitle,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _messageCtrl = TextEditingController();
  final _firestore = FirestoreService();

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;

    final user = context.read<UserProvider>().user;
    if (user == null) return;

    _messageCtrl.clear();
    try {
      await _firestore.sendMessage(widget.chatId, user.uid, text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao enviar mensagem. Tente novamente.')),
        );
        _messageCtrl.text = text; // Restaura o texto em caso de erro
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.black : AppTheme.lightBg;
    final textColor = isDark ? Colors.white : Colors.black87;
    final user = context.read<UserProvider>().user;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.black : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.otherUserName,
              style: GoogleFonts.outfit(color: textColor, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              widget.adTitle,
              style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.getMessagesStream(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.facebookBlue));
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline_rounded, color: Colors.grey, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'Erro ao carregar mensagens',
                          style: GoogleFonts.outfit(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, color: Colors.grey.withOpacity(0.4), size: 64),
                        const SizedBox(height: 12),
                        Text(
                          'Nenhuma mensagem ainda.\nSeja o primeiro a enviar!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(color: Colors.grey, fontSize: 15),
                        ),
                      ],
                    ),
                  );
                }

                // Ordena localmente por tempo (mais recente primeiro para ListView reverse)
                final sortedDocs = List<QueryDocumentSnapshot>.from(docs)
                  ..sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    final aTime = (aData['time'] as Timestamp?)?.toDate() ?? DateTime(2000);
                    final bTime = (bData['time'] as Timestamp?)?.toDate() ?? DateTime(2000);
                    return bTime.compareTo(aTime); // mais recente primeiro
                  });

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedDocs.length,
                  itemBuilder: (context, index) {
                    final data = sortedDocs[index].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == user?.uid;
                    final text = data['text'] as String? ?? '';
                    if (text.isEmpty) return const SizedBox.shrink();
                    
                    return _buildMessageBubble(text, isMe, isDark);
                  },
                );
              },
            ),
          ),
          _buildInputArea(isDark),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isMe, bool isDark) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.facebookBlue : (isDark ? AppTheme.blackLight : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(18),
            bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(0),
          ),
        ),
        child: Text(
          text,
          style: GoogleFonts.outfit(
            color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.blackCard : Colors.white,
        border: Border(top: BorderSide(color: isDark ? AppTheme.blackBorder : Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageCtrl,
              style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Digite uma mensagem...',
                hintStyle: GoogleFonts.outfit(color: Colors.grey),
                filled: true,
                fillColor: isDark ? AppTheme.black : Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: AppTheme.facebookBlue),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}
