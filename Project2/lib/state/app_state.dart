import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppState extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;

  // Remove 'final' keyword to allow reassignment
  Map<String, Map<String, int>> balances = {
    'MILK': {'allowed': 2, 'used': 0},
    'CEREAL': {'allowed': 3, 'used': 0},
    'LEGUMES': {'allowed': 4, 'used': 0},
    'FRUIT & VEGETABLE CVB': {'allowed': 5, 'used': 0},
  };

  List<Map<String, dynamic>> basket = [];
  String? _uid;

  bool _balancesLoaded = false;
  bool get balancesLoaded => _balancesLoaded;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // This is the getter your AppRouter needs
  bool get isLoggedIn => _uid != null;

  // This is called by main.dart when the user logs in or out
  void updateUser(User? user) {
    debugPrint('updateUser called: user = ${user?.uid}, current _uid = $_uid');

    if (user != null && user.uid != _uid) {
      _uid = user.uid; // ← MAKE SURE THIS LINE EXISTS
      _balancesLoaded = false;
      debugPrint('🆕 New user logged in: $_uid');
      loadBalances();
    } else if (user == null && _uid != null) {
      debugPrint('👋 User logged out');
      _clearState();
    }
    debugPrint('📊 Balances count: ${balances.length}');
    notifyListeners();
  }

  void _clearState() {
    balances = {
      'MILK': {'allowed': 2, 'used': 0},
      'CEREAL': {'allowed': 3, 'used': 0},
      'LEGUMES': {'allowed': 4, 'used': 0},
      'FRUIT & VEGETABLE CVB': {'allowed': 5, 'used': 0},
    }; // Now this works
    basket.clear();
    _balancesLoaded = false;
    _uid = null;
  }

  String _canon(String raw) {
    final trimmed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    return trimmed.toUpperCase();
  }

  // This function now uses the internal _uid
  Future<void> loadBalances() async {
    debugPrint('🔍 loadBalances called, _uid = $_uid');

    if (_uid == null) {
      debugPrint('⚠️ _uid is null, cannot load balances');
      return;
    }

    if (_balancesLoaded) {
      debugPrint('✅ Balances already loaded, skipping');
      return;
    }

    try {
      _isLoading = true;
      notifyListeners();

      debugPrint('📡 Querying Firestore for user: $_uid');
      final doc = await _db.collection('users').doc(_uid).get();

      if (!doc.exists) {
        debugPrint('❌ User document does not exist, creating initial balances');
        await _createInitialBalances();
      } else {
        debugPrint('✅ User document exists, parsing data');
        final data = doc.data();

        if (data != null && data.containsKey('balances')) {
          final balanceData = data['balances'] as Map<String, dynamic>;
          debugPrint('💰 Loaded balance data: $balanceData');

          balances = balanceData.map((key, value) {
            final v = (value as Map<String, dynamic>? ?? const {});
            return MapEntry(_canon(key), {
              'allowed': (v['allowed'] ?? 0) as int,
              'used': (v['used'] ?? 0) as int,
            });
          });
        } else {
          debugPrint('⚠️ No balances found in document, creating defaults');
          await _createInitialBalances();
          return;
        }

        if (data.containsKey('basket')) {
          final basketData = data['basket'] as List<dynamic>? ?? [];
          basket.clear();
          basket.addAll(basketData.map((item) => item as Map<String, dynamic>));
        }
      }

      _balancesLoaded = true;
      debugPrint('✅ Balances loaded successfully: ${balances.keys.toList()}');
    } catch (e) {
      debugPrint('❌ Error loading balances: $e');
      _balancesLoaded = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // This creates the default data for a NEW user
  Future<void> _createInitialBalances() async {
    if (_uid == null) {
      debugPrint('❌ Cannot create balances: _uid is null');
      return;
    }

    final defaultBalances = {
      'MILK': {'allowed': 2, 'used': 0},
      'CEREAL': {'allowed': 3, 'used': 0},
      'LEGUMES': {'allowed': 4, 'used': 0},
      'FRUIT & VEGETABLE CVB': {'allowed': 5, 'used': 0},
    };

    try {
      debugPrint('🆕 Creating initial balances document for: $_uid');

      await _db.collection('users').doc(_uid).set({
        'balances': defaultBalances,
        'basket': [],
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      balances = defaultBalances;
      basket.clear();

      debugPrint('✅ Initial balances created: ${balances.keys.toList()}');
    } catch (e) {
      debugPrint('❌ Error creating initial balances: $e');
    }
  }

  bool canAdd(String categoryRaw) {
    final cat = _canon(categoryRaw);
    final cap = balances[cat];
    // If balances are loaded and the category isn't in the map, it's not allowed.
    if (_balancesLoaded && cap == null) return false;
    if (cap == null) return true; // Failsafe for before loading
    return (cap['used'] ?? 0) < (cap['allowed'] ?? 0);
  }

  // Returns true if a new item was added, false if incremented or failed
  bool addItem({
    required String upc,
    required String name,
    required String category,
  }) {
    if (_uid == null) return false;
    if (upc.isEmpty) return false;

    final cat = _canon(category);
    if (!canAdd(cat)) return false; // Check limit

    final idx = basket.indexWhere((e) => e['upc'] == upc);

    if (idx >= 0) {
      // Item already exists, just increment it
      incrementItem(upc);
      return false; // 'false' = incremented
    } else {
      // It's a new item
      basket.add({'upc': upc, 'name': name, 'category': cat, 'qty': 1});
      if (balances.containsKey(cat)) {
        balances[cat]!['used'] = (balances[cat]!['used'] ?? 0) + 1;
      }
      notifyListeners();
      _updateFirestoreData(); // Save to cloud
      return true; // 'true' = new item
    }
  }

  void incrementItem(String upc) {
    if (_uid == null) return;
    final i = basket.indexWhere((e) => e['upc'] == upc);
    if (i < 0) return;

    final cat = _canon(basket[i]['category'] as String);
    if (!canAdd(cat)) return;

    basket[i]['qty'] = (basket[i]['qty'] ?? 1) + 1;

    if (balances.containsKey(cat)) {
      balances[cat]!['used'] = (balances[cat]!['used'] ?? 0) + 1;
    }
    notifyListeners();
    _updateFirestoreData(); // Save to cloud
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
      final newUsed = (balances[category]!['used'] ?? 0) - 1;
      balances[category]!['used'] = newUsed < 0 ? 0 : newUsed;
    }

    notifyListeners();
    await _updateFirestoreData(); // Save to cloud
  }

  // This is the single function to save the user's data
  Future<void> _updateFirestoreData() async {
    if (_uid == null) return;
    try {
      await _db.collection('users').doc(_uid).set({
        'balances': balances,
        'basket': basket,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // merge:true won't overwrite email/name
    } catch (e) {
      debugPrint('Error updating Firestore: $e');
    }
  }
}
