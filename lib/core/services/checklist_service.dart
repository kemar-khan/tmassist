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
TM Network Troubleshooting — Standard Field Procedures:

Common Causes:
- Fiber optic line damaged or disconnected at ONT/ONU
- Signal attenuation due to dirty or faulty connectors
- UniFi router/modem misconfiguration or firmware issue
- ISP-side port or DSLAM fault
- DNS misconfiguration causing partial connectivity
- IP conflict on customer LAN

Required Tools:
- Optical power meter (OPM) and light source
- OTDR (Optical Time Domain Reflectometer)
- Fiber inspection probe / USB scope
- Laptop for router admin access (192.168.1.1)
- Cable tester for LAN verification

Field Procedures:
1. Confirm ONT indicator lights — LOS (red) indicates fiber signal loss
2. Check fiber patch cord from ONT to wall socket for bends or damage
3. Use OPM to measure optical signal level at ONT input (acceptable range: -8 to -27 dBm for GPON)
4. If signal loss detected, inspect fiber connector end-faces with probe; clean with IPA wipe if dirty
5. Log into router admin panel — check WAN status, PPPoE credentials, and VLAN settings
6. Run speed test from router to distinguish ISP vs LAN issue
7. Check DHCP lease table for IP conflicts on customer devices
8. If fault is upstream of ONT, escalate to TM Network Operations with OPM readings

Safety Notes:
- Never look directly into a fiber end-face or light source — risk of eye injury
- Power down ONT before cleaning connectors
''';

      case 'hardware':
        return '''
TM Hardware Inspection — Standard Field Procedures:

Common Causes:
- ONT, router, or STB (HyppTV) power supply failure
- Damaged LAN/fiber patch cable causing intermittent connection
- Faulty RJ45 port on router or wall socket
- Overheating due to poor ventilation
- Physical damage to CPE (Customer Premises Equipment)
- Failed port on router (one port works, another does not)

Required Tools:
- Replacement patch cables (Cat5e/Cat6 and fiber patch cord)
- Cable tester (RJ45)
- Multimeter (for power supply voltage check)
- Spare CPE units (ONT, router) for swap testing
- Screwdriver set for enclosure inspection

Field Procedures:
1. Perform full visual inspection — check for burn marks, swollen capacitors, physical cracks
2. Verify power LED on all CPE units (ONT, router, STB) — no LED indicates power failure
3. Test power adapter output with multimeter; replace adapter if voltage is outside rated range
4. Swap LAN cable between router and device — use cable tester to confirm continuity
5. Test each RJ45 port on router individually with known-good cable and device
6. Check device ventilation — if unit is hot to touch, power off for 10 minutes and retest
7. If fault persists after all checks, perform CPE swap with spare unit and confirm resolution
8. Record serial number of faulty unit and complete TM asset replacement form

Safety Notes:
- Power off all equipment before inspecting internal components
- Do not open sealed CPE units — void warranty and TM policy
''';

      case 'software':
        return '''
TM Software & Configuration Diagnostics — Standard Field Procedures:

Common Causes:
- Incorrect PPPoE username/password entered on router
- VLAN ID misconfiguration (TM UniFi uses VLAN 500 for internet, VLAN 600 for IPTV)
- Outdated router or ONT firmware causing instability
- Corrupted router configuration requiring factory reset
- DNS server unreachable causing browsing failures despite active connection
- HyppTV middleware account mismatch or subscription issue

Required Tools:
- Laptop with browser for router admin access
- TM technician portal access (for account/subscription verification)
- USB drive with latest firmware image (if offline update needed)

Field Procedures:
1. Access router admin panel (default: 192.168.1.1) — verify WAN connection type is PPPoE
2. Confirm PPPoE credentials match TM account — re-enter if in doubt (do not rely on saved credentials)
3. Check VLAN settings — Internet: VLAN 500, IPTV: VLAN 600; incorrect VLAN causes full outage
4. Check router firmware version against TM-approved version list; update if outdated
5. Test DNS resolution: ping 8.8.8.8 (IP) vs ping google.com (domain) — failure on domain only = DNS issue; switch to 8.8.8.8 or 1.1.1.1
6. If configuration is corrupted, perform factory reset and reconfigure from scratch using TM settings sheet
7. Verify HyppTV subscription status via TM portal if IPTV is affected but internet works
8. After any change, run full connectivity test: internet browsing, speed test, and IPTV playback

Safety Notes:
- Always back up current router config before making changes
- Inform customer before performing factory reset — all custom WiFi settings will be lost
''';

      default:
        return '''
TM General Troubleshooting — Standard Field Procedures:

Common Causes:
- Undetermined fault requiring systematic isolation
- Customer-reported issue may span multiple systems (network, hardware, software)
- External factor (weather, construction, third-party interference)

Required Tools:
- Optical power meter and fiber inspection probe
- Cable tester and multimeter
- Laptop for configuration access
- TM technician portal for account and line status check

