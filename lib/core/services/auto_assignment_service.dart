import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/coverage.dart';

class AutoAssignmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String?> assignBestTechnician(
    String ticketId,
    String category, {
    String? area,
  }) async {
    try {
      final techSnap = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'technician')
          .get();

      if (techSnap.docs.isEmpty) return null;

      final activeTicketsSnap = await _firestore
          .collection('tickets')
          .where('status', whereIn: ['ASSIGNED', 'IN_PROGRESS'])
          .get();

      final resolvedTicketsSnap = await _firestore
          .collection('tickets')
          .where('status', whereIn: ['RESOLVED', 'CLOSED'])
          .get();

      final allTechs = techSnap.docs;

      bool matchesSkill(QueryDocumentSnapshot t) {
        final spec = t.data() as Map<String, dynamic>;
        return (spec['specialization']?.toString().toLowerCase() ?? '') ==
            category.toLowerCase();
      }

      bool coversArea(QueryDocumentSnapshot t) {
        if (area == null || area.isEmpty || area == 'Other') return true;
        final data = t.data() as Map<String, dynamic>;
        final areas = List<String>.from(data['coverageAreas'] ?? []);
        return areas.contains(area);
      }

      // Fallback chain
      String note = '';
      var candidates = allTechs
          .where((t) => matchesSkill(t) && coversArea(t))
          .toList();

      // The normal match found someone. For an "Other" (or empty) area that
      // says why nobody's coverage was checked.
      if (candidates.isNotEmpty && isAnyArea(area)) {
        note = 'Area marked as Other, assigned by skill and workload';
      }

      if (candidates.isEmpty) {
        // Skill matched, coverage did not: the "Outside Coverage Area" pill
        // (assignedOutsideCoverage) says that, so the note stays empty.
        candidates = allTechs.where(matchesSkill).toList();
      }
      if (candidates.isEmpty) {
        candidates = allTechs.where((t) {
          final data = t.data() as Map<String, dynamic>;
          return (data['specialization']?.toString().toLowerCase() ?? '') ==
              'other';
        }).toList();
        if (candidates.isNotEmpty)
          note = 'No matching specialist, assigned to general technician';
      }
      if (candidates.isEmpty) {
        candidates = allTechs;
        note = 'No matching specialist or coverage, assigned by workload';
      }

      String? bestTechnicianId;
      String bestTechnicianName = 'Unknown Technician';
      List<String>? bestCoverage;
      double bestScore = -1;

      for (final techDoc in candidates) {
        final techId = techDoc.id;
        final techData = techDoc.data() as Map<String, dynamic>;

        final activeCount = activeTicketsSnap.docs
            .where(
              (t) =>
                  (t.data() as Map<String, dynamic>)['technicianId'] == techId,
            )
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

        final resolvedCount = resolvedTicketsSnap.docs
            .where(
              (t) =>
                  (t.data() as Map<String, dynamic>)['technicianId'] == techId,
            )
            .length;

        final totalHandled = activeCount + resolvedCount;
        final performanceScore = totalHandled > 0
            ? (resolvedCount / totalHandled) * 50
            : 25;

        final totalScore = workloadScore + performanceScore;

        if (totalScore > bestScore) {
          bestScore = totalScore;
          bestTechnicianId = techId;
          bestTechnicianName = (techData['fullName'] ?? 'Unknown Technician')
              .toString();
          final coverage = techData['coverageAreas'];
          bestCoverage = coverage is List
              ? [for (final a in coverage) a.toString()]
              : null;
        }
      }

      if (bestTechnicianId != null) {
        await _firestore.collection('tickets').doc(ticketId).update({
          'technicianId': bestTechnicianId,
          'technicianName': bestTechnicianName,
          'status': 'ASSIGNED',
          'assignedAt': FieldValue.serverTimestamp(),
          'assignmentType': 'AUTO',
          'assignmentNote': note,
          // A snapshot at assignment time; never recomputed later.
          'assignedOutsideCoverage': isOutsideCoverage(bestCoverage, area),
        });
      }

      return bestTechnicianId;
    } catch (e) {
      throw Exception('Auto assignment failed: $e');
    }
  }
}
