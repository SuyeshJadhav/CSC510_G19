import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppState extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;

  /// Category caps loaded from Firestore. Keys are canonicalized (UPPERCASE).
  Map<String, Map<String, int>> balances = {};
  final List<Map<String, dynamic>> basket = [];

  bool _balancesLoaded = false;
  bool get balancesLoaded => _balancesLoaded;

  String _canon(String raw) {
    final trimmed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    return trimmed.toUpperCase();
  }

  /// balances/<docId>, fields like:
  ///   FRUIT & VEGETABLE CVB : {allowed: 8, used: 0}
  Future<void> loadBalances({String docId = 'default'}) async {
    if (_balancesLoaded) return;
    final snap = await _db.collection('balances').doc(docId).get();
    if (snap.exists) {
      final data = (snap.data() ?? {}) as Map<String, dynamic>;
      balances = data.map((key, value) {
        final v = (value as Map<String, dynamic>? ?? const {});
        return MapEntry(
          _canon(key),
          {
            'allowed': (v['allowed'] ?? 0) as int,
            'used': (v['used'] ?? 0) as int,
          },
        );
      });
    } else {
      balances = {}; // no caps configured -> unlimited (MVP)
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

  Future<void> addItem({
    required String upc,
    required String name,
    required String category,
    bool persistUsageToFirestore = false,
    String balancesDocId = 'default',
  }) async {
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
        await _db
            .collection('balances')
            .doc(balancesDocId)
            .update({'$cat.used': FieldValue.increment(1)});
      }
    }

    notifyListeners();
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
        await _db
            .collection('balances')
            .doc(balancesDocId)
            .update({'$cat.used': FieldValue.increment(-1)});
      }
    }

    final qty = (basket[i]['qty'] ?? 1) - 1;
    if (qty <= 0) {
      basket.removeAt(i);
    } else {
      basket[i]['qty'] = qty;
    }

    notifyListeners();
  }
}
