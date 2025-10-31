import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppState extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;

  Map<String, Map<String, int>> balances = {
    'MILK': {'allowed': 2, 'used': 0},
    'CEREAL': {'allowed': 3, 'used': 0},
    'LEGUMES': {'allowed': 4, 'used': 0},
    'FRUIT & VEGETABLE CVB': {'allowed': 5, 'used': 0},
  };
  final List<Map<String, dynamic>> basket = [];

  bool _balancesLoaded = false;
  bool get balancesLoaded => _balancesLoaded;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _canon(String raw) {
    final trimmed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    return trimmed.toUpperCase();
  }

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
    // If not in balances, it's not a WIC item.
    if (_balancesLoaded && cap == null) return false;
    // If balances aren't loaded, allow it (for testing)
    if (cap == null) return true;
    return (cap['used'] ?? 0) < (cap['allowed'] ?? 0);
  }

  // --- THIS FUNCTION IS MODIFIED ---
  // It now returns a bool:
  // true = item was newly added
  // false = item was incremented or not added
  bool addItem({
    required String upc,
    required String name,
    required String category,
    bool persistUsageToFirestore = true,
    String balancesDocId = 'default',
  }) {
    if (upc.isEmpty) {
      print("Error: Tried to add item with empty UPC.");
      return false;
    }
    final cat = _canon(category);
    if (!canAdd(cat)) {
      return false; // Return false, limit reached
    }

    final idx = basket.indexWhere((e) => e['upc'] == upc);

    if (idx >= 0) {
      // If item already exists, just increment it
      incrementItem(upc);
      return false; // 'false' means it was an increment
    } else {
      // It's a new item
      basket.add({'upc': upc, 'name': name, 'category': cat, 'qty': 1});
      if (balances.containsKey(cat)) {
        balances[cat]!['used'] = (balances[cat]!['used'] ?? 0) + 1;
        if (persistUsageToFirestore) {
          _db.collection('balances').doc(balancesDocId).update({
            '$cat.used': FieldValue.increment(1),
          });
        }
      }
      notifyListeners();
      return true; // 'true' means it was a new item
    }
  }

  void incrementItem(
    String upc, {
    bool persistUsageToFirestore = true,
    String balancesDocId = 'default',
  }) {
    final i = basket.indexWhere((e) => e['upc'] == upc);
    if (i < 0) return; // Item not in basket

    final cat = _canon(basket[i]['category'] as String);
    if (!canAdd(cat)) return; // Check WIC balance

    // Increment quantity
    basket[i]['qty'] = (basket[i]['qty'] ?? 1) + 1;

    // Update WIC balance
    if (balances.containsKey(cat)) {
      balances[cat]!['used'] = (balances[cat]!['used'] ?? 0) + 1;
      if (persistUsageToFirestore) {
        _db.collection('balances').doc(balancesDocId).update({
          '$cat.used': FieldValue.increment(1),
        });
      }
    }
    notifyListeners();
  }

  Future<void> decrementItem(
    String upc, {
    String balancesDocId = 'default',
  }) async {
    final index = basket.indexWhere((item) => item['upc'] == upc);
    if (index == -1) return;

    final currentQty = basket[index]['qty'] as int;
    final category = _canon(basket[index]['category'] as String);

    if (currentQty > 1) {
      // Decrement quantity
      basket[index]['qty'] = currentQty - 1;
    } else {
      // Remove item if quantity would become 0
      basket.removeAt(index);
    }

    if (balances.containsKey(category)) {
      balances[category]!['used'] = (balances[category]!['used'] ?? 0) - 1;

      try {
        await _db.collection('balances').doc(balancesDocId).update({
          '$category.used': FieldValue.increment(-1),
        });
      } catch (e) {
        debugPrint('Error updating Firestore balance: $e');
      }
    }

    notifyListeners();

    try {
      final balanceRef = FirebaseFirestore.instance
          .collection('balances')
          .doc(balancesDocId);

      await balanceRef.set({
        'basket': basket,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating basket: $e');
    }
  }
}
