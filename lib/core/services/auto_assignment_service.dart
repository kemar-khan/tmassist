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

      // Step 2: Get all active tickets (assigned or in_progress)
      final activeTicketsSnap = await _firestore
          .collection('tickets')
          .where('status', whereIn: ['ASSIGNED', 'IN_PROGRESS'])
          .get();

      // Step 3: Get all resolved tickets for performance calculation
      final resolvedTicketsSnap = await _firestore
          .collection('tickets')
          .where('status', isEqualTo: 'RESOLVED')
          .get();

      // Step 4: Filter technicians by specialization priority
      final allTechs = techSnap.docs;

      // Priority 1 — exact category match
      var candidateTechs = allTechs.where((t) {
        final spec = t.data()['specialization']?.toString().toLowerCase() ?? '';
        return spec == category.toLowerCase();
      }).toList();

      // Priority 2 — 'Other' specialization as fallback
      if (candidateTechs.isEmpty) {
        candidateTechs = allTechs.where((t) {
          final spec =
              t.data()['specialization']?.toString().toLowerCase() ?? '';
          return spec == 'other';
        }).toList();
      }

      // Priority 3 — everyone as last resort
      if (candidateTechs.isEmpty) {
        candidateTechs = allTechs;
      }

      // Step 5: Score each candidate
      String? bestTechnicianId;
      String? bestTechnicianName;
      double bestScore = -1;

      for (final techDoc in candidateTechs) {
        final techId = techDoc.id;
        final techData = techDoc.data();

        // --- Factor 1: Workload (50%) — weighted higher now that skill is pre-filtered ---
        final activeCount = activeTicketsSnap.docs
            .where((t) => t.data()['technicianId'] == techId)
            .length;

        double workloadScore;
        if (activeCount == 0) {
          workloadScore = 50;
        } else if (activeCount == 1) {
          workloadScore = 40;
        } else if (activeCount == 2) {
          workloadScore = 25;
        } else if (activeCount == 3) {
          workloadScore = 10;
        } else {
          workloadScore = 0;
        }

        // --- Factor 2: Performance (50%) ---
        final resolvedCount = resolvedTicketsSnap.docs
            .where((t) => t.data()['technicianId'] == techId)
            .length;

        final totalHandled = activeCount + resolvedCount;
        double performanceScore = 0;
        if (totalHandled > 0) {
          final completionRate = resolvedCount / totalHandled;
          performanceScore = completionRate * 50;
        } else {
          performanceScore = 25; // new technician, benefit of the doubt
        }

        // --- Total Score ---
        final totalScore = workloadScore + performanceScore;

        if (totalScore > bestScore) {
          bestScore = totalScore;
          bestTechnicianId = techId;
          bestTechnicianName = (techData['fullName'] ?? 'Unnamed Technician')
              .toString();
        }
      }

      // Step 6: Assign ticket to best technician
      if (bestTechnicianId != null) {
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
