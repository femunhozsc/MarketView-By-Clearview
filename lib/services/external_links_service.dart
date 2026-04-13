import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ExternalLinksService {
  static const String privacyPolicyUrl = String.fromEnvironment(
    'MARKETVIEW_PRIVACY_URL',
  );
  static const String termsUrl = String.fromEnvironment(
    'MARKETVIEW_TERMS_URL',
  );
  static const String supportEmail = String.fromEnvironment(
    'MARKETVIEW_SUPPORT_EMAIL',
    defaultValue: 'suporte@marketview.app',
  );
  static const String supportWhatsappUrl = String.fromEnvironment(
    'MARKETVIEW_SUPPORT_WHATSAPP_URL',
  );
  static const String appReviewUrl = String.fromEnvironment(
    'MARKETVIEW_APP_REVIEW_URL',
  );

  Future<bool> openUrlString(String url) async {
    if (url.trim().isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<bool> composeSupportEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      queryParameters: const {
        'subject': 'Suporte MarketView',
      },
    );
    return launchUrl(uri);
  }

  Future<void> openOrExplain(
    BuildContext context, {
    required String? url,
    required String unavailableMessage,
  }) async {
    final success = await openUrlString(url ?? '');
    if (!context.mounted || success) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(unavailableMessage)),
    );
  }
}
