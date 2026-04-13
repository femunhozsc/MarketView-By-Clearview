import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/store_model.dart';
import '../providers/user_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

class StoreMembersScreen extends StatefulWidget {
  const StoreMembersScreen({
    super.key,
    required this.storeId,
  });

  final String storeId;

  @override
  State<StoreMembersScreen> createState() => _StoreMembersScreenState();
}

class _StoreMembersScreenState extends State<StoreMembersScreen> {
  final _firestore = FirestoreService();
  StoreModel? _store;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final store = await _firestore.getStore(widget.storeId);
    if (!mounted) return;
    setState(() {
      _store = store;
      _loading = false;
    });
  }

  Future<void> _makeAdmin(StoreMember member) async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;

    await _firestore.updateStoreMemberRole(
      storeId: widget.storeId,
      actingUserId: user.uid,
      memberUserId: member.userId,
      role: StoreMemberRole.admin,
    );
    await _load();
  }

  Future<void> _removeMember(StoreMember member) async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;

    await _firestore.removeStoreMember(
      storeId: widget.storeId,
      actingUserId: user.uid,
      memberUserId: member.userId,
    );
    await _load();
  }

  Future<void> _removeAdmin(StoreMember member) async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;

    await _firestore.removeStoreAdmin(
      storeId: widget.storeId,
      actingUserId: user.uid,
      memberUserId: member.userId,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.black : AppTheme.lightBg;
    final textColor = isDark ? Colors.white : Colors.black87;
    final currentUserId = context.watch<UserProvider>().user?.uid;
    final canRemoveAdmin = currentUserId != null && _store?.ownerId == currentUserId;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.black : Colors.white,
        elevation: 0,
        title: Text(
          'Gerenciar membros',
          style: GoogleFonts.roboto(
            color: textColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.facebookBlue),
            )
          : _store == null
              ? const SizedBox.shrink()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _store!.members.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final member = _store!.members[index];
                    final isOwner = member.userId == _store!.ownerId;
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.blackCard : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark
                              ? AppTheme.blackBorder
                              : const Color(0xFFE8E8E8),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor:
                                    AppTheme.facebookBlue.withValues(alpha: 0.10),
                                backgroundImage: member.avatarUrl != null
                                    ? NetworkImage(member.avatarUrl!)
                                    : null,
                                child: member.avatarUrl == null
                                    ? Text(
                                        member.name.isNotEmpty
                                            ? member.name[0].toUpperCase()
                                            : 'U',
                                        style: GoogleFonts.roboto(
                                          color: AppTheme.facebookBlue,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      member.name,
                                      style: GoogleFonts.roboto(
                                        color: textColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      isOwner
                                          ? 'Proprietário'
                                          : member.isAdmin
                                              ? 'Administrador'
                                              : 'Membro',
                                      style: GoogleFonts.roboto(
                                        color: AppTheme.facebookBlue,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (!isOwner) ...[
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                if (!member.isAdmin)
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _makeAdmin(member),
                                      child: const Text('Tornar admin'),
                                    ),
                                  ),
                                if (!member.isAdmin) const SizedBox(width: 10),
                                if (member.isAdmin && canRemoveAdmin) ...[
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _removeAdmin(member),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFFF59E0B),
                                      ),
                                      child: const Text('Remover admin'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _removeMember(member),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.error,
                                    ),
                                    child: const Text('Remover'),
                                  ),
                                ),
                              ],
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
