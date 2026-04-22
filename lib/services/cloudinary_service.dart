import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../screens/photo_gallery_picker_screen.dart';
import '../theme/app_theme.dart';

class CloudinaryService {
  static const String cloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: 'dm40f9nsf',
  );
  static const String uploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: 'marketview_preset',
  );

  bool get isConfigured =>
      cloudName.trim().isNotEmpty && uploadPreset.trim().isNotEmpty;

  final ImagePicker _picker = ImagePicker();
  final ImageCropper _cropper = ImageCropper();

  Future<Map<String, String>?> uploadImage(File file, {String? folder}) async {
    if (!isConfigured) {
      debugPrint('Cloudinary upload ignorado: configuracao ausente.');
      return null;
    }
    try {
      final uri =
          Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      if (folder != null) {
        request.fields['folder'] = folder;
      }

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      if (response.statusCode == 200) {
        final json = Map<String, dynamic>.from(jsonDecode(responseData));
        final secureUrl = (json['secure_url'] ?? json['url']) as String?;
        final publicId = json['public_id'] as String?;
        if (secureUrl == null || secureUrl.isEmpty || publicId == null) {
          debugPrint('Cloudinary upload respondeu sem URL/public_id: $json');
          return null;
        }
        return {
          'url': secureUrl,
          'publicId': publicId,
        };
      }

      debugPrint(
        'Cloudinary upload falhou: status ${response.statusCode} body: $responseData',
      );
      return null;
    } catch (e) {
      debugPrint('Cloudinary upload erro: $e');
      return null;
    }
  }

  Future<String?> uploadImageUrl(File file, {String? folder}) async {
    final result = await uploadImage(file, folder: folder);
    return result?['url'];
  }

  Future<bool> deleteImage(String publicId) async {
    if (!isConfigured) {
      return false;
    }
    try {
      final uri =
          Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/destroy');
      final response = await http.post(uri, body: {
        'public_id': publicId,
        'upload_preset': uploadPreset,
      });
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['result'] == 'ok';
      }
      debugPrint('Cloudinary delete falhou: status ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('Cloudinary delete erro: $e');
      return false;
    }
  }

  Future<void> deleteImages(List<String> publicIds) async {
    for (final id in publicIds) {
      await deleteImage(id);
    }
  }

  Future<bool> deleteImageByUrl(String url) async {
    final publicId = publicIdFromUrl(url);
    if (publicId == null || publicId.isEmpty) return false;
    return deleteImage(publicId);
  }

  String? publicIdFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.host.contains('cloudinary.com')) {
      return null;
    }

    final segments = uri.pathSegments;
    final uploadIndex = segments.indexOf('upload');
    if (uploadIndex == -1 || uploadIndex + 1 >= segments.length) {
      return null;
    }

    var startIndex = uploadIndex + 1;
    if (segments[startIndex].startsWith('v')) {
      startIndex++;
    }
    if (startIndex >= segments.length) return null;

    final publicIdWithExtension = segments.sublist(startIndex).join('/');
    final dotIndex = publicIdWithExtension.lastIndexOf('.');
    if (dotIndex == -1) return publicIdWithExtension;
    return publicIdWithExtension.substring(0, dotIndex);
  }

  Future<String?> uploadProfilePhoto(String uid, File file) async {
    return uploadImageUrl(file, folder: 'users/$uid');
  }

  Future<String?> uploadUserBanner(String uid, File file) async {
    return uploadImageUrl(file, folder: 'users/$uid');
  }

  Future<String?> uploadStoreLogo(String storeId, File file) async {
    return uploadImageUrl(file, folder: 'stores/$storeId');
  }

  Future<String?> uploadStoreBanner(String storeId, File file) async {
    return uploadImageUrl(file, folder: 'stores/$storeId');
  }

  Future<Map<String, String>?> uploadAdPhotoFull(
    String adId,
    File file,
    int index,
  ) async {
    return uploadImage(file, folder: 'ads/$adId');
  }

  Future<String?> uploadAdPhoto(String adId, File file, int index) async {
    return uploadImageUrl(file, folder: 'ads/$adId');
  }

  Future<String?> uploadCommunityPostImage(String postId, File file) async {
    return uploadImageUrl(file, folder: 'community_posts/$postId');
  }

  Future<File?> pickAndCropImage({
    required BuildContext context,
    bool camera = false,
    CropAspectRatio? aspectRatio,
    String title = 'Recortar Imagem',
  }) async {
    String? selectedPath;
    if (camera) {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 75,
      );
      selectedPath = picked?.path;
    } else {
      final files = await PhotoGalleryPickerScreen.pick(
        context,
        title: 'Galeria de fotos',
      );
      if (files.isNotEmpty) {
        selectedPath = files.first.path;
      }
    }

    if (selectedPath == null) return null;

    final croppedFile = await _cropper.cropImage(
      sourcePath: selectedPath,
      aspectRatio: aspectRatio,
      compressQuality: 80,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: title,
          toolbarColor: AppTheme.facebookBlue,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: aspectRatio != null,
          activeControlsWidgetColor: AppTheme.facebookBlue,
        ),
        IOSUiSettings(
          title: title,
          cancelButtonTitle: 'Cancelar',
          doneButtonTitle: 'Concluir',
          aspectRatioLockEnabled: aspectRatio != null,
        ),
      ],
    );

    if (croppedFile == null) return null;
    return File(croppedFile.path);
  }

  Future<File?> cropImageFreely({
    required String path,
    String title = 'Recortar imagem',
  }) async {
    final croppedFile = await _cropper.cropImage(
      sourcePath: path,
      compressQuality: 80,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: title,
          toolbarColor: AppTheme.facebookBlue,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          hideBottomControls: false,
          activeControlsWidgetColor: AppTheme.facebookBlue,
        ),
        IOSUiSettings(
          title: title,
          cancelButtonTitle: 'Cancelar',
          doneButtonTitle: 'Concluir',
          aspectRatioLockEnabled: false,
          resetAspectRatioEnabled: true,
        ),
      ],
    );

    if (croppedFile == null) return null;
    return File(croppedFile.path);
  }

  Future<List<File>> pickImagesFromGallery(
    BuildContext context, {
    int max = 10,
  }) async {
    return PhotoGalleryPickerScreen.pick(
      context,
      maxSelection: max,
      title: 'Galeria de fotos',
    );
  }

  Future<List<File>> pickMultipleImages(
    BuildContext context, {
    int max = 10,
  }) async {
    return pickImagesFromGallery(context, max: max);
  }
}
