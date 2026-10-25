import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LicenseException implements Exception {
  final String message;

  const LicenseException(this.message);

  @override
  String toString() => message;
}

class LicenseStatus {
  final bool isActive;
  final bool hasStoredKey;

  const LicenseStatus({required this.isActive, required this.hasStoredKey});
}

class LicenseService {
  static const checkoutUrl =
      'https://nutrikuaa.lemonsqueezy.com/checkout/buy/'
      '6d867eeb-6384-42d4-ac37-f4e014b044e8';

  static const _activateEndpoint =
      'https://api.lemonsqueezy.com/v1/licenses/activate';
  static const _validateEndpoint =
      'https://api.lemonsqueezy.com/v1/licenses/validate';
  static const _deactivateEndpoint =
      'https://api.lemonsqueezy.com/v1/licenses/deactivate';

  static const _prefIsPro = 'nutrikuaa_nutri_is_pro';
  static const _prefKey = 'nutrikuaa_nutri_license_key';
  static const _prefInstanceId = 'nutrikuaa_nutri_instance_id';

  final http.Client _client;

  LicenseService({http.Client? client}) : _client = client ?? http.Client();

  Future<LicenseStatus> status() async {
    final prefs = await SharedPreferences.getInstance();
    return LicenseStatus(
      isActive: prefs.getBool(_prefIsPro) ?? false,
      hasStoredKey: prefs.getString(_prefKey)?.isNotEmpty ?? false,
    );
  }

  Future<bool> isProActive() async => (await status()).isActive;

  void close() => _client.close();

  Future<void> activate(String licenseKey) async {
    final normalizedKey = licenseKey.trim();
    if (normalizedKey.isEmpty) {
      throw const LicenseException('Enter a license key.');
    }

    final response = await _post(_activateEndpoint, {
      'license_key': normalizedKey,
      'instance_name': 'Nutrikuaa Nutri Web',
    });

    if (response['activated'] != true) {
      throw LicenseException(
        _errorMessage(response, 'License activation failed.'),
      );
    }

    final instance = response['instance'];
    final instanceId = instance is Map ? instance['id']?.toString() : null;
    if (instanceId == null || instanceId.isEmpty) {
      throw const LicenseException(
        'Lemon Squeezy activated the key but returned no instance ID.',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, normalizedKey);
    await prefs.setString(_prefInstanceId, instanceId);
    await prefs.setBool(_prefIsPro, true);
  }

  Future<bool> validate() async {
    final prefs = await SharedPreferences.getInstance();
    final licenseKey = prefs.getString(_prefKey);
    final instanceId = prefs.getString(_prefInstanceId);

    if (licenseKey == null || instanceId == null) {
      await prefs.setBool(_prefIsPro, false);
      return false;
    }

    final response = await _post(_validateEndpoint, {
      'license_key': licenseKey,
      'instance_id': instanceId,
    });
    final isValid = response['valid'] == true;
    await prefs.setBool(_prefIsPro, isValid);
    return isValid;
  }

  Future<void> deactivate() async {
    final prefs = await SharedPreferences.getInstance();
    final licenseKey = prefs.getString(_prefKey);
    final instanceId = prefs.getString(_prefInstanceId);

    if (licenseKey == null || instanceId == null) {
      await _clearLicense(prefs);
      return;
    }

    final response = await _post(_deactivateEndpoint, {
      'license_key': licenseKey,
      'instance_id': instanceId,
    });
    if (response['deactivated'] != true) {
      throw LicenseException(
        _errorMessage(response, 'License deactivation failed.'),
      );
    }

    await _clearLicense(prefs);
  }

  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, String> fields,
  ) async {
    final response = await _client.post(Uri.parse(endpoint), body: fields);

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const LicenseException('Unexpected response from Lemon Squeezy.');
    }
    final result = Map<String, dynamic>.from(decoded);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LicenseException(
        _errorMessage(
          result,
          'Lemon Squeezy request failed (${response.statusCode}).',
        ),
      );
    }

    return result;
  }

  String _errorMessage(Map<String, dynamic> response, String fallback) {
    final error = response['error'];
    if (error is String && error.isNotEmpty) return error;
    return fallback;
  }

  Future<void> _clearLicense(SharedPreferences prefs) async {
    await prefs.remove(_prefKey);
    await prefs.remove(_prefInstanceId);
    await prefs.setBool(_prefIsPro, false);
  }
}
