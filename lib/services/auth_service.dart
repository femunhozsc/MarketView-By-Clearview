import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';
import 'firestore_service.dart';

class AuthService {
  static const double _defaultLat = -24.0466;
  static const double _defaultLng = -52.3780;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestore = FirestoreService();

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  bool get isLoggedIn => _auth.currentUser != null;

  bool requiresVerifiedEmail(User user) {
    return false; // Desabilitado temporariamente a pedido do usuário
  }

  Future<AuthResult> register({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return AuthResult(success: true, user: credential.user);
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, error: _translateError(e.code));
    } catch (_) {
      return const AuthResult(
        success: false,
        error: 'Erro inesperado. Tente novamente.',
      );
    }
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return AuthResult(success: true, user: credential.user);
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, error: _translateError(e.code));
    } catch (_) {
      return const AuthResult(
        success: false,
        error: 'Erro inesperado. Tente novamente.',
      );
    }
  }

  Future<AuthResult> registerForEmailAccess({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        return const AuthResult(
          success: false,
          error: 'Nao foi possivel criar sua conta agora.',
        );
      }

      final trimmedName = displayName?.trim() ?? '';
      if (trimmedName.isNotEmpty) {
        await user.updateDisplayName(trimmedName);
      }

      await ensureUserProfile(
        user: _auth.currentUser ?? user,
        displayName: trimmedName,
        email: email.trim(),
      );

      await user.sendEmailVerification();
      await _auth.signOut();

      return const AuthResult(
        success: true,
        message: 'Conta criada com sucesso. Verifique seu e-mail para entrar.',
        emailVerificationRequired: true,
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, error: _translateError(e.code));
    } catch (_) {
      return const AuthResult(
        success: false,
        error: 'Erro inesperado. Tente novamente.',
      );
    }
  }

  Future<AuthResult> loginWithVerifiedEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final signedUser = credential.user;
      if (signedUser == null) {
        return const AuthResult(
          success: false,
          error: 'Nao foi possivel entrar agora.',
        );
      }

      await signedUser.reload();
      final refreshedUser = _auth.currentUser ?? signedUser;
      final existingProfile = await _firestore.getUser(refreshedUser.uid);
      if (requiresVerifiedEmail(refreshedUser)) {
        final requiresVerification =
            existingProfile?.emailVerificationRequired ?? false;
        if (!requiresVerification) {
          await ensureUserProfile(
            user: refreshedUser,
            displayName: refreshedUser.displayName,
            email: refreshedUser.email,
          );
          return const AuthResult(
            success: true,
            message:
                'Login realizado. Esta conta antiga foi liberada mesmo sem verificacao de e-mail.',
          );
        }

        await refreshedUser.sendEmailVerification();
        await _auth.signOut();
        return const AuthResult(
          success: false,
          error: 'Seu e-mail ainda nao foi verificado. Enviamos um novo link.',
          emailVerificationRequired: true,
        );
      }

      await ensureUserProfile(
        user: refreshedUser,
        displayName: refreshedUser.displayName,
        email: refreshedUser.email,
      );
      if (existingProfile?.emailVerificationRequired ?? false) {
        await _firestore.updateUser(
          refreshedUser.uid,
          {'emailVerificationRequired': false},
        );
      }

      return AuthResult(success: true, user: refreshedUser);
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, error: _translateError(e.code));
    } catch (_) {
      return const AuthResult(
        success: false,
        error: 'Erro inesperado. Tente novamente.',
      );
    }
  }

  Future<AuthResult> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return const AuthResult(
        success: true,
        message: 'Enviamos o link de recuperacao para o seu e-mail.',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, error: _translateError(e.code));
    } catch (_) {
      return const AuthResult(
        success: false,
        error: 'Nao foi possivel enviar o link de recuperacao agora.',
      );
    }
  }

  Future<PhoneCodeRequestResult> requestPhoneCode({
    required String phoneNumber,
    String? displayName,
    int? resendToken,
  }) async {
    final completer = Completer<PhoneCodeRequestResult>();

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        forceResendingToken: resendToken,
        verificationCompleted: (credential) async {
          try {
            final result = await _auth.signInWithCredential(credential);
            if (result.user != null) {
              await ensureUserProfile(
                user: result.user!,
                displayName: displayName,
                phoneNumber: phoneNumber,
              );
            }

            if (!completer.isCompleted) {
              completer.complete(
                const PhoneCodeRequestResult(
                  success: true,
                  autoVerified: true,
                  message: 'Numero verificado automaticamente.',
                ),
              );
            }
          } on FirebaseAuthException catch (e) {
            if (!completer.isCompleted) {
              completer.complete(
                PhoneCodeRequestResult(
                  success: false,
                  error: _translateError(e.code),
                ),
              );
            }
          } catch (_) {
            if (!completer.isCompleted) {
              completer.complete(
                const PhoneCodeRequestResult(
                  success: false,
                  error: 'Nao foi possivel validar o numero agora.',
                ),
              );
            }
          }
        },
        verificationFailed: (exception) {
          if (completer.isCompleted) return;
          completer.complete(
            PhoneCodeRequestResult(
              success: false,
              error: _translateError(exception.code),
            ),
          );
        },
        codeSent: (verificationId, nextResendToken) {
          if (completer.isCompleted) return;
          completer.complete(
            PhoneCodeRequestResult(
              success: true,
              verificationId: verificationId,
              resendToken: nextResendToken,
              message: 'Codigo enviado por SMS.',
            ),
          );
        },
        codeAutoRetrievalTimeout: (verificationId) {
          if (completer.isCompleted) return;
          completer.complete(
            PhoneCodeRequestResult(
              success: true,
              verificationId: verificationId,
              resendToken: resendToken,
              message: 'Digite o codigo recebido para concluir.',
            ),
          );
        },
      );
    } on FirebaseAuthException catch (e) {
      if (!completer.isCompleted) {
        completer.complete(
          PhoneCodeRequestResult(
            success: false,
            error: _translateError(e.code),
          ),
        );
      }
    } catch (_) {
      if (!completer.isCompleted) {
        completer.complete(
          const PhoneCodeRequestResult(
            success: false,
            error: 'Nao foi possivel enviar o SMS agora.',
          ),
        );
      }
    }

    return completer.future;
  }

  Future<AuthResult> verifySmsCode({
    required String verificationId,
    required String smsCode,
    required String phoneNumber,
    String? displayName,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );
      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      if (user == null) {
        return const AuthResult(
          success: false,
          error: 'Nao foi possivel validar o codigo informado.',
        );
      }

      await ensureUserProfile(
        user: user,
        displayName: displayName,
        phoneNumber: phoneNumber,
      );

      return AuthResult(success: true, user: user);
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, error: _translateError(e.code));
    } catch (_) {
      return const AuthResult(
        success: false,
        error: 'Erro inesperado ao validar o codigo.',
      );
    }
  }

  Future<void> ensureCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await ensureUserProfile(
      user: user,
      displayName: user.displayName,
      email: user.email,
      phoneNumber: user.phoneNumber,
    );
  }

  Future<void> ensureUserProfile({
    required User user,
    String? displayName,
    String? email,
    String? phoneNumber,
  }) async {
    final existingUser = await _firestore.getUser(user.uid);
    final resolvedEmail = (email ?? user.email ?? '').trim();
    final resolvedPhone = (phoneNumber ?? user.phoneNumber ?? '').trim();
    final resolvedName = (displayName ?? user.displayName ?? '').trim();
    final splitName = _splitName(
      resolvedName.isNotEmpty
          ? resolvedName
          : _fallbackName(resolvedEmail, resolvedPhone),
    );

    if (existingUser == null) {
      final newUser = UserModel(
        uid: user.uid,
        firstName: splitName.first,
        lastName: splitName.last,
        cpf: '',
        email: resolvedEmail,
        phone: resolvedPhone,
        address: AddressModel(
          city: 'Campo Mourao',
          state: 'PR',
          country: 'Brasil',
          lat: _defaultLat,
          lng: _defaultLng,
        ),
        createdAt: DateTime.now(),
      );
      await _firestore.createUser(newUser);
      return;
    }

    final updates = <String, dynamic>{};
    if (existingUser.email.isEmpty && resolvedEmail.isNotEmpty) {
      updates['email'] = resolvedEmail;
    }
    if (existingUser.phone.isEmpty && resolvedPhone.isNotEmpty) {
      updates['phone'] = resolvedPhone;
    }
    if (existingUser.firstName.isEmpty && splitName.first.isNotEmpty) {
      updates['firstName'] = splitName.first;
    }
    if (existingUser.lastName.isEmpty && splitName.last.isNotEmpty) {
      updates['lastName'] = splitName.last;
    }
    if (updates.isNotEmpty) {
      await _firestore.updateUser(user.uid, updates);
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<AuthResult> deleteCurrentAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      return const AuthResult(
        success: false,
        error: 'Nenhuma conta ativa encontrada.',
      );
    }

    try {
      await user.delete();
      try {
        await _firestore.deleteUserAccountData(user.uid);
      } catch (_) {
        // Mantemos a conta removida no Auth e deixamos a limpeza residual para manutencao.
      }
      return const AuthResult(success: true);
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, error: _translateError(e.code));
    } catch (_) {
      return const AuthResult(
        success: false,
        error: 'Nao foi possivel excluir a conta agora. Tente novamente.',
      );
    }
  }

  ({String first, String last}) _splitName(String rawName) {
    final sanitized = rawName.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (sanitized.isEmpty) {
      return (first: 'Usuario', last: '');
    }

    final parts = sanitized.split(' ');
    final first = parts.first;
    final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    return (first: first, last: last);
  }

  String _fallbackName(String email, String phoneNumber) {
    if (email.isNotEmpty && email.contains('@')) {
      return email.split('@').first.replaceAll(RegExp(r'[^A-Za-z0-9]+'), ' ');
    }
    if (phoneNumber.isNotEmpty) {
      final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
      final tail =
          digits.length >= 4 ? digits.substring(digits.length - 4) : digits;
      return 'Usuario $tail';
    }
    return 'Usuario';
  }

  String _translateError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Este e-mail ja esta cadastrado.';
      case 'invalid-email':
        return 'Digite um e-mail valido.';
      case 'weak-password':
        return 'Use uma senha com pelo menos 6 caracteres.';
      case 'user-not-found':
        return 'Nao encontramos uma conta com esse e-mail.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Credenciais invalidas.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde alguns minutos.';
      case 'network-request-failed':
        return 'Sem conexao com a internet.';
      case 'requires-recent-login':
        return 'Faca login novamente para concluir essa acao.';
      case 'invalid-phone-number':
        return 'Numero de telefone invalido.';
      case 'quota-exceeded':
        return 'Limite de envio de SMS atingido no momento.';
      case 'session-expired':
        return 'O codigo expirou. Solicite um novo SMS.';
      case 'invalid-verification-code':
        return 'Codigo de verificacao invalido.';
      case 'invalid-verification-id':
        return 'Nao foi possivel validar esse codigo. Solicite outro SMS.';
      case 'credential-already-in-use':
        return 'Esse numero ja esta em uso por outra conta.';
      case 'app-not-authorized':
        return 'Aplicativo nao autorizado para este projeto Firebase.';
      default:
        return 'Erro de autenticacao. Tente novamente.';
    }
  }
}

class AuthResult {
  final bool success;
  final User? user;
  final String? error;
  final String? message;
  final bool emailVerificationRequired;

  const AuthResult({
    required this.success,
    this.user,
    this.error,
    this.message,
    this.emailVerificationRequired = false,
  });
}

class PhoneCodeRequestResult {
  final bool success;
  final String? verificationId;
  final int? resendToken;
  final bool autoVerified;
  final String? error;
  final String? message;

  const PhoneCodeRequestResult({
    required this.success,
    this.verificationId,
    this.resendToken,
    this.autoVerified = false,
    this.error,
    this.message,
  });
}
