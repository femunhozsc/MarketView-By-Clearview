import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  // Upload foto de perfil
  Future<String?> uploadProfilePhoto(String uid, File file) async {
    return _uploadFile(
      path: 'users/$uid/profile.jpg',
      file: file,
    );
  }

  Future<String?> uploadUserBanner(String uid, File file) async {
    return _uploadFile(
      path: 'users/$uid/banner.jpg',
      file: file,
    );
  }

  // Upload logo da loja
  Future<String?> uploadStoreLogo(String storeId, File file) async {
    return _uploadFile(
      path: 'stores/$storeId/logo.jpg',
      file: file,
    );
  }

  // Upload banner da loja
  Future<String?> uploadStoreBanner(String storeId, File file) async {
    return _uploadFile(
      path: 'stores/$storeId/banner.jpg',
      file: file,
    );
  }

  // Upload foto de anúncio
  Future<String?> uploadAdPhoto(String adId, File file, int index) async {
    return _uploadFile(
      path: 'ads/$adId/photo_$index.jpg',
      file: file,
    );
  }

  Future<String?> uploadCommunityPostImage(String postId, File file) async {
    return _uploadFile(
      path: 'community_posts/$postId/image.jpg',
      file: file,
    );
  }

  // Upload genérico
  Future<String?> _uploadFile({
    required String path,
    required File file,
  }) async {
    try {
      final ref = _storage.ref().child(path);
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      await ref.putFile(file, metadata);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Firebase Storage upload falhou em $path: $e');
      return null;
    }
  }

  // Selecionar imagem da galeria
  Future<File?> pickImage({bool camera = false}) async {
    final XFile? picked = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1200,
    );
    if (picked == null) return null;
    return File(picked.path);
  }

  // Selecionar múltiplas imagens
  Future<List<File>> pickMultipleImages({int max = 10}) async {
    final List<XFile> picked = await _picker.pickMultiImage(
      imageQuality: 75,
      maxWidth: 1200,
    );
    return picked.take(max).map((e) => File(e.path)).toList();
  }

  Future<bool> deleteFileByUrl(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
      return true;
    } catch (e) {
      debugPrint('Firebase Storage delete falhou em $url: $e');
      return false;
    }
  }
}
