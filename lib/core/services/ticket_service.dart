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
    // Step 2: Auto assign best technician
    try {
      print('=== AUTO ASSIGNMENT STARTING ===');
      print('Ticket ID: ${ticketRef.id}');
      print('Category: ${category.trim()}');

      final autoAssignmentService = AutoAssignmentService();
      final assignedId = await autoAssignmentService.assignBestTechnician(
        ticketRef.id,
        category.trim(),
      );

      print('=== AUTO ASSIGNMENT RESULT ===');
      print('Assigned Technician ID: $assignedId');
    } catch (e) {
      print('=== AUTO ASSIGNMENT ERROR ===');
      print('Error: $e');
    }
  }
}
