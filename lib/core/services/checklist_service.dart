import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '/config/app_constants.dart';

class ChecklistService {
  late final GenerativeModel _model;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ChecklistService() {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: AppConstants.geminiApiKey,
    );
  }

  // --- Knowledge Base ---
  String _getKnowledgeBase(String category) {
    switch (category.toLowerCase()) {
      case 'network':
        return '''
Network Troubleshooting Standard Procedures:
- Verify all physical cable connections
- Check modem and router indicator lights
- Restart modem and router in correct sequence
- Check IP configuration and DNS settings
- Test connection speed and signal strength
- Check for network congestion or interference
- Verify ISP service status
- Check firewall and security settings
- Test with multiple devices to isolate issue
- Check router firmware version
''';
      case 'hardware':
        return '''
Hardware Inspection Standard Procedures:
- Perform visual inspection of all components
- Check all power connections and adapters
- Inspect cables for physical damage
- Test power supply output
- Check device temperature and ventilation
- Inspect ports and connectors for damage
- Test with replacement components if available
- Check device drivers and firmware
- Run hardware diagnostic tools
- Document all physical findings
''';
      case 'software':
        return '''
Software Diagnostic Standard Procedures:
- Check system logs for error messages
- Verify software version and updates
- Check system resource usage (CPU, RAM, disk)
- Restart relevant services or applications
- Check configuration files for errors
- Verify user permissions and access rights
- Test in safe mode or clean environment
- Check for conflicting software or processes
- Backup data before making changes
- Document all software changes made
''';
      default:
        return '''
General Troubleshooting Standard Procedures:
- Gather detailed information about the issue
- Identify when the problem first occurred
- Check for any recent changes to the system
- Inspect physical environment and connections
- Test basic functionality step by step
- Isolate the root cause systematically
- Apply fix and verify resolution
- Document findings and actions taken
''';
    }
  }

  // --- Fetch Similar Past Tickets ---
  Future<String> _getSimilarTicketsContext(
    String category,
    String currentTicketId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('tickets')
          .where('category', isEqualTo: category)
          .where('status', isEqualTo: 'RESOLVED')
          .limit(3)
          .get();

      if (snapshot.docs.isEmpty) return 'No similar resolved tickets found.';

      final buffer = StringBuffer();
      buffer.writeln('Similar resolved tickets in this category:');

      for (final doc in snapshot.docs) {
        if (doc.id == currentTicketId) continue;
        final data = doc.data();
        final title = data['title']?.toString() ?? '';
        final description = data['description']?.toString() ?? '';
        if (title.isNotEmpty) {
          buffer.writeln('- Issue: $title');
          if (description.isNotEmpty) {
            buffer.writeln('  Details: $description');
          }
        }
      }

      return buffer.toString();
    } catch (e) {
      return 'Could not retrieve similar tickets.';
    }
  }

  // --- Generate Checklist ---
  Future<List<Map<String, String>>> generateChecklist({
    required String ticketId,
    required String category,
    required String title,
    required String description,
    List<Map<String, String>>? existingItems,
    bool addToExisting = false,
  }) async {
    final knowledgeBase = _getKnowledgeBase(category);
    final similarTickets = await _getSimilarTicketsContext(category, ticketId);

    final existingContext = addToExisting && existingItems != null
        ? '''
Current checklist items (DO NOT repeat these):
${existingItems.map((e) => '- ${e['title']}').join('\n')}
'''
        : '';

    final prompt =
        '''
You are an AI assistant for TM (Telekom Malaysia) helping technicians fix customer issues.

KNOWLEDGE BASE:
$knowledgeBase

SIMILAR PAST RESOLVED TICKETS:
$similarTickets

CURRENT TICKET:
Category: $category
Issue Title: $title
Issue Description: $description

$existingContext

Generate a specific, actionable checklist for this exact issue.
Each item must have:
- title: short action step (max 8 words)
- detail: specific instruction for this exact issue (1-2 sentences)
- priority: exactly one of "High", "Medium", or "Low"
- estimatedTime: realistic time like "5 mins", "10 mins", "15 mins"

Rules:
- Generate between 5 to 8 checklist items
- Order items from most important to least
- Make items specific to THIS ticket, not generic
- High priority = must do first, critical to resolution
- Medium priority = important but not blocking
- Low priority = good to check but optional

Respond ONLY with a valid JSON array. No explanation, no markdown.
Example format:
[
  {
    "title": "Check router power connection",
    "detail": "Verify the power adapter is firmly connected to both the router and wall socket. Check for any visible damage to the cable.",
    "priority": "High",
    "estimatedTime": "5 mins"
  }
]
''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final responseText = response.text ?? '';

      final cleaned = responseText
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final start = cleaned.indexOf('[');
      final end = cleaned.lastIndexOf(']');

      if (start == -1 || end == -1) {
        throw Exception('No valid JSON array found in response');
      }

      final jsonString = cleaned.substring(start, end + 1);
      final List<dynamic> parsed = _parseJsonArray(jsonString);

      return parsed.map((item) {
        return {
          'title': item['title']?.toString() ?? '',
          'detail': item['detail']?.toString() ?? '',
          'priority': item['priority']?.toString() ?? 'Medium',
          'estimatedTime': item['estimatedTime']?.toString() ?? '10 mins',
        };
      }).toList();
    } catch (e) {
      throw Exception('Checklist generation failed: $e');
    }
  }

  List<dynamic> _parseJsonArray(String json) {
    // Simple extraction of objects from JSON array
    final items = <Map<String, dynamic>>[];
    final pattern = RegExp(
      r'\{[^{}]*"title"[^{}]*"detail"[^{}]*"priority"[^{}]*"estimatedTime"[^{}]*\}',
      dotAll: true,
    );

    for (final match in pattern.allMatches(json)) {
      final obj = match.group(0) ?? '';
      items.add({
        'title': _extractField(obj, 'title'),
        'detail': _extractField(obj, 'detail'),
        'priority': _extractField(obj, 'priority'),
        'estimatedTime': _extractField(obj, 'estimatedTime'),
      });
    }

    return items;
  }

  String _extractField(String json, String field) {
    final pattern = RegExp('"$field"\\s*:\\s*"(.*?)"', dotAll: true);
    final match = pattern.firstMatch(json);
    return match?.group(1)?.trim() ?? '';
  }
}
