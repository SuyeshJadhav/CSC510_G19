import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Central application state manager that handles user-scoped WIC benefits
/// balances and shopping basket data.
///
/// This [ChangeNotifier] persists data to [FirebaseFirestore] and derives
/// sensible default caps for each WIC category when first encountered.
/// APL (Approved Product List) documents do NOT carry caps - they are
/// managed entirely within this state.
///
/// Usage: Wire this into your app via [ChangeNotifierProxyProvider] in
/// [main.dart] to automatically sync with [FirebaseAuth] state changes.
class AppState extends ChangeNotifier {
  // final _db = FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  AppState({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  // ---------- Reactive data ----------

  /// User-specific WIC benefit balances by category.
  ///
  /// Maps canonical category names (uppercase, normalized) to balance objects
  /// containing:
  /// - `'allowed'`: [int]? - Maximum items allowed (null = uncapped, e.g., CVB)
  /// - `'used'`: [int] - Number of items currently in basket
  ///
  /// Example: `{ 'MILK': { 'allowed': 3, 'used': 1 } }`
  Map<String, Map<String, dynamic>> balances = {};

  /// The user's current shopping basket.
  ///
  /// Each item is a [Map] with keys:
  /// - `'upc'`: [String] - Universal Product Code
  /// - `'name'`: [String] - Product display name
  /// - `'category'`: [String] - Canonical category (uppercase)
  /// - `'qty'`: [int] - Quantity of this item
  final List<Map<String, dynamic>> basket = [];

  // ---------- Auth/user ----------

  /// The currently authenticated user's unique ID from [FirebaseAuth].
  ///
  /// Null when no user is logged in.
  String? _uid;

  /// Whether user-specific [balances] data has been loaded from [FirebaseFirestore].
  ///
  /// Screens can check this before displaying balance information.
  bool _balancesLoaded = false;

  /// Public getter for [_balancesLoaded].
  ///
  /// Returns true after [loadUserState] completes successfully.
  bool get balancesLoaded => _balancesLoaded;

  // ---------- Public: wire auth state into AppState ----------

  /// Updates the internal user reference and triggers state reload.
  ///
  /// This is called by the [ChangeNotifierProxyProvider] in [main.dart]
  /// whenever the [FirebaseAuth] state changes. If [user] is null,
  /// all data is cleared. Otherwise, [loadUserState] is called in the
  /// background to fetch persisted data.
  ///
  /// Side effects:
  /// - Clears [balances] and [basket] if logged out
  /// - Calls [notifyListeners] to rebuild widgets
  /// - Initiates [loadUserState] for logged-in users
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

  /// Clears all local state data.
  ///
  /// Resets [balances], [basket], and [_balancesLoaded] flag.
  /// Does NOT persist to [FirebaseFirestore] - use [_persist] for that.
  void _clear() {
    balances = {};
    basket.clear();
    _balancesLoaded = false;
  }

  /// Canonicalizes a category string for consistent storage and comparison.
  ///
  /// Trims whitespace, collapses multiple spaces to single spaces, and
  /// converts to uppercase.
  ///
  /// Example: `"  Milk Products  "` becomes `"MILK PRODUCTS"`
  String _canon(String raw) =>
      raw.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();

