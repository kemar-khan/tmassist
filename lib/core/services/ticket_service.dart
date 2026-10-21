import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auto_assignment_service.dart';

class TicketService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> createTicket({
    required String category,
    required String title,
    required String description,
    required String address,
    required String area,
    required String contactNumber,
    String? attachmentUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No logged in user found.');
    }

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data();

    if (userData == null) {
      throw Exception('Customer profile not found.');
    }

    // Step 1: Create the ticket
    final ticketRef = await _firestore.collection('tickets').add({
      'category': category.trim(),
      'title': title.trim(),
      'description': description.trim(),
      'address': address.trim(),
      'area': area.trim(),
      'contactNumber': contactNumber.trim(),
      'attachmentUrl': attachmentUrl,
      'status': 'NEW',
      'customerId': user.uid,
      'customerName': userData['fullName'] ?? 'Unknown User',
      'customerEmail': user.email,
      'technicianId': null,
      'supervisorId': null,
      'assignmentType': 'MANUAL',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Step 2: Auto assign best technician
    try {
      final autoAssignmentService = AutoAssignmentService();
      await autoAssignmentService.assignBestTechnician(
        ticketRef.id,
        category.trim(),
        area: area.trim(),
      );
    } catch (e) {
      print('Auto assignment error: $e');
    }
  }

  /// Soft-cancels a ticket (nothing is deleted). Allowed only while the ticket
  /// is NEW, or ASSIGNED and the technician has not started the job.
  Future<void> cancelTicket(String ticketId, {String? reason}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No logged in user found.');
    }

    final ref = _firestore.collection('tickets').doc(ticketId);
    final snap = await ref.get();
    final data = snap.data();
    if (!snap.exists || data == null) {
      throw Exception('Ticket not found.');
    }

    if (data['customerId'] != user.uid) {
      throw Exception('You can only cancel your own tickets.');
    }

    final status = (data['status'] ?? '').toString().toUpperCase();
    final canCancel =
        status == 'NEW' || (status == 'ASSIGNED' && data['startedAt'] == null);
    if (!canCancel) {
      throw Exception('Ticket can no longer be cancelled');
    }

    final trimmedReason = reason?.trim() ?? '';
    await ref.update({
      'status': 'CANCELLED',
      'cancelledAt': FieldValue.serverTimestamp(),
      'cancelledBy': user.uid,
      if (trimmedReason.isNotEmpty) 'cancellationReason': trimmedReason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
