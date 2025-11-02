import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Central app state: user-scoped balances (caps) + basket, persisted to Firestore.
/// APL documents do NOT carry caps. Caps are derived here unless the user doc
/// already specifies them.
class AppState extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;

  // ---------- Reactive data ----------
  // balances: { CANON_CAT : { 'allowed': int? (null = uncapped), 'used': int } }
  Map<String, Map<String, dynamic>> balances = {};
  final List<Map<String, dynamic>> basket = [];

  // ---------- Auth/user ----------
  String? _uid;
  bool _balancesLoaded = false;
  bool get balancesLoaded => _balancesLoaded;

  // ---------- Public: wire auth state into AppState ----------
  void updateUser(User? user) {
    _uid = user?.uid;
    if (_uid == null) {
      _clear();
      notifyListeners();
      return;
    }
    _balancesLoaded = false;
    // fire-and-forget load; UI can check balancesLoaded
    // ignore: discarded_futures
    loadUserState();
    notifyListeners();
  }

  // ---------- Helpers ----------
  void _clear() {
    balances = {};
    basket.clear();
    _balancesLoaded = false;
  }

  String _canon(String raw) =>
      raw.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();

  /// Derive a sensible default cap when a category is first seen.
  /// Return `null` to mark uncapped (e.g., CVB/produce).
  int? _deriveAllowed(String canonCat) {
    // CVB / Fruit & Veg — uncapped
    if (canonCat.contains('CVB') ||
        canonCat.contains('FRUIT') ||
        canonCat.contains('VEGETABLE')) {
      return null;
    }
    // Dairy
    if (canonCat.contains('MILK') ||
        canonCat.contains('CHEESE') ||
        canonCat.contains('YOGURT') ||
        canonCat.contains('DAIRY')) {
      return 4;
    }
    // Cereal / grains
    if (canonCat.contains('CEREAL') ||
        canonCat.contains('OAT') ||
        canonCat.contains('GRAIN')) {
      return 6;
    }
    // Protein: legumes/beans/eggs
    if (canonCat.contains('LEGUME') ||
        canonCat.contains('BEAN') ||
        canonCat.contains('PEA') ||
        canonCat.contains('LENTIL') ||
        canonCat.contains('EGG') ||
        canonCat.contains('PEANUT') ||
        canonCat.contains('NUT')) {
      return 6;
    }
    // Juice / infant (example)
    if (canonCat.contains('JUICE') ||
        canonCat.contains('INFANT') ||
        canonCat.contains('FORMULA')) {
      return 4;
    }
    // Default soft cap
    return 5;
  }

  void _ensureCategoryInit(String canonCat) {
    if (!balances.containsKey(canonCat)) {
      balances[canonCat] = {
        'allowed': _deriveAllowed(canonCat), // may be null (uncapped)
        'used': 0,
      };
      return;
    }
    final m = balances[canonCat]!;
    m.putIfAbsent('allowed', () => _deriveAllowed(canonCat));
    m.putIfAbsent('used', () => 0);
  }

  bool _canAddCanon(String canonCat) {
    final allowed = balances[canonCat]?['allowed'];
    final used = (balances[canonCat]?['used'] ?? 0) as int;
    if (allowed is int) return used < allowed;
    return true; // uncapped
  }

  // ---------- Firestore I/O ----------
  Future<void> loadUserState() async {
    if (_uid == null) {
      _clear();
      notifyListeners();
      return;
    }

    try {
      final doc = await _db.collection('users').doc(_uid).get();
      final data = doc.data();

      if (data == null) {
        // First-time user: start empty; caps derive on demand
        _clear();
        await _persist(); // create doc scaffold
      } else {
        // balances
        final b = (data['balances'] as Map?) ?? {};
        balances = b.map((k, v) {
          final key = _canon(k.toString());
          final allowed = (v is Map && v['allowed'] is int)
              ? v['allowed'] as int
              : null;
          final used = (v is Map && v['used'] is int) ? v['used'] as int : 0;
          return MapEntry(key, {'allowed': allowed, 'used': used});
        });

        // basket
        final raw = (data['basket'] as List?) ?? [];
        basket
          ..clear()
          ..addAll(
            raw.whereType<Map>().map(
              (m) => {
                'upc': (m['upc'] ?? '').toString(),
                'name': (m['name'] ?? '').toString(),
                'category': _canon((m['category'] ?? '').toString()),
                'qty': (m['qty'] is int) ? m['qty'] as int : 1,
              },
            ),
          );
      }
    } finally {
      _balancesLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).set({
      'balances': balances,
      'basket': basket,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---------- Public API used by screens ----------

  /// Returns true if another item from this category can be added.
  bool canAdd(String categoryRaw) {
    final cat = _canon(categoryRaw);
    if (!balances.containsKey(cat)) return true; // first time seen -> allowed
    return _canAddCanon(cat);
  }

  /// Add one item. Returns `true` if this created a new basket line, `false`
  /// if it only incremented an existing line. Persists in the background.
  bool addItem({
    required String upc,
    required String name,
    required String category,
  }) {
    if (_uid == null) return false;
    final cat = _canon(category);

    _ensureCategoryInit(cat);
    if (!_canAddCanon(cat)) return false;

    final idx = basket.indexWhere((e) => e['upc'] == upc && upc.isNotEmpty);
    if (idx >= 0) {
      // existing line -> increment path
      incrementItem(upc);
      return false;
    }

    basket.add({'upc': upc, 'name': name, 'category': cat, 'qty': 1});
    balances[cat]!['used'] = (balances[cat]!['used'] ?? 0) + 1;

    // persist (fire-and-forget)
    // ignore: discarded_futures
    _persist();
    notifyListeners();
    return true;
  }

  void incrementItem(String upc) {
    if (_uid == null) return;
    final i = basket.indexWhere((e) => e['upc'] == upc);
    if (i < 0) return;

    final cat = _canon(basket[i]['category'] as String);
    _ensureCategoryInit(cat);
    if (!_canAddCanon(cat)) return;

    basket[i]['qty'] = (basket[i]['qty'] ?? 1) + 1;
    balances[cat]!['used'] = (balances[cat]!['used'] ?? 0) + 1;

    // ignore: discarded_futures
    _persist();
    notifyListeners();
  }

  void decrementItem(String upc) {
    if (_uid == null) return;
    final i = basket.indexWhere((e) => e['upc'] == upc);
    if (i < 0) return;

    final cat = _canon(basket[i]['category'] as String);
    final newQty = (basket[i]['qty'] ?? 1) - 1;

    if (balances.containsKey(cat)) {
      final used = (balances[cat]!['used'] ?? 0) as int;
      balances[cat]!['used'] = (used - 1).clamp(0, 1 << 30);
    }

    if (newQty <= 0) {
      basket.removeAt(i);
    } else {
      basket[i]['qty'] = newQty;
    }

    // ignore: discarded_futures
    _persist();
    notifyListeners();
  }

  /// Optional: set/override a cap from UI/admin. `null` = uncapped.
  Future<void> setCap(String category, int? allowed) async {
    if (_uid == null) return;
    final cat = _canon(category);
    _ensureCategoryInit(cat);
    balances[cat]!['allowed'] = allowed;
    await _persist();
    notifyListeners();
  }
}
