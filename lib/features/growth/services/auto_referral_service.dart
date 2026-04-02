import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'referral_service.dart';

class AutoReferralService {
  AutoReferralService._();

  static final AppLinks _appLinks = AppLinks();

  static Future<void> captureInitialLink() async {
    final uri = await _appLinks.getInitialLink();
    if (uri == null) return;
    final code = uri.queryParameters['code']?.trim();
    if (code == null || code.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_invite_code', code);
  }

  static Future<void> captureUri(Uri uri) async {
    final code = uri.queryParameters['code']?.trim();
    if (code == null || code.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_invite_code', code);
  }

  static Stream<Uri> get uriStream => _appLinks.uriLinkStream;

  static Future<bool> claimPendingInviteIfAny() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('pending_invite_code')?.trim();
    if (code == null || code.isEmpty) return false;
    final ok = await ReferralService.claimInviteCode(code);
    if (ok) {
      await prefs.remove('pending_invite_code');
      return true;
    }
    return false;
  }
}
