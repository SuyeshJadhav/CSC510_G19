import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppState extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;

  Map<String, Map<String, int>> balances = {};
  List<Map<String, dynamic>> basket = [];
  String? _uid;

  bool _balancesLoaded = false;
  bool get balancesLoaded => _balancesLoaded;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// A simple getter to check if the user is logged in.
  /// The router will listen to this.
  bool get isLoggedIn => _uid != null;

  // Update user when auth state changes
  void updateUser(User? user) {
    _uid = user?.uid;

    if (user != null) {
      // Don't await here - let it load in the background
      _balancesLoaded = false; // Reset the flag
      loadBalances();
    } else {
      _clearState();
    }

    notifyListeners();
  }

  void _clearState() {
    balances = {};
    basket.clear();
    _balancesLoaded = false;
    _uid = null;
  }

  String _canon(String raw) {
    final trimmed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    return trimmed.toUpperCase();
  }

  Future<void> loadBalances() async {
    if (_uid == null) {
      _clearState();
      return;
    }

    if (_balancesLoaded) return;

    try {
      _isLoading = true;
      notifyListeners();

      final doc = await _db.collection('users').doc(_uid).get();

      if (!doc.exists) {
        await _createInitialBalances();
        _balancesLoaded = true;
        return;
      }

      final data = doc.data();
      if (data != null) {
        if (data['balances'] != null) {
          balances = Map<String, Map<String, int>>.from(
            (data['balances'] as Map).map(
              (k, v) => MapEntry(k.toString(), Map<String, int>.from(v as Map)),
            ),
          );
        }

        if (data['basket'] != null) {
          basket = List<Map<String, dynamic>>.from(data['basket']);
        }
      }

      _balancesLoaded = true;
    } catch (e) {
      debugPrint('Error loading balances: $e');
      _balancesLoaded = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _createInitialBalances() async {
    if (_uid == null) return;

    // These are the default WIC benefits for a new account
    final defaultBalances = {
      'MILK': {'allowed': 2, 'used': 0},
      'CEREAL': {'allowed': 3, 'used': 0},
      'LEGUMES': {'allowed': 4, 'used': 0},
      'FRUIT & VEGETABLE CVB': {'allowed': 5, 'used': 0},
    };

    try {
      await _db.collection('users').doc(_uid).set(
        {
          'balances': defaultBalances,
          'basket': [],
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      ); // Use merge:true to avoid overwriting email, etc.

      balances = defaultBalances;
      basket.clear();
    } catch (e) {
      debugPrint('Error creating initial balances: $e');
    }
  }

  bool canAdd(String categoryRaw) {
    final cat = _canon(categoryRaw);
    final cap = balances[cat];
    if (_balancesLoaded && cap == null) return false;
    if (cap == null) return true;
    return (cap['used'] ?? 0) < (cap['allowed'] ?? 0);
  }

  bool addItem({
    required String upc,
    required String name,
    required String category,
  }) {
    if (_uid == null) return false;
    if (upc.isEmpty) return false;

    final cat = _canon(category);
    final existingIndex = basket.indexWhere((item) => item['upc'] == upc);

    if (existingIndex != -1) {
      // Item already exists, call increment
      incrementItem(upc);
      return false; // 'false' means it was an increment
    }

    if (!canAdd(cat)) return false; // Check limit for new item

    basket.add({'upc': upc, 'name': name, 'category': cat, 'qty': 1});

    if (balances.containsKey(cat)) {
      balances[cat]!['used'] = (balances[cat]!['used'] ?? 0) + 1;
    }

    notifyListeners();
    _updateFirestoreData(); // Save to database
    return true; // 'true' means it was a new item
  }

  void incrementItem(String upc) {
    if (_uid == null) return;

    final index = basket.indexWhere((item) => item['upc'] == upc);
    if (index == -1) return;

    final category = _canon(basket[index]['category'] as String);

    if (!canAdd(category)) return;

    basket[index]['qty'] = (basket[index]['qty'] as int) + 1;

    if (balances.containsKey(category)) {
      balances[category]!['used'] = (balances[category]!['used'] ?? 0) + 1;
    }

    notifyListeners();
    _updateFirestoreData(); // Save to database
  }

  Future<void> decrementItem(String upc) async {
    if (_uid == null) return;

    final index = basket.indexWhere((item) => item['upc'] == upc);
    if (index == -1) return;

    final currentQty = basket[index]['qty'] as int;
    final category = _canon(basket[index]['category'] as String);

    if (currentQty > 1) {
      basket[index]['qty'] = currentQty - 1;
    } else {
      basket.removeAt(index);
    }

    if (balances.containsKey(category)) {
      balances[category]!['used'] = (balances[category]!['used'] ?? 0) - 1;
    }

    notifyListeners();
    await _updateFirestoreData(); // Save to database
  }

  Future<void> _updateFirestoreData() async {
    if (_uid == null) return;

    try {
      await _db.collection('users').doc(_uid).set({
        'basket': basket,
        'balances': balances,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating Firestore: $e');
    }
  }
}
