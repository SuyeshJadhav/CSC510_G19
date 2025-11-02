import 'package:cloud_firestore/cloud_firestore.dart';

class AplService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> findByUpc(String upc) async {
    final doc = await _db.collection('apl').doc(upc).get();
    if (!doc.exists) return null;
    return doc.data();
  }

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
