import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wolfbite/state/app_state.dart';

class MockUser extends Mock implements User {
  @override
  String get uid => 'test-uid';
}

void main() {
  group('AppState', () {
    late AppState appState;
    late FakeFirebaseFirestore fakeFirestore;
    late MockUser mockUser;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      appState = AppState(db: fakeFirestore);
      mockUser = MockUser();
    });

    test('updateUser loads user data when logged in', () async {
      await fakeFirestore.collection('users').doc('test-uid').set({
        'balances': {
          'MILK': {'allowed': 3, 'used': 1},
        },
        'basket': [
          {'upc': '12345', 'name': 'Milk', 'category': 'MILK', 'qty': 1},
        ],
      });

      appState.updateUser(mockUser);

      await Future.delayed(Duration.zero); // allow async operations to complete

      expect(appState.balancesLoaded, isTrue);
      expect(appState.balances['MILK']!['used'], 1);
      expect(appState.basket.first['upc'], '12345');
    });

    test('addItem adds a new item to the basket', () {
      appState.updateUser(mockUser);
      appState.addItem(upc: '12345', name: 'Milk', category: 'MILK');

      expect(appState.basket.length, 1);
      expect(appState.basket.first['upc'], '12345');
      expect(appState.balances['MILK']!['used'], 1);
    });

    test('incrementItem increases the quantity of an existing item', () {
      appState.updateUser(mockUser);
      appState.addItem(upc: '12345', name: 'Milk', category: 'MILK');
      appState.incrementItem('12345');

      expect(appState.basket.first['qty'], 2);
      expect(appState.balances['MILK']!['used'], 2);
    });

    test('decrementItem decreases the quantity of an existing item', () {
      appState.updateUser(mockUser);
      appState.addItem(upc: '12345', name: 'Milk', category: 'MILK');
      appState.incrementItem('12345');
      appState.decrementItem('12345');

      expect(appState.basket.first['qty'], 1);
      expect(appState.balances['MILK']!['used'], 1);
    });

    test('decrementItem removes an item when quantity reaches zero', () {
      appState.updateUser(mockUser);
      appState.addItem(upc: '12345', name: 'Milk', category: 'MILK');
      appState.decrementItem('12345');

      expect(appState.basket, isEmpty);
      expect(appState.balances['MILK']!['used'], 0);
    });

    test('addItem does not add an item if the category limit is reached', () {
      appState.updateUser(mockUser);
      appState.balances['MILK'] = {'allowed': 1, 'used': 1};

      final result = appState.addItem(
        upc: '54321',
        name: 'Yogurt',
        category: 'MILK',
      );

      expect(result, isFalse);
      expect(appState.basket.length, 0);
    });
  });
}
