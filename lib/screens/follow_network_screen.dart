import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import 'chat_detail_screen.dart';
import 'seller_profile_screen.dart';

class FollowNetworkScreen extends StatefulWidget {
  final String title;
  final bool followersMode;

  const FollowNetworkScreen({
    super.key,
    required this.title,
    required this.followersMode,
  });

  @override
  State<FollowNetworkScreen> createState() => _FollowNetworkScreenState();
}

class _FollowNetworkScreenState extends State<FollowNetworkScreen> {
  final _firestore = FirestoreService();
  bool _loading = true;
  List<UserModel> _users = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final current = context.read<UserProvider>().user;
    if (current == null) return;

    List<UserModel> users = [];
    if (widget.followersMode) {
      final sellerId = current.uid;
      users = await _firestore.getFollowersOfSeller(sellerId);
    } else {
      users = await _firestore.getUsersByIds(current.followingSellerIds);
    }

    if (!mounted) return;
    setState(() {
      _users = users;
      _loading = false;
    });
  }

  Future<void> _messageUser(UserModel other) async {
    final current = context.read<UserProvider>().user;
    if (current == null) return;
    try {
      final chatId = await _firestore.getOrCreateDirectChat(
        current.uid,
        other.uid,
        title: '',
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            chatId: chatId,
            otherUserId: other.uid,
            otherUserName: other.fullName,
            adTitle: '',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível abrir a conversa agora.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppTheme.black : AppTheme.lightBg,
      appBar: AppBar(title: Text(widget.title)),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.facebookBlue))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _users.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final user = _users[index];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.blackCard : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? AppTheme.blackBorder
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SellerProfileScreen(
                              sellerId: user.uid,
                              sellerName: user.fullName,
                            ),
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 24,
                          backgroundImage: user.profilePhoto != null
                              ? NetworkImage(user.profilePhoto!)
                              : null,
                          child: user.profilePhoto == null
                              ? Text(user.firstName.isNotEmpty
                                  ? user.firstName[0]
                                  : 'U')
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SellerProfileScreen(
                                sellerId: user.uid,
                                sellerName: user.fullName,
                              ),
                            ),
                          ),
                          child: Text(user.fullName),
                        ),
                      ),
                      FilledButton(
                        onPressed: () => _messageUser(user),
                        child: const Text('Mensagem'),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
