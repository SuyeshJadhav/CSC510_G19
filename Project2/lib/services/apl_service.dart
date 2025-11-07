import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for querying the Approved Product List (APL) from [FirebaseFirestore].
///
/// The APL collection contains WIC-eligible products with their UPC codes,
/// names, categories, and eligibility status. This service provides methods
/// to look up products and find substitutes within the same category.
class AplService {
  // final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  AplService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  /// Looks up a product by its Universal Product Code (UPC).
  ///
  /// Queries the `apl` collection in [FirebaseFirestore] using the [upc]
  /// as the document ID.
  ///
  /// Returns a [Map] with product data (name, category, eligible, etc.)
  /// if found, or null if the product doesn't exist in the APL.
  ///
  /// Example return value:
  /// ```dart
  /// {
  ///   'upc': '000000743266',
  ///   'name': 'Whole Milk',
  ///   'category': 'Milk',
  ///   'eligible': true
  /// }
  /// ```
  Future<Map<String, dynamic>?> findByUpc(String upc) async {
    final doc = await _db.collection('apl').doc(upc).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  /// Finds WIC-eligible substitute products in the same category.
  ///
  /// Queries the `apl` collection for products matching the given [category]
  /// where `eligible` is true. Results are limited to [max] items (default 3).
  ///
  /// This is useful when a user's preferred product would exceed their
  /// category limit, allowing the app to suggest alternatives.
  ///
  /// Parameters:
  /// - [category]: The product category to search within
  /// - [max]: Maximum number of substitutes to return (default: 3)
  ///
  /// Returns a [List] of product [Map]s with the same structure as [findByUpc].
  Future<List<Map<String, dynamic>>> substitutes(
    String category, {
    int max = 3,
  }) async {
    final query = await _db
        .collection('apl')
        .where('category', isEqualTo: category)
        .where('eligible', isEqualTo: true)
        .limit(max)
        .get();

    return query.docs.map((d) => d.data()).toList();
  }
}
