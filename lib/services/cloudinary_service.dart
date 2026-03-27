import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../theme/app_theme.dart';

class CloudinaryService {
  // Substitua pelos seus dados do Cloudinary
  static const String cloudName = 'dm40f9nsf';
  static const String uploadPreset = 'marketview_preset'; // crie um preset unsigned no Cloudinary

  final ImagePicker _picker = ImagePicker();
  final ImageCropper _cropper = ImageCropper();

  /// Upload genérico para Cloudinary com compactação via transformações.
  /// Retorna um Map com 'url' e 'publicId' para permitir deleção futura.
  Future<Map<String, String>?> uploadImage(File file, {String? folder}) async {
    try {
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      if (folder != null) {
        request.fields['folder'] = folder;
      }

      // Transformações de compactação no upload:
      // - quality auto:good → Cloudinary escolhe a melhor compactação
      // - format auto → converte para WebP/AVIF quando o navegador suporta
      // - width 1200 → limita largura máxima a 1200px (suficiente para mobile)
      request.fields['transformation'] = 'q_auto:good,f_auto,w_1200,c_limit';

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final json = Map<String, dynamic>.from(jsonDecode(responseData));
        return {
          'url': json['secure_url'] as String,
          'publicId': json['public_id'] as String,
        };
      }
      debugPrint('Cloudinary upload falhou: status ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('Cloudinary upload erro: $e');
      return null;
    }
  }

  /// Upload simples que retorna apenas a URL (compatibilidade)
  Future<String?> uploadImageUrl(File file, {String? folder}) async {
    final result = await uploadImage(file, folder: folder);
    return result?['url'];
  }

  /// Deleta uma imagem do Cloudinary pelo publicId.
  /// NOTA: Deleção via unsigned request requer habilitar "Allow unsigned
  /// destroy" nas configurações do Cloudinary, ou usar uma Cloud Function.
  /// A melhor alternativa é usar Firebase Cloud Functions como proxy.
  Future<bool> deleteImage(String publicId) async {
    try {
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/destroy');
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

  /// Deleta múltiplas imagens de uma vez
  Future<void> deleteImages(List<String> publicIds) async {
    for (final id in publicIds) {
      await deleteImage(id);
    }
  }

  // Upload foto de perfil
  Future<String?> uploadProfilePhoto(String uid, File file) async {
    return uploadImageUrl(file, folder: 'users/$uid');
  }

  // Upload logo da loja
  Future<String?> uploadStoreLogo(String storeId, File file) async {
    return uploadImageUrl(file, folder: 'stores/$storeId');
  }

  // Upload banner da loja
  Future<String?> uploadStoreBanner(String storeId, File file) async {
    return uploadImageUrl(file, folder: 'stores/$storeId');
  }

  // Upload foto de anúncio — retorna Map com url e publicId
  Future<Map<String, String>?> uploadAdPhotoFull(String adId, File file, int index) async {
    return uploadImage(file, folder: 'ads/$adId');
  }

  // Upload foto de anúncio — retorna apenas URL (compatibilidade)
  Future<String?> uploadAdPhoto(String adId, File file, int index) async {
    return uploadImageUrl(file, folder: 'ads/$adId');
  }

  // Selecionar imagem da galeria com corte opcional
  Future<File?> pickAndCropImage({
    required BuildContext context,
    bool camera = false,
    CropAspectRatio? aspectRatio,
    String title = 'Recortar Imagem',
  }) async {
    final XFile? picked = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1200, // Limita resolução antes do upload
      maxHeight: 1200,
      imageQuality: 75, // Compactação local antes de enviar
    );
    
    if (picked == null) return null;

    final croppedFile = await _cropper.cropImage(
      sourcePath: picked.path,
      aspectRatio: aspectRatio,
      compressQuality: 80, // Compactação adicional no crop
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

  // Selecionar múltiplas imagens
  Future<List<File>> pickMultipleImages({int max = 10}) async {
    final List<XFile> picked = await _picker.pickMultiImage(
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 75,
    );
    return picked.take(max).map((e) => File(e.path)).toList();
  }
}
