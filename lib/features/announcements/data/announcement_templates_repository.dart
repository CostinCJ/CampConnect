import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/announcement_template.dart';

/// Org-level announcement templates, stored under
/// `organizations/{orgId}/announcementTemplates`. Shared across all the org's
/// camps (like master locations).
class AnnouncementTemplatesRepository {
  final FirebaseFirestore _firestore;

  AnnouncementTemplatesRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _ref(String orgId) => _firestore
      .collection('organizations')
      .doc(orgId)
      .collection('announcementTemplates');

  Stream<List<AnnouncementTemplate>> watchTemplates(String orgId) {
    return _ref(orgId).snapshots().map((snap) {
      final list =
          snap.docs.map(AnnouncementTemplate.fromFirestore).toList();
      list.sort((a, b) => a.order.compareTo(b.order));
      return list;
    });
  }

  Future<void> addTemplate(String orgId, AnnouncementTemplate template) async {
    await _ref(orgId).add(template.toFirestore());
  }

  Future<void> updateTemplate(
    String orgId,
    AnnouncementTemplate template,
  ) async {
    await _ref(orgId).doc(template.id).update(template.toFirestore());
  }

  Future<void> deleteTemplate(String orgId, String id) async {
    await _ref(orgId).doc(id).delete();
  }

  /// Writes the built-in defaults the first time an org has no templates, so
  /// the manager and picker are never empty. Uses the defaults' stable ids, so
  /// a concurrent double-call can't create duplicates. No-ops when any template
  /// already exists (including after a guide deletes some).
  Future<void> seedDefaultsIfEmpty(String orgId) async {
    final ref = _ref(orgId);
    final existing = await ref.limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final batch = _firestore.batch();
    for (final template in defaultAnnouncementTemplates()) {
      batch.set(ref.doc(template.id), template.toFirestore());
    }
    await batch.commit();
  }
}
