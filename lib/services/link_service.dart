import 'package:url_launcher/url_launcher.dart';

class LinkService {
  const LinkService._();

  static Future<bool> openExternal(String value) async {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme) {
      return false;
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
