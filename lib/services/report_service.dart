import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';

class ReportService {
  static const List<String> reasons = [
    'Golpe ou fraude',
    'Conteudo proibido',
    'Informacoes falsas',
    'Spam',
    'Produto ou servico irregular',
    'Outro',
  ];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> showReportDialog({
    required BuildContext context,
    required UserModel? user,
    required String targetType,
    required String targetId,
    required String targetTitle,
    String targetOwnerId = '',
  }) async {
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faca login para enviar uma denuncia.')),
      );
      return false;
    }

    final result = await showModalBottomSheet<_ReportResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ReportReasonSheet(targetTitle: targetTitle),
    );
    if (result == null) return false;

    await submitReport(
      user: user,
      targetType: targetType,
      targetId: targetId,
      targetTitle: targetTitle,
      targetOwnerId: targetOwnerId,
      reason: result.reason,
      details: result.details,
    );
    return true;
  }

  Future<void> submitReport({
    required UserModel user,
    required String targetType,
    required String targetId,
    required String targetTitle,
    required String targetOwnerId,
    required String reason,
    required String details,
  }) async {
    final now = Timestamp.now();
    final safeTargetTitle =
        targetTitle.trim().isNotEmpty ? targetTitle.trim() : 'Item sem titulo';
    final reportId =
        'report_${user.uid}_${DateTime.now().millisecondsSinceEpoch}';
    final chatRef = _firestore.collection('support_chats').doc(reportId);
    final messageRef = chatRef.collection('messages').doc();
    final targetLabel =
        targetType == 'ad' ? 'anuncio' : 'publicacao da comunidade';
    final detailText =
        details.trim().isEmpty ? '' : '\nDetalhes: ${details.trim()}';
    final messageText =
        'Denuncia de $targetLabel: $safeTargetTitle\nMotivo: $reason$detailText';

    final batch = _firestore.batch();
    batch.set(chatRef, {
      'id': chatRef.id,
      'type': 'report',
      'userId': user.uid,
      'userName': user.fullName.isNotEmpty ? user.fullName : 'Usuario',
      'userEmail': user.email,
      'subject': 'Denuncia: $safeTargetTitle',
      'status': 'open',
      'lastMessage': messageText,
      'lastMessageSenderRole': 'user',
      'lastMessageTime': now,
      'createdAt': now,
      'updatedAt': now,
      'reportTargetType': targetType,
      'reportTargetId': targetId,
      'reportTargetTitle': safeTargetTitle,
      'reportTargetOwnerId': targetOwnerId,
      'reportReason': reason,
      'reportDetails': details.trim(),
    });
    batch.set(messageRef, {
      'id': messageRef.id,
      'senderId': user.uid,
      'senderName': user.fullName.isNotEmpty ? user.fullName : 'Usuario',
      'senderRole': 'user',
      'text': messageText,
      'time': now,
      'readBy': [user.uid],
    });
    await batch.commit();
  }
}

class _ReportResult {
  const _ReportResult({
    required this.reason,
    required this.details,
  });

  final String reason;
  final String details;
}

class _ReportReasonSheet extends StatefulWidget {
  const _ReportReasonSheet({required this.targetTitle});

  final String targetTitle;

  @override
  State<_ReportReasonSheet> createState() => _ReportReasonSheetState();
}

class _ReportReasonSheetState extends State<_ReportReasonSheet> {
  String _selectedReason = ReportService.reasons.first;
  final _detailsController = TextEditingController();

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_selectedReason == 'Outro' && _detailsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Descreva o motivo da denuncia.')),
      );
      return;
    }

    Navigator.pop(
      context,
      _ReportResult(
        reason: _selectedReason,
        details: _detailsController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Denunciar',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              widget.targetTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 14),
            ...ReportService.reasons.map(
              (reason) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _selectedReason == reason
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                ),
                title: Text(reason),
                onTap: () {
                  setState(() => _selectedReason = reason);
                },
              ),
            ),
            TextField(
              controller: _detailsController,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: _selectedReason == 'Outro'
                    ? 'Descreva o motivo'
                    : 'Detalhes adicionais (opcional)',
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('Enviar denuncia'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
