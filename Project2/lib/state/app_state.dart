import 'package:flutter/foundation.dart';

class AppState extends ChangeNotifier {
  final Map<String, Map<String, int>> balances = {
    'MILK': {'allowed': 2, 'used': 0},
    'CEREAL': {'allowed': 3, 'used': 0},
    'LEGUMES': {'allowed': 4, 'used': 0},
  };

  final List<Map<String, dynamic>> basket = [];

  bool canAdd(String category) =>
      (balances[category]?['used'] ?? 0) < (balances[category]?['allowed'] ?? 0);

  void addItem({required String upc, required String name, required String category}) {
    if (!canAdd(category)) return;
    final i = basket.indexWhere((e) => e['upc'] == upc);
    if (i >= 0) {
      basket[i]['qty']++;
    } else {
      basket.add({'upc': upc, 'name': name, 'category': category, 'qty': 1});
    }
    balances[category]!['used'] = (balances[category]!['used'] ?? 0) + 1;
    notifyListeners();
  }

  void removeItem(String upc) {
    final i = basket.indexWhere((e) => e['upc'] == upc);
    if (i < 0) return;
    final cat = basket[i]['category'] as String;
    balances[cat]!['used'] = (balances[cat]!['used'] ?? 1) - 1;
    if (basket[i]['qty'] == 1) {
      basket.removeAt(i);
    } else {
      basket[i]['qty']--;
    }
    notifyListeners();
  }
}
