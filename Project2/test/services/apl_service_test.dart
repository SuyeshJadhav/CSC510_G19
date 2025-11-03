import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wolfbite/services/apl_service.dart';

void main() {
  group('AplService', () {
    late AplService aplService;
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      aplService = AplService(db: fakeFirestore);
    });

    test('findByUpc returns null for non-existent UPC', () async {
      final result = await aplService.findByUpc('non-existent-upc');
      expect(result, isNull);
    });

    test('findByUpc returns product data for existing UPC', () async {
      await fakeFirestore.collection('apl').doc('12345').set({
        'name': 'Test Product',
        'category': 'Test Category',
      });

      final result = await aplService.findByUpc('12345');

      expect(result, isNotNull);
      expect(result!['name'], 'Test Product');
    });

    test('substitutes returns empty list when none are found', () async {
      final result = await aplService.substitutes('non-existent-category');
      expect(result, isEmpty);
    });

    test(
      'substitutes returns eligible products in the same category',
      () async {
        await fakeFirestore.collection('apl').add({
          'name': 'Product 1',
          'category': 'Test Category',
          'eligible': true,
        });
        await fakeFirestore.collection('apl').add({
          'name': 'Product 2',
          'category': 'Test Category',
          'eligible': false,
        });
        await fakeFirestore.collection('apl').add({
          'name': 'Product 3',
          'category': 'Test Category',
          'eligible': true,
        });

        final result = await aplService.substitutes('Test Category');

        expect(result, hasLength(2));
        expect(result.any((p) => p['name'] == 'Product 1'), isTrue);
        expect(result.any((p) => p['name'] == 'Product 3'), isTrue);
      },
    );
  });
}
