import 'dart:io';

import 'package:image_picker/image_picker.dart';

import 'cloudinary_service.dart';

class StorageService {
  final CloudinaryService _cloudinary = CloudinaryService();
  final ImagePicker _picker = ImagePicker();

  Future<String?> uploadProfilePhoto(String uid, File file) {
    return _cloudinary.uploadProfilePhoto(uid, file);
  }

  Future<String?> uploadUserBanner(String uid, File file) {
    return _cloudinary.uploadUserBanner(uid, file);
  }

  Future<String?> uploadStoreLogo(String storeId, File file) {
    return _cloudinary.uploadStoreLogo(storeId, file);
  }

  Future<String?> uploadStoreBanner(String storeId, File file) {
    return _cloudinary.uploadStoreBanner(storeId, file);
  }

  Future<String?> uploadAdPhoto(String adId, File file, int index) {
    return _cloudinary.uploadAdPhoto(adId, file, index);
  }

  Future<String?> uploadCommunityPostImage(String postId, File file) {
    return _cloudinary.uploadCommunityPostImage(postId, file);
  }

  Future<File?> pickImage({bool camera = false}) async {
    final picked = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1200,
    );
    if (picked == null) return null;
    return File(picked.path);
  }

  Future<List<File>> pickMultipleImages({int max = 10}) async {
    final picked = await _picker.pickMultiImage(
      imageQuality: 75,
      maxWidth: 1200,
    );
    return picked.take(max).map((e) => File(e.path)).toList();
  }

  Future<bool> deleteFileByUrl(String url) {
    return _cloudinary.deleteImageByUrl(url);
  }
}
