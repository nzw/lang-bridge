import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/dictionary_entry.dart';
import '../../domain/repositories.dart';

class FirestoreUserDictionaryRepository implements UserDictionaryRepository {
  FirestoreUserDictionaryRepository({required this.uid});

  final String uid;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('users/$uid/entries');

  // Firestore の WriteBatch は 500 操作が上限なので分割してコミットする。
  static const _batchLimit = 490;

  DictionaryEntry _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) throw StateError('Firestore document has no data: ${doc.id}');
    return DictionaryEntry.fromJson(data);
  }

  @override
  Future<List<DictionaryEntry>> listAll() async {
    final snap = await _col.get();
    return snap.docs.map(_fromDoc).toList();
  }

  @override
  Future<DictionaryEntry?> getById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return _fromDoc(doc);
  }

  @override
  Future<void> upsert(DictionaryEntry entry) async {
    await _col.doc(entry.id).set(entry.toJson());
  }

  @override
  Future<void> upsertMany(List<DictionaryEntry> entries) async {
    final db = FirebaseFirestore.instance;
    for (var offset = 0; offset < entries.length; offset += _batchLimit) {
      final batch = db.batch();
      final chunk = entries.skip(offset).take(_batchLimit);
      for (final e in chunk) {
        batch.set(_col.doc(e.id), e.toJson());
      }
      await batch.commit();
    }
  }

  @override
  Future<void> deleteById(String id) async {
    await _col.doc(id).delete();
  }

  @override
  Future<void> deleteManyByIds(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = FirebaseFirestore.instance;
    for (var offset = 0; offset < ids.length; offset += _batchLimit) {
      final batch = db.batch();
      for (final id in ids.skip(offset).take(_batchLimit)) {
        batch.delete(_col.doc(id));
      }
      await batch.commit();
    }
  }

  @override
  Future<void> deleteAll() async {
    final snap = await _col.get();
    if (snap.docs.isEmpty) return;
    final db = FirebaseFirestore.instance;
    for (var offset = 0; offset < snap.docs.length; offset += _batchLimit) {
      final batch = db.batch();
      for (final doc in snap.docs.skip(offset).take(_batchLimit)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  @override
  Future<void> deleteBySessionId(String sessionId) async {
    final snap = await _col
        .where('importSessionId', isEqualTo: sessionId)
        .get();
    if (snap.docs.isEmpty) return;
    await deleteManyByIds(snap.docs.map((d) => d.id).toList());
  }
}
