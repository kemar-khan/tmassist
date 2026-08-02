import 'package:cloud_firestore/cloud_firestore.dart';

class AutoAssignmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String?> assignBestTechnician(String ticketId, String category) async {
    try {
      // Step 1: Get all technicians
      final techSnap = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'technician')
          .get();

      if (techSnap.docs.isEmpty) return null;

      // Step 2: Get all active tickets (ASSIGNED or IN_PROGRESS)
      final activeTicketsSnap = await _firestore
          .collection('tickets')
          .where('status', whereIn: ['ASSIGNED', 'IN_PROGRESS'])
          .get();

      // Step 3: Get all resolved tickets for performance calculation
      final resolvedTicketsSnap = await _firestore
          .collection('tickets')
          .where('status', isEqualTo: 'RESOLVED')
          .get();

      // Step 4: Score each technician
      String? bestTechnicianId;
      String? bestTechnicianName;
      double bestScore = -1;

      for (final techDoc in techSnap.docs) {
        final techId = techDoc.id;
        final techData = techDoc.data();
        final specialization = techData['specialization']?.toString() ?? '';

        // --- Factor 1: Skill Match (40%) ---
        double skillScore = 0;
        if (specialization.toLowerCase() == category.toLowerCase()) {
          skillScore = 40;
        } else if (specialization.toLowerCase() == 'other' ||
            category.toLowerCase() == 'other') {
          skillScore = 20;
        } else {
          skillScore = 5;
        }

        // --- Factor 2: Workload (40%) ---
        final activeCount = activeTicketsSnap.docs
            .where((t) => t.data()['technicianId'] == techId)
            .length;

        double workloadScore;
        if (activeCount == 0) {
          workloadScore = 40;
        } else if (activeCount == 1) {
          workloadScore = 30;
        } else if (activeCount == 2) {
          workloadScore = 20;
        } else if (activeCount == 3) {
          workloadScore = 10;
        } else {
          workloadScore = 0;
        }

        // --- Factor 3: Performance (20%) ---
        final assignedCount = activeTicketsSnap.docs
            .where((t) => t.data()['technicianId'] == techId)
            .length;

        final resolvedCount = resolvedTicketsSnap.docs
            .where((t) => t.data()['technicianId'] == techId)
            .length;

        final totalHandled = assignedCount + resolvedCount;
        double performanceScore = 0;
        if (totalHandled > 0) {
          final completionRate = resolvedCount / totalHandled;
          performanceScore = completionRate * 20;
        } else {
          // New technician, give benefit of the doubt
          performanceScore = 15;
        }

        // --- Total Score ---
        final totalScore = skillScore + workloadScore + performanceScore;

        if (totalScore > bestScore) {
          bestScore = totalScore;
          bestTechnicianId = techId;
          bestTechnicianName = (techData['fullName'] ?? 'Unnamed Technician')
              .toString();
        }
      }

      // Step 5: Assign the ticket to best technician
      if (bestTechnicianId != null) {
        // Get technician name before updating
        final techDoc = await _firestore
            .collection('users')
            .doc(bestTechnicianId)
            .get();
        final techData = techDoc.data() as Map<String, dynamic>?;
        final techName =
            techData?['fullName']?.toString() ?? 'Unknown Technician';

        await _firestore.collection('tickets').doc(ticketId).update({
          'technicianId': bestTechnicianId,
          'technicianName': techName,
          'status': 'ASSIGNED',
          'assignedAt': FieldValue.serverTimestamp(),
          'assignmentType': 'AUTO',
        });
      }

      return bestTechnicianId;
    } catch (e) {
      throw Exception('Auto assignment failed: $e');
    }
  }
}
