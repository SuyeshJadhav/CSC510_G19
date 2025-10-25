import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AppState extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  Map<String, Map<String, int>> balances = {
    'MILK': {'allowed': 2, 'used': 0},
    'CEREAL': {'allowed': 3, 'used': 0},
    'LEGUMES': {'allowed': 4, 'used': 0},
  };

  final List<Map<String, dynamic>> basket = [];

  bool _balancesLoaded = false;
  bool get balancesLoaded => _balancesLoaded;

  // We add a loading state for network activity
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _canon(String raw) {
    final trimmed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    return trimmed.toUpperCase();
  }

  /// balances/<docId>, fields like:
  ///   FRUIT & VEGETABLE CVB : {allowed: 8, used: 0}
  Future<void> loadBalances({String docId = 'default'}) async {
    if (_balancesLoaded) return;
    try {
      final snap = await _db.collection('balances').doc(docId).get();
      if (snap.exists) {
        final data = Map<String, dynamic>.from(snap.data() ?? {});
        balances = data.map((key, value) {
          final v = (value as Map<String, dynamic>? ?? const {});
          return MapEntry(_canon(key), {
            'allowed': (v['allowed'] ?? 0) as int,
            'used': (v['used'] ?? 0) as int,
          });
        });
      } else {
        // If no doc, we just use the hardcoded defaults
        print('Balance doc not found, using default values.');
      }
    } catch (e) {
      print('Error loading balances: $e');
    }
    _balancesLoaded = true;
    notifyListeners();
  }

  bool canAdd(String categoryRaw) {
    final cat = _canon(categoryRaw);
    final cap = balances[cat];
    if (cap == null) return true; // unknown category -> allow for MVP
    return (cap['used'] ?? 0) < (cap['allowed'] ?? 0);
  }

  Future<void> addItem(String upc, {String balancesDocId = 'default'}) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Fetch the product from Firestore.
      // We assume your collection is named 'apl' and the UPC is the doc ID.
      final docSnap = await _db.collection('apl').doc(upc).get();

      if (!docSnap.exists) {
        print('Product with UPC $upc not found.');
        // You can add a user-facing error message here
      } else {
        // 2. Extract data from the document
        final data = docSnap.data() as Map<String, dynamic>;
        final String name = data['name'] ?? 'Unknown Product';
        final String category = data['category'] ?? 'Uncategorized';

        // 3. Call the internal method to add the item to the basket
        _addItemToBasket(
          upc: upc,
          name: name,
          category: category,
          balancesDocId: balancesDocId,
        );
      }
    } catch (e) {
      print('Error fetching product: $e');
      // Handle error
    }

    _isLoading = false;
    notifyListeners();
  }

  void _addItemToBasket({
    required String upc,
    required String name,
    required String category,
    bool persistUsageToFirestore = true, // Defaulting to true
    String balancesDocId = 'default',
  }) {
    final cat = _canon(category);
    if (!canAdd(cat)) return;

    final idx = basket.indexWhere((e) => e['upc'] == upc && upc.isNotEmpty);
    if (idx >= 0) {
      basket[idx]['qty'] = (basket[idx]['qty'] ?? 1) + 1;
    } else {
      basket.add({'upc': upc, 'name': name, 'category': cat, 'qty': 1});
    }

    if (balances.containsKey(cat)) {
      balances[cat]!['used'] = (balances[cat]!['used'] ?? 0) + 1;
      if (persistUsageToFirestore) {
        // This is a "fire-and-forget" update. We don't await it.
        // It will update in the background.
        _db.collection('balances').doc(balancesDocId).update({
          '$cat.used': FieldValue.increment(1),
        });
      }
    }
  }

  Future<void> removeItem(
    String upc, {
    bool persistUsageToFirestore = false,
    String balancesDocId = 'default',
  }) async {
    final i = basket.indexWhere((e) => e['upc'] == upc);
    if (i < 0) return;

    final cat = _canon(basket[i]['category'] as String);

    if (balances.containsKey(cat)) {
      final newUsed = (balances[cat]!['used'] ?? 0) - 1;
      balances[cat]!['used'] = newUsed < 0 ? 0 : newUsed;
      if (persistUsageToFirestore) {
        await _db.collection('balances').doc(balancesDocId).update({
          '$cat.used': FieldValue.increment(-1),
        });
      }
    }

    final qty = (basket[i]['qty'] ?? 1) - 1;
    if (qty <= 0) {
      basket.removeAt(i);
    } else {
      basket[i]['qty']--;
    }
    notifyListeners();
  }
}
