import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

class DbService {
  static final _db = FirebaseFirestore.instance;

  static Future<void> ensureUserDoc() async {
    final uid = AuthService.uid!;
    final doc = _db.collection('users').doc(uid);
    final snap = await doc.get();
    if (!snap.exists) await doc.set({
      'email': AuthService.email,
      'name': AuthService.displayName(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> addBreed(String breed) async {
    final uid = AuthService.uid;
    if (uid == null) throw Exception('Not signed in');

    final userDoc = _db.collection('users').doc(uid);
    await userDoc.set({
      'email': AuthService.email,
      'name': AuthService.displayName(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final ref = userDoc.collection('breeds').doc(breed);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final count = (snap.data()?['count'] ?? 0) as int;
      tx.set(ref, {'count': count + 1}, SetOptions(merge: true));
    });
  }

  static Stream<QuerySnapshot<Map<String,dynamic>>> vaccStream() {
    final uid = AuthService.uid!;
    return _db.collection('users').doc(uid).collection('vaccinations').orderBy('name').snapshots();
  }

  static Future<void> setVaccination(String name, bool given) async {
    final uid = AuthService.uid!;
    final ref = _db.collection('users').doc(uid).collection('vaccinations').doc(name);
    await ref.set({'name': name, 'given': given, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }
}
