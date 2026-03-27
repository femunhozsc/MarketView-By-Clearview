import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../screens/home_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user != null) {
          // Carrega dados do usuário do Firestore
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<UserProvider>().loadUser(user.uid);
          });
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<UserProvider>().clear();
          });
        }

        // Sempre mostra o HomeScreen — ele gerencia o estado internamente
        // Se não logado, a aba de perfil mostra opções de login/cadastro
        return const HomeScreen();
      },
    );
  }
}