  /// Derives a default allowed quantity for a newly encountered category.
  ///
  /// Returns `null` for uncapped categories (CVB, Fruits & Vegetables).
  /// Returns sensible defaults for common WIC categories:
  /// - Dairy (milk, cheese, yogurt): 3-4 items
  /// - Bread & Grains: 2 items
  /// - Protein (meat, beans, peanut butter): 1-2 items
  /// - Juice: 1 item
  /// - Default: 2 items
  ///
  /// This is called by [_ensureCategoryInit] when a category is first added
  /// to [balances].
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
      return 3;
    }
    // Bread
    if (canonCat.contains('BREAD') ||
        canonCat.contains('GRAIN') ||
        canonCat.contains('CEREAL')) {
      return 2;
    }
    // Protein
    if (canonCat.contains('MEAT') ||
        canonCat.contains('BEAN') ||
        canonCat.contains('PEANUT')) {
      return 1;
    }
    // Juice
    if (canonCat.contains('JUICE')) {
      return 1;
    }
    // Default
    return 2;
  }

  /// Ensures the given canonical category exists in [balances] with defaults.
  ///
  /// If [canonCat] is not yet in [balances], initializes it with:
  /// - `'allowed'`: derived from [_deriveAllowed]
  /// - `'used'`: 0
  ///
  /// If it exists, ensures both keys are present.
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

  /// Checks if another item from the given canonical category can be added.
  ///
  /// Returns true if:
  /// - The category is uncapped (allowed is null), OR
  /// - The used count is less than the allowed count
  ///
  /// Returns false if the limit has been reached.
  bool _canAddCanon(String canonCat) {
    final allowed = balances[canonCat]?['allowed'];
    final used = (balances[canonCat]?['used'] ?? 0) as int;
    if (allowed is int) return used < allowed;
    return true; // uncapped
  }

  // ---------- Firestore I/O ----------

  /// Loads user-specific [balances] and [basket] from [FirebaseFirestore].
  ///
  /// Fetches the document at `users/{uid}` and populates local state.
  /// If the document doesn't exist, creates an empty scaffold via [_persist].
  /// All category names are canonicalized via [_canon].
  ///
  /// Side effects:
  /// - Sets [_balancesLoaded] to true on completion
  /// - Calls [notifyListeners] to update UI
  /// - Creates Firestore document for first-time users
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

  /// Persists current [balances] and [basket] to [FirebaseFirestore].
  ///
  /// Updates the document at `users/{uid}` with current state and a
  /// server timestamp. Uses merge mode to preserve other fields.
  ///
  /// This is called after any mutation ([addItem], [incrementItem],
  /// [decrementItem]) to keep Firestore in sync.
  Future<void> _persist() async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).set({
      'balances': balances,
      'basket': basket,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---------- Public API used by screens ----------

  /// Returns true if another item from the given category can be added.
  ///
  /// The [categoryRaw] string is canonicalized before checking against
  /// [balances]. Returns true for first-time categories (will be capped
  /// on first [addItem] call).
  ///
  /// Used by UI to enable/disable "Add" buttons.
  bool canAdd(String categoryRaw) {
    final cat = _canon(categoryRaw);
    if (!balances.containsKey(cat)) return true; // first time seen -> allowed
    return _canAddCanon(cat);
  }

  /// Adds one item to the [basket] and updates [balances].
  ///
  /// If an item with the same [upc] already exists, increments its quantity
  /// via [incrementItem] and returns false.
  ///
  /// Otherwise, creates a new basket line with qty=1, increments the category's
  /// used count, and persists via [_persist].
  ///
  /// Parameters:
  /// - [upc]: Universal Product Code
  /// - [name]: Display name for the product
  /// - [category]: Raw category string (will be canonicalized)
  ///
  /// Returns true if a new line was created, false if only quantity increased.
  ///
  /// Side effects:
  /// - Calls [_ensureCategoryInit] to set default caps
  /// - Calls [_persist] to save to [FirebaseFirestore]
  /// - Calls [notifyListeners] to update UI
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

  /// Increases the quantity of an existing basket item by 1.
  ///
  /// Searches [basket] for an item with matching [upc], increments its
  /// `'qty'` field, and updates the category's used count in [balances].
  ///
  /// Does nothing if:
  /// - No user is logged in
  /// - Item not found in basket
  /// - Category limit would be exceeded
  ///
  /// Side effects:
  /// - Calls [_persist] to save to [FirebaseFirestore]
  /// - Calls [notifyListeners] to update UI
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

  /// Decreases the quantity of an existing basket item by 1.
  ///
  /// If the new quantity reaches 0, the entire item is removed from [basket].
  /// Updates the category's used count in [balances] accordingly.
  ///
  /// Does nothing if:
  /// - No user is logged in
  /// - Item not found in basket
  ///
  /// Side effects:
  /// - Calls [_persist] to save to [FirebaseFirestore]
  /// - Calls [notifyListeners] to update UI
  void decrementItem(String upc) {
    if (_uid == null) return;
    final i = basket.indexWhere((e) => e['upc'] == upc);
    if (i < 0) return;

    final cat = _canon(basket[i]['category'] as String);
    final newQty = (basket[i]['qty'] ?? 1) - 1;

    if (balances.containsKey(cat)) {
      final used = (balances[cat]!['used'] ?? 0) as int;
      balances[cat]!['used'] = (used - 1).clamp(0, 999);
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
}
