import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

class UserProvider extends ChangeNotifier {
  UserModel? _user;
  bool _loading = false;
  final FirestoreService _firestore = FirestoreService();

  UserModel? get user => _user;
  bool get loading => _loading;
  bool get isLoggedIn => FirebaseAuth.instance.currentUser != null;
  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> loadUser(String uid) async {
    _loading = true;
    notifyListeners();
    _user = await _firestore.getUser(uid);
    _loading = false;
    notifyListeners();
  }

  void setUser(UserModel user) {
    _user = user;
    notifyListeners();
  }

  void clear() {
    _user = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    final uid = this.uid;
    if (uid == null) return;
    await loadUser(uid);
  }

  /// Registra um clique em uma categoria para o sistema de recomendação.
  /// Atualiza localmente e no Firestore de forma assíncrona.
  Future<void> trackCategoryClick(String category) async {
    if (_user == null) return;
    
    // Atualiza localmente primeiro para resposta imediata
    final updatedClicks = Map<String, int>.from(_user!.categoryClicks);
    updatedClicks[category] = (updatedClicks[category] ?? 0) + 1;
    _user = _user!.copyWith(categoryClicks: updatedClicks);
    notifyListeners();
    
    // Persiste no Firestore em background
    try {
      await _firestore.trackCategoryClick(_user!.uid, category);
    } catch (e) {
      debugPrint('Erro ao rastrear clique de categoria: $e');
    }
  }
}