Field Procedures:
1. Gather detailed issue description from customer — when did it start, what changed recently
2. Verify TM account status and active services via technician portal
3. Check for active TM service outages in the area before proceeding on-site
4. Inspect all physical connections from street cabinet to CPE
5. Test each layer systematically: physical → signal → network → application
6. Isolate whether fault is on TM infrastructure side or customer premises equipment
7. Apply fix at identified layer and verify full service restoration
8. If root cause cannot be determined on-site, escalate with detailed findings to TM NOC

Safety Notes:
- Follow TM field safety guidelines at all times
- Do not access street cabinets or external infrastructure without authorisation
''';
    }
  }

  // --- Fetch Similar Past Tickets WITH Resolution Notes ---
  Future<String> _getSimilarTicketsContext(
    String category,
    String currentTicketId,
  ) async {
    try {
      // Step 1: Fetch resolved tickets of same category
      final ticketSnapshot = await _firestore
          .collection('tickets')
          .where('category', isEqualTo: category)
          .where('status', isEqualTo: 'RESOLVED')
          .limit(5)
          .get();

      if (ticketSnapshot.docs.isEmpty) {
        return 'No similar resolved tickets found for this category.';
      }

      final buffer = StringBuffer();
      buffer.writeln('Past resolved tickets in the "$category" category:');
      buffer.writeln();

      int count = 0;
      for (final ticketDoc in ticketSnapshot.docs) {
        if (ticketDoc.id == currentTicketId) continue;
        if (count >= 3) break;

        final ticketData = ticketDoc.data();
        final title = ticketData['title']?.toString() ?? '';
        final description = ticketData['description']?.toString() ?? '';

        // Step 2: Fetch the matching report for resolution details
        final reportDoc = await _firestore
            .collection('reports')
            .doc(ticketDoc.id)
            .get();

        if (!reportDoc.exists) continue;

        final reportData = reportDoc.data() ?? {};
        final rootCause = reportData['rootCause']?.toString() ?? '';
        final stepsTaken = reportData['stepsTaken']?.toString() ?? '';
        final resolutionSummary =
            reportData['resolutionSummary']?.toString() ?? '';
        final technicianNotes = reportData['technicianNotes']?.toString() ?? '';

        // Only include if we have meaningful resolution data
        if (rootCause.isEmpty && stepsTaken.isEmpty) continue;

        count++;
        buffer.writeln('--- Past Case $count ---');
        if (title.isNotEmpty) buffer.writeln('Issue: $title');
        if (description.isNotEmpty) buffer.writeln('Description: $description');
        if (rootCause.isNotEmpty) buffer.writeln('Root Cause: $rootCause');
        if (stepsTaken.isNotEmpty) buffer.writeln('Steps Taken: $stepsTaken');
        if (resolutionSummary.isNotEmpty) {
          buffer.writeln('How It Was Resolved: $resolutionSummary');
        }
        if (technicianNotes.isNotEmpty) {
          buffer.writeln('Technician Notes: $technicianNotes');
        }
        buffer.writeln();
      }

      if (count == 0) {
        return 'No similar resolved tickets with resolution details found.';
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
Current checklist items already generated (DO NOT repeat these):
${existingItems.map((e) => '- ${e['title']}').join('\n')}
'''
        : '';

    final prompt =
        '''
You are an AI assistant for TM (Telekom Malaysia) field technicians.
Your job is to generate a specific, actionable troubleshooting checklist based on the ticket below.

=== TM KNOWLEDGE BASE FOR "$category" ISSUES ===
$knowledgeBase

=== PAST RESOLVED CASES (learn from these resolutions) ===
$similarTickets

=== CURRENT TICKET TO SOLVE ===
Category: $category
Issue Title: $title
Customer Description: $description

$existingContext

=== YOUR TASK ===
Generate a checklist tailored to THIS specific ticket.
Use the knowledge base for correct TM procedures and tools.
Use the past resolved cases to inform likely root causes and proven fix steps.

Each checklist item must have:
- title: short action step (max 8 words)
- detail: specific instruction relevant to this exact ticket (1-2 sentences, mention specific tools or settings where relevant)
- priority: exactly one of "High", "Medium", or "Low"
- estimatedTime: realistic time like "5 mins", "10 mins", "15 mins", "30 mins"

Rules:
- Generate between 5 to 8 checklist items
- Order from highest to lowest priority
- High = must do first, directly targets likely root cause
- Medium = important diagnostic or verification step
- Low = good practice check, less likely to be the root cause
- Be specific to THIS ticket — do not copy generic steps that do not apply
- Reference specific TM tools, settings, or values where relevant (e.g. VLAN 500, -8 to -27 dBm)

Respond ONLY with a valid JSON array. No explanation, no markdown, no preamble.
[
  {
    "title": "Example action step here",
    "detail": "Specific instruction referencing this ticket and TM procedures.",
    "priority": "High",
    "estimatedTime": "10 mins"
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
