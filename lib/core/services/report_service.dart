import 'package:cloud_firestore/cloud_firestore.dart';

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveReport({
    required String ticketId,
    required Map<String, dynamic> reportData,
  }) async {
    await _firestore.collection('reports').doc(ticketId).set({
      ...reportData,
      'ticketId': ticketId,
      'status': 'SUBMITTED',
      'submittedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('tickets').doc(ticketId).update({
      'hasReport': true,
      'status': 'RESOLVED',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>?> getReport(String ticketId) async {
    final doc = await _firestore.collection('reports').doc(ticketId).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  Future<void> saveDraft({
    required String ticketId,
    required Map<String, dynamic> draftData,
  }) async {
    await _firestore.collection('drafts').doc(ticketId).set({
      ...draftData,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Saves ONLY the technician notes (and the time) into the draft. A merge
  /// write, so the generated texts, photo and checklist signature already in
  /// the draft are never touched. Creates a notes-only draft when none exists.
  Future<void> saveDraftNotes({
    required String ticketId,
    required String notes,
  }) async {
    await _firestore.collection('drafts').doc(ticketId).set({
      'technicianNotes': notes,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getDraft(String ticketId) async {
    final doc = await _firestore.collection('drafts').doc(ticketId).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  Future<void> deleteDraft(String ticketId) async {
    await _firestore.collection('drafts').doc(ticketId).delete();
  }

  Future<void> addSupervisorComment({
    required String ticketId,
    required String comment,
  }) async {
    await _firestore.collection('reports').doc(ticketId).update({
      'supervisorComments': comment,
      'supervisorCommentedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
