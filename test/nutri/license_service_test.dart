import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutrikuaa_app/nutri/application/license_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('activates a key and stores the returned instance', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/v1/licenses/activate');
      expect(request.bodyFields['license_key'], 'test-key');
      expect(request.bodyFields['instance_name'], 'Nutrikuaa Nutri Web');
      return http.Response(
        jsonEncode({
          'activated': true,
          'instance': {'id': 'instance-123'},
        }),
        200,
      );
    });

    final service = LicenseService(client: client);
    await service.activate('  test-key  ');

    final status = await service.status();
    expect(status.isActive, isTrue);
    expect(status.hasStoredKey, isTrue);
  });

  test('validation updates the locally cached active state', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nutrikuaa_nutri_license_key', 'test-key');
    await prefs.setString('nutrikuaa_nutri_instance_id', 'instance-123');
    await prefs.setBool('nutrikuaa_nutri_is_pro', true);

    final service = LicenseService(
      client: MockClient((request) async {
        expect(request.url.path, '/v1/licenses/validate');
        expect(request.bodyFields['license_key'], 'test-key');
        expect(request.bodyFields['instance_id'], 'instance-123');
        return http.Response(jsonEncode({'valid': false}), 200);
      }),
    );

    expect(await service.validate(), isFalse);
    expect((await service.status()).isActive, isFalse);
  });

  test('deactivation clears the stored key after API confirmation', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nutrikuaa_nutri_license_key', 'test-key');
    await prefs.setString('nutrikuaa_nutri_instance_id', 'instance-123');
    await prefs.setBool('nutrikuaa_nutri_is_pro', true);

    final service = LicenseService(
      client: MockClient((request) async {
        expect(request.url.path, '/v1/licenses/deactivate');
        return http.Response(jsonEncode({'deactivated': true}), 200);
      }),
    );

    await service.deactivate();

    final status = await service.status();
    expect(status.isActive, isFalse);
    expect(status.hasStoredKey, isFalse);
  });
}
