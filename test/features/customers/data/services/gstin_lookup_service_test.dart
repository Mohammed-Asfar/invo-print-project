import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:invo_print/core/errors/app_exception.dart';
import 'package:invo_print/features/customers/data/services/gstin_lookup_service.dart';

void main() {
  group('GstinLookupService', () {
    test('validates GSTIN from live RapidAPI status response shape', () async {
      final service = GstinLookupService(
        client: MockClient((request) async {
          expect(
            request.url.toString(),
            contains('/v1/gstin/18AAACR5055K1Z6/status'),
          );
          expect(request.headers['X-RapidAPI-Key'], 'key');
          return http.Response(
            '{"data":{"gstin":"18AAACR5055K1Z6","status":"Active","is_active":true}}',
            200,
          );
        }),
      );

      final result = await service.validate(
        gstin: '18aaacr5055k1z6',
        apiKey: 'key',
        host: 'powerful-gstin-tool.p.rapidapi.com',
        endpointPath: '/v1/gstin/{gstin}/status',
      );

      expect(result.gstin, '18AAACR5055K1Z6');
      expect(result.isValid, isTrue);
    });

    test('returns invalid when API reports inactive status', () async {
      final service = GstinLookupService(
        client: MockClient(
          (_) async => http.Response(
            '{"data":{"gstin":"18AAACR5055K1Z6","status":"Inactive"}}',
            200,
          ),
        ),
      );

      final result = await service.validate(
        gstin: '18AAACR5055K1Z6',
        apiKey: 'key',
        host: 'powerful-gstin-tool.p.rapidapi.com',
        endpointPath: '/v1/gstin/{gstin}/status',
      );

      expect(result.isValid, isFalse);
    });

    test(
      'extracts business details and address from details payload',
      () async {
        final service = GstinLookupService(
          client: MockClient(
            (_) async => http.Response('''
            {
              "data": {
                "gstin": "33AHOPY8219N1ZE",
                "legal_name": "TBS ENTERPRISES",
                "trade_name": "TBS",
                "place_of_business_principal": {
                  "address": {
                    "door_num": "No: 22",
                    "building_name": "MMS Complex",
                    "location": "Pudupattinam",
                    "district": "Kanchipuram",
                    "state": "Tamil Nadu",
                    "pin_code": "603102"
                  }
                }
              }
            }
            ''', 200),
          ),
        );

        final details = await service.lookup(
          gstin: '33AHOPY8219N1ZE',
          apiKey: 'key',
          host: 'powerful-gstin-tool.p.rapidapi.com',
          endpointPath: '/v1/gstin/{gstin}/details',
        );

        expect(details.displayName, 'TBS');
        expect(details.stateName, 'Tamil Nadu');
        expect(details.stateCode, '33');
        expect(details.formattedAddress, contains('No: 22'));
        expect(details.formattedAddress, contains('603102'));
      },
    );

    test('shows clear invalid GSTIN message for 422 responses', () async {
      final service = GstinLookupService(
        client: MockClient(
          (_) async =>
              http.Response('{"message":"Invalid GSTIN Number!"}', 422),
        ),
      );

      expect(
        () => service.lookup(
          gstin: 'bad',
          apiKey: 'key',
          host: 'powerful-gstin-tool.p.rapidapi.com',
          endpointPath: '/v1/gstin/{gstin}/details',
        ),
        throwsA(
          isA<AppException>().having(
            (error) => error.message,
            'message',
            'Invalid GSTIN Number!',
          ),
        ),
      );
    });
  });
}
