import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({
    super.key,
    this.chatId,
    this.createNew = false,
  });

  final String? chatId;
  final bool createNew;

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  static const _autoReplyText =
      'Ola! Ja va descrevendo o problema com o maximo de detalhes. Nosso suporte funciona das 8h as 18h, 7 dias por semana.';

  final _firestore = FirebaseFirestore.instance;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Future<void>? _chatFuture;
  String? _activeChatId;
  bool _sending = false;

  String? _createdChatId;

  String _resolveChatId(String uid) {
    if (widget.chatId != null && widget.chatId!.trim().isNotEmpty) {
      return widget.chatId!.trim();
    }
    if (widget.createNew) {
      _createdChatId ??=
          'support_${uid}_${DateTime.now().millisecondsSinceEpoch}';
      return _createdChatId!;
    }
    return 'support_$uid';
  }

  DocumentReference<Map<String, dynamic>> _chatRef(String uid) {
    return _firestore.collection('support_chats').doc(_resolveChatId(uid));
  }

  Future<void> _ensureSupportChat(UserModel user) async {
    final ref = _chatRef(user.uid);
    final baseData = {
      'id': ref.id,
      'userId': user.uid,
      'userName': user.fullName.isNotEmpty ? user.fullName : 'Usuario',
      'userEmail': user.email,
      'subject': 'Atendimento MarketView',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (widget.createNew && widget.chatId == null) {
      await ref.set({
        ...baseData,
        'status': 'open',
        'lastMessage': '',
        'lastMessageSenderRole': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    final snapshot = await ref.get();
    if (snapshot.exists) {
      await ref.set(baseData, SetOptions(merge: true));
      return;
    }

    await ref.set({
      ...baseData,
      'status': 'open',
      'lastMessage': '',
      'lastMessageSenderRole': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  void _ensureFuture(UserModel user) {
    final chatId = _resolveChatId(user.uid);
    if (_activeChatId == chatId && _chatFuture != null) return;
    _activeChatId = chatId;
    _chatFuture = _ensureSupportChat(user);
  }

  Future<void> _sendMessage(UserModel user) async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      final chatRef = _chatRef(user.uid);
      final chatSnapshot = await chatRef.get();
      final chatData = chatSnapshot.data();
      if (chatData != null && chatData['status'] == 'closed') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Este atendimento foi finalizado. Abra uma nova solicitacao.',
            ),
          ),
        );
        return;
      }
      final hasMessagesSnapshot =
          await chatRef.collection('messages').limit(1).get();
      final shouldAddAutoReply = hasMessagesSnapshot.docs.isEmpty;
      final messageRef = chatRef.collection('messages').doc();
      final autoReplyRef = chatRef.collection('messages').doc();
      final messageTime = Timestamp.now();
      final autoReplyTime = Timestamp.fromMillisecondsSinceEpoch(
        messageTime.millisecondsSinceEpoch + 1,
      );
      final batch = _firestore.batch();

      batch.set(
        chatRef,
        {
          'id': chatRef.id,
          'userId': user.uid,
          'userName': user.fullName.isNotEmpty ? user.fullName : 'Usuario',
          'userEmail': user.email,
          'subject': 'Atendimento MarketView',
          'status': 'open',
          'lastMessage': text,
          'lastMessageSenderRole': 'user',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      batch.set(messageRef, {
        'id': messageRef.id,
        'senderId': user.uid,
        'senderName': user.fullName.isNotEmpty ? user.fullName : 'Usuario',
        'senderRole': 'user',
        'text': text,
        'time': messageTime,
        'readBy': [user.uid],
      });
      if (shouldAddAutoReply) {
        batch.set(autoReplyRef, {
          'id': autoReplyRef.id,
          'senderId': 'marketview_support_bot',
          'senderName': 'Suporte MarketView',
          'senderRole': 'system',
          'text': _autoReplyText,
          'time': autoReplyTime,
          'readBy': const <String>[],
        });
      }

      await batch.commit();
      _messageController.clear();
      unawaited(_scrollToBottom());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nao foi possivel enviar a mensagem.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _scrollToBottom() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
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

    _ensureFuture(user);
    final chatRef = _chatRef(user.uid);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.black : Colors.white,
        elevation: 0,
        title: Text(
          'Suporte MarketView',
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
      body: FutureBuilder<void>(
        future: _chatFuture,
        builder: (context, setupSnapshot) {
          if (setupSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.facebookBlue),
            );
          }

          if (setupSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Nao foi possivel abrir o suporte agora.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.roboto(color: mutedColor),
                ),
              ),
            );
          }

          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
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
                        color: AppTheme.facebookBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.support_agent_rounded,
                        color: AppTheme.facebookBlue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Atendimento pelo app',
                            style: GoogleFonts.roboto(
                              color: textColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Envie sua duvida e acompanhe a resposta por aqui.',
                            style: GoogleFonts.roboto(
                              color: mutedColor,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: chatRef
                      .collection('messages')
                      .orderBy('time')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.facebookBlue,
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Erro ao carregar o chat.',
                          style: GoogleFonts.roboto(color: mutedColor),
                        ),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Conte para a gente como podemos ajudar.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.roboto(color: mutedColor),
                          ),
                        ),
                      );
                    }

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      unawaited(_scrollToBottom());
                    });

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data();
                        final senderRole =
                            data['senderRole'] as String? ?? 'user';
                        final mine = senderRole == 'user';
                        final text = data['text'] as String? ?? '';
                        final time = data['time'] as Timestamp?;

                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.76,
                            ),
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: mine ? AppTheme.facebookBlue : cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: mine ? null : Border.all(color: border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  text,
                                  style: GoogleFonts.roboto(
                                    color: mine ? Colors.white : textColor,
                                    fontSize: 14,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTime(time),
                                  style: GoogleFonts.roboto(
                                    color: mine
                                        ? Colors.white.withValues(alpha: 0.72)
                                        : mutedColor,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.black : Colors.white,
                    border: Border(top: BorderSide(color: border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.newline,
                          decoration: const InputDecoration(
                            hintText: 'Digite sua mensagem...',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: FilledButton(
                          onPressed: _sending ? null : () => _sendMessage(user),
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
