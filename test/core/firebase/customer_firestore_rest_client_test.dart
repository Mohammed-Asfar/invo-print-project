import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/core/errors/app_exception.dart';
import 'package:invo_print/core/firebase/customer_firestore_rest_client.dart';

import '../../helpers/fake_customer_firestore_rest_client.dart';

void main() {
  group('FirestoreWritePrecondition', () {
    test('builds query parameters for exists and update time cases', () {
      expect(const FirestoreWritePrecondition.mustExist().toQueryParameters(), {
        'currentDocument.exists': 'true',
      });
      expect(
        const FirestoreWritePrecondition.mustNotExist().toQueryParameters(),
        {'currentDocument.exists': 'false'},
      );
      expect(
        const FirestoreWritePrecondition(
          updateTime: '2026-06-02T10:00:00Z',
        ).toQueryParameters(),
        {'currentDocument.updateTime': '2026-06-02T10:00:00Z'},
      );
      expect(
        const FirestoreWritePrecondition(
          exists: true,
          updateTime: '2026-06-02T10:00:00Z',
        ).toQueryParameters(),
        {
          'currentDocument.exists': 'true',
          'currentDocument.updateTime': '2026-06-02T10:00:00Z',
        },
      );
    });
  });

  group('FakeCustomerFirestoreRestClient', () {
    test(
      'returns snapshot metadata and enforces update-time preconditions',
      () async {
        final firestore = FakeCustomerFirestoreRestClient({
          'settings/app': {'invoiceNextNumber': 7},
        });

        final snapshot = await firestore.getDocumentSnapshot('settings', 'app');
        expect(snapshot, isNotNull);
        expect(snapshot!.data['invoiceNextNumber'], 7);
        expect(snapshot.updateTime, isNotEmpty);

        await firestore.setDocument(
          'settings',
          'app',
          {'invoiceNextNumber': 8},
          precondition: FirestoreWritePrecondition(
            updateTime: snapshot.updateTime,
          ),
        );

        await expectLater(
          () => firestore.setDocument(
            'settings',
            'app',
            {'invoiceNextNumber': 9},
            precondition: FirestoreWritePrecondition(
              updateTime: snapshot.updateTime,
            ),
          ),
          throwsA(
            isA<AppException>().having(
              (error) => error.message,
              'message',
              contains('FAILED_PRECONDITION'),
            ),
          ),
        );
      },
    );

    test('enforces must-exist and must-not-exist preconditions', () async {
      final firestore = FakeCustomerFirestoreRestClient();

      await expectLater(
        () => firestore.setDocument(
          'settings',
          'app',
          {'invoiceNextNumber': 1},
          precondition: const FirestoreWritePrecondition.mustExist(),
        ),
        throwsA(
          isA<AppException>().having(
            (error) => error.message,
            'message',
            contains('FAILED_PRECONDITION'),
          ),
        ),
      );

      await firestore.setDocument(
        'settings',
        'app',
        {'invoiceNextNumber': 1},
        precondition: const FirestoreWritePrecondition.mustNotExist(),
      );

      await expectLater(
        () => firestore.setDocument(
          'settings',
          'app',
          {'invoiceNextNumber': 2},
          precondition: const FirestoreWritePrecondition.mustNotExist(),
        ),
        throwsA(
          isA<AppException>().having(
            (error) => error.message,
            'message',
            contains('FAILED_PRECONDITION'),
          ),
        ),
      );
    });
  });
}
