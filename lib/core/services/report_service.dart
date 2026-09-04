import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '/config/app_constants.dart';

class ReportService {
  late final GenerativeModel _model;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ReportService() {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: AppConstants.geminiApiKey,
    );
  }

  Future<Map<String, String>> generateAiSections({
    required String category,
    required String title,
    required String description,
    required List<String> completedSteps,
  }) async {
    final stepsText = completedSteps.isEmpty
        ? 'No checklist steps recorded.'
        : completedSteps.map((s) => '- $s').join('\n');

    final prompt =
        '''
You are a technical report assistant for TM (Telekom Malaysia).
A technician has resolved a customer service ticket. 
Based on the information below, generate two sections for the service report.

Ticket Category: $category
Issue Title: $title
Issue Description: $description

Completed Troubleshooting Steps:
$stepsText

Generate the following two sections:
1. rootCause: A clear, professional 2-3 sentence explanation of what caused this issue
2. recommendations: 2-3 specific recommendations to prevent this issue from recurring

Rules:
- Be specific to this exact issue, not generic
- Use professional technical language
- Keep each section concise and clear

Respond ONLY with a valid JSON object. No explanation, no markdown.
Example format:
{
  "rootCause": "The issue was caused by...",
}
''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final responseText = response.text ?? '';

      final cleaned = responseText
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');

      if (start == -1 || end == -1) {
        throw Exception('No valid JSON found in response');
      }

      final jsonString = cleaned.substring(start, end + 1);

      return {'rootCause': _extractField(jsonString, 'rootCause')};
    } catch (e) {
      throw Exception('Report AI generation failed: $e');
    }
  }

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

    // Update ticket to mark report as submitted
    await _firestore.collection('tickets').doc(ticketId).update({
      'hasReport': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>?> getReport(String ticketId) async {
    final doc = await _firestore.collection('reports').doc(ticketId).get();

    if (!doc.exists) return null;
    return doc.data();
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

  String _extractField(String json, String field) {
    final pattern = RegExp('"$field"\\s*:\\s*"(.*?)"', dotAll: true);
    final match = pattern.firstMatch(json);
    return match?.group(1)?.trim() ?? '';
  }
}
