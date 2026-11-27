import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // kDebugMode, debugPrint
import 'package:google_generative_ai/google_generative_ai.dart';
import '/config/app_constants.dart';
import '../../utils/gemini_retry.dart';
import 'subcategory_detector.dart';
import '../../utils/similar_cases.dart';
import '../../utils/checklist_kb.dart';
import '../../utils/checklist_parse.dart';
import '../config/timeouts.dart';

/// TEMP-DEBUG [CHECKLIST] output: the text sent to Gemini and what comes back.
/// Printed only in debug builds, in pieces so long responses are not cut off.
/// It never includes the API key or any header: only prompt and response text.
void _dbg(String message) {
  if (kDebugMode) debugPrint(message);
}

class ChecklistService {
  late final GenerativeModel _model;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ChecklistService() {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: AppConstants.geminiApiKey,
      generationConfig: GenerationConfig(
        temperature: 0.2,
        responseMimeType: 'application/json',
      ),
    );
  }

  /// True when the latest [generateChecklist] call could not use the AI and
  /// built the checklist from the knowledge base instead.
  bool lastUsedFallback = false;

  /// The whole knowledge-base entry text, for tests.
  @visibleForTesting
  static String knowledgeBaseFor(String subcategory) =>
      _getKnowledgeBase(subcategory);

  /// The safety notes of the knowledge-base entry of [subcategory], exactly as
  /// written there (no AI). Empty when the entry has none.
  static List<String> safetyNotesFor(String subcategory) =>
      safetyNotesFromKb(_getKnowledgeBase(subcategory));

  /// The no-AI checklist for [subcategory]: one item per numbered Field
  /// Procedure of its knowledge-base entry (see [fallbackChecklistFromKb]).
  static List<Map<String, String>> fallbackChecklistFor(String subcategory) =>
      fallbackChecklistFromKb(_getKnowledgeBase(subcategory));

  /// The detection of the latest [generateChecklist] call, so the screen can
  /// save it on the ticket (`detectedSubcategory`, `detectedConfidence`).
  SubcategoryResult? lastDetection;

  /// The issue type of the ticket, found by [SubcategoryDetector] (weighted
  /// keywords; the category is only a hint). `general` when nothing matched;
  /// the knowledge base then uses its general entry.
  String _detectSubcategory(String category, String title, String description) {
    final result = SubcategoryDetector.detect(
      category: category,
      title: title,
      description: description,
    );

    lastDetection = result;

    // TEMP-DEBUG [CHECKLIST] start
    _dbg(
      '[CHECKLIST] subcategory=${result.subcategory} '
      'confidence=${result.confidence} score=${result.score} '
      'matched=${result.matchedTerms}',
    );
    if (result.subcategory == 'general') {
      _dbg(
        '[CHECKLIST] USING FALLBACK subcategory general (no keyword matched)',
      );
    }
    // TEMP-DEBUG [CHECKLIST] end

    return result.subcategory;
  }

  // --- Step 5: Knowledge Base Retrieval by Subcategory ---
  static String _getKnowledgeBase(String subcategory) {
    switch (subcategory) {
      // NETWORK SUBCATEGORIES
      case 'fiber_loss':
        return '''
TM Unifi FTTH No Optical Signal — Field Procedures:

Common Causes:
- Fibre patch cord or drop cable damaged, bent or disconnected
- Dirty or damaged connector end-face
- Fault in the passive section between OLT and customer (FDC, FDP, splitter)
- ONU optical or power fault

Required Tools:
- Optical power meter (GPON, 1310/1490/1550 nm)
- Visual fault locator
- Fibre inspection scope and cleaning kit (99% isopropyl alcohol, lint-free wipes, one-click cleaner)

Field Procedures:
1. Check the ONU front panel: Power LED white, LINK LED white and stable
2. If LINK is off, inspect the fibre from the fibre wall socket (FWS) to the ONU for bends, damage or loose connectors
3. Re-seat both ends of the patch cord, inspect the end-face with the scope, clean if dirty
4. Measure received power at the ONU with the power meter. ONU receiver sensitivity is -28 dBm (total allowable loss 28 dB)
5. Use the visual fault locator to find a break or sharp bend along the cable
6. Swap in a known-good patch cord and re-test
7. If the fault is before the FWS (drop cable, FDP, FDC or splitter), escalate with the test readings

Safety Notes:
- Never look into a fibre end-face or active light source
- Follow ladder (1:4 ratio) and full body harness rules when working on pole-mounted DPs

Source: Technical content (LED meanings, VLAN IDs, ports, thresholds, fault flow) from the TM Training Centre Unifi FTTH modules review deck; safety reminders are general field-safety practice.
''';

      case 'onu_auth_failure':
        return '''
TM Unifi ONU Authentication Failure — Field Procedures:

Common Causes:
- ONU authentication password not configured or incorrect
- ONU brand does not match the OLT
- Service VLAN fault on ONU or OLT

Required Tools:
- Laptop with LAN cable
- TM work order (contains the ONU authentication password)

Field Procedures:
1. Read the ONU LEDs: Power on, LINK white and stable, AUTH off means the ONU is not authenticated
2. If LINK is also off, treat it as a fibre fault first
3. Check that the ONU brand matches the OLT
4. Reconfigure the ONU authentication password as given in the work order
5. Reboot the ONU, then confirm AUTH and LINK are stable
6. If LINK and AUTH are on but there is still no service, call the field technical centre to check the service VLAN on the ONU and OLT

Safety Notes:
- Do not share the authentication password outside TM systems
- Use the credentials in the TM work instruction

Source: Technical content (LED meanings, VLAN IDs, ports, thresholds, fault flow) from the TM Training Centre Unifi FTTH modules review deck; safety reminders are general field-safety practice.
''';

      case 'wifi_issue':
        return '''
TM WiFi Connectivity — Field Procedures:

Common Causes:
- Router placed in poor location (behind walls, inside cabinets)
- 2.4GHz channel congestion from neighbouring WiFi networks
- Too many devices connected simultaneously
- Outdated router firmware causing stability issues
- WiFi password mismatch on customer device

Required Tools:
- WiFi analyser app (on smartphone or laptop)
- Laptop for router admin panel access (192.168.1.1)
- Cable for wired connection test

Field Procedures:
1. Test wired LAN connection first — if wired works, confirms issue is WiFi-specific not WAN
2. Log into router admin panel (192.168.1.1) — check WiFi settings and connected devices count
3. Use WiFi analyser app to scan for channel congestion — switch to least congested channel
4. Check router firmware version — update to latest TM-approved firmware if outdated
5. Check router placement — move to open elevated position away from interference sources
6. Separate 2.4GHz and 5GHz SSIDs — recommend 5GHz for devices within 5 metres
7. Check maximum connected devices — reboot router if count is abnormally high
8. Forget and reconnect WiFi on affected device — confirm correct password entered

Safety Notes:
- Inform customer before changing WiFi SSID or password
- Always back up router config before making changes

Source: General field practice, discussed with the TM R&D collaborator; not from the TM training deck
''';

      case 'speed_degradation':
        return '''
TM Unifi Slow Speed — Field Procedures:

TM service standards (user to nearest node or BRAS):
- Throughput at least 90% of the subscribed speed
- Latency: local up to 85 ms, international up to 350 ms
- Packet loss up to 1%
- Jitter: lower is better

Common Causes:
- Weak or degraded optical link (dirty or damaged connector)
- Many users sharing one PON port (max 64 users per port)
- Poor cable between ONU LAN1 and the premise gateway (PG)
- Wi-Fi limitations at the customer premise

Required Tools:
- Laptop with LAN cable
- TM Internet Experience Measurement Tool (verify.tm.net.my) or a speed test
- Optical power meter, fibre inspection scope and cleaning kit

Field Procedures:
1. Confirm the customer's subscribed speed
2. Run the speed test wired from a PG LAN port and record download, upload, ping and jitter
3. Run the same test over Wi-Fi and compare (general practice)
4. Compare results with the TM standard: at least 90% of plan, latency up to 85 ms, packet loss up to 1%
5. Confirm ONU LINK and AUTH are stable and LAN1 LED is white (ONU to PG link OK)
6. Inspect and clean the fibre connector, check the patch cord for bends, measure received power (sensitivity -28 dBm)
7. Swap the LAN cable between ONU LAN1 and PG WAN with a known-good one (general practice)
8. If wired speed is still below 90% with a healthy optical link, escalate with the test readings

Safety Notes:
- Never look into a fibre end-face
- Record test results with time for escalation

Source: Technical content (LED meanings, VLAN IDs, ports, thresholds, fault flow) from the TM Training Centre Unifi FTTH modules review deck; the latency, throughput and packet-loss thresholds are also from the TROS Part III-A technical specification; safety reminders are general field-safety practice.
''';

      case 'intermittent':
        return '''
TM Unifi Intermittent Disconnection — Field Procedures:

Common Causes:
- Loose or dirty fibre connector causing micro-interruptions
- Patch cord bent or crushed
- Unstable ONU power (adapter or power port)
- Loose LAN cable between ONU and PG
- Marginal optical power

Required Tools:
- Optical power meter, fibre inspection scope and cleaning kit
- Laptop for continuous ping test

Field Procedures:
1. Watch the ONU LEDs during a drop: LINK, AUTH, LAN1 and VOIP
2. If LINK drops, it is a fibre-side fault: re-seat, inspect and clean both connectors, check for bends
3. If only LAN1 or the PG WAN drops, check the LAN cable and the PG
4. Check the power adapter and power port
5. Measure received power with the power meter (sensitivity -28 dBm)
6. Run a continuous ping for about 30 minutes and compare against the TM standard: packet loss up to 1%, latency up to 85 ms (general practice for the test)
7. Replace the patch cord if no other cause is found
8. If drops continue with a healthy link, escalate with the ping log and drop times

Safety Notes:
- Never look into a fibre end-face
- Note the exact times of each disconnection

Source: Technical content (LED meanings, VLAN IDs, ports, thresholds, fault flow) from the TM Training Centre Unifi FTTH modules review deck; the latency and packet-loss thresholds are also from the TROS Part III-A technical specification; safety reminders are general field-safety practice.
''';

      // HARDWARE SUBCATEGORIES
      case 'ont_failure':
        return '''
TM Unifi ONU (ONT) Hardware or Power Fault — Field Procedures:

Common Causes:
- Power adapter or power port fault
- ONU unit fault
- ONU not authenticated with the OLT

Required Tools:
- Spare power adapter and spare ONU
- Optical power meter
- Laptop and TM work order (ONU authentication password)

Field Procedures:
1. Check the ONU Power LED (TM logo): white means power OK
2. If the Power LED is off, check the ON/OFF switch and the power adapter input on the back panel
3. Replace the power adapter, then the power port, then the ONU if it still has no power
4. If power is on and LINK is off, check the fibre and the internal wiring
5. If LINK is on and AUTH is off, reconfigure the ONU authentication password and check that the ONU brand matches the OLT
6. If LINK and AUTH are on but there is no service, call the field technical centre to check the service VLAN
7. After any ONU replacement, configure the authentication password and confirm all services (internet, voice, IPTV)

Safety Notes:
- Switch off the ONU before disconnecting the fibre
- Do not open the ONU casing (general practice)

Source: Technical content (LED meanings, VLAN IDs, ports, thresholds, fault flow) from the TM Training Centre Unifi FTTH modules review deck; safety reminders are general field-safety practice.
''';

      case 'router_failure':
        return '''
TM Router/Modem Failure — Field Procedures:

Common Causes:
- Router firmware corruption causing instability
- Failed LAN port (one or more ports dead)
- Router overheating causing thermal shutdown
- Power adapter failure
- Factory reset wiping configuration

Required Tools:
- Laptop and spare LAN cable for port testing
- Multimeter for power adapter check
- Spare router unit for swap test
- TM router configuration sheet

Field Procedures:
1. Check all router indicator LEDs — note which are on/off/blinking
2. Test each LAN port individually with known-good cable and device
3. Attempt router admin panel access (192.168.1.1) — if unreachable, router has crashed
4. Perform router reboot — hold power 10 seconds; wait 3 minutes for full boot
5. Test power adapter voltage with multimeter — replace if outside rated range
6. Check router temperature — if extremely hot, allow cooling and retest
7. If admin accessible but WAN down, re-enter PPPoE credentials and VLAN 500 settings
8. If unrecoverable, perform unit swap — reconfigure with TM standard settings

Safety Notes:
- Inform customer before factory reset — all custom settings will be lost
- Document original configuration before making changes

Source: General field practice, discussed with the TM R&D collaborator; not from the TM training deck
''';

      case 'cable_damage':
        return '''
TM Unifi Fibre Cable and Connector Damage — Field Procedures:

Common Causes:
- Patch cord kinked, crushed or bent too sharply
- Dirty or scratched connector end-face
- Damaged fibre wall socket (FWS) or adaptor
- Loose connector at the FWS or ONU
- Damaged LAN cable between ONU and PG

Required Tools:
- Fibre inspection scope
- Cleaning kit (one-click cleaner, lint-free wipes, 99% isopropyl alcohol)
- Spare patch cord and spare LAN cable
- Optical power meter

Field Procedures:
1. Check the ONU LINK LED. Off means no optical signal
2. Inspect the patch cord from the FWS to the ONU for kinks, crush damage and tight bends
3. Inspect both connector end-faces with the scope
4. Clean with the one-click cleaner or lint-free wipes and isopropyl alcohol, then re-inspect
5. Re-seat the connector at the FWS adaptor and at the ONU
6. Inspect the FWS for damage and check the cable entry has proper routing and strain relief
7. Replace the patch cord and confirm LINK turns on and received power is acceptable
8. Check the LAN cable from ONU LAN1 to PG WAN and replace if damaged (general practice)
9. If the damage is in the drop cable before the FWS, escalate

Safety Notes:
- Never look into a fibre end-face or active light source
- Switch off the ONU before cleaning or swapping fibre

Source: Technical content (LED meanings, VLAN IDs, ports, thresholds, fault flow) from the TM Training Centre Unifi FTTH modules review deck; safety reminders are general field-safety practice.
''';

      // SOFTWARE SUBCATEGORIES
      case 'pppoe_auth':
        return '''
TM PPPoE Authentication Failure — Field Procedures:

Common Causes:
- Incorrect PPPoE username or password on router
- TM account suspended due to billing
- Router WAN type set incorrectly (DHCP instead of PPPoE)
- Saved credentials corrupted after firmware update
- TM RADIUS server issue

Required Tools:
- Laptop for router admin panel access (192.168.1.1)
- TM technician portal for account status verification

Field Procedures:
1. Log into router admin panel (192.168.1.1) — navigate to WAN settings
2. Confirm WAN connection type is PPPoE (not DHCP or Static IP)
3. Verify PPPoE username format — TM format: username@unifi or username@streamyx
4. Re-enter PPPoE password manually — do not rely on saved credentials
5. Check TM account status via technician portal — confirm account is active
6. Set VLAN ID to 500 for internet WAN — missing VLAN causes authentication failure
7. If still failing after correct credentials, check for TM RADIUS server issue with NOC
8. If account suspended, advise customer to contact TM billing

Safety Notes:
- Never share customer PPPoE credentials outside TM systems
- Confirm with customer before resetting any credentials

Source: Current TM field workflow (technician portal, NOC, RADIUS check) as described by the TM R&D collaborator; general practice for the remaining steps
''';

      case 'vlan_config':
        return '''
TM Unifi Service and VLAN Configuration — Field Procedures:

TM service VLANs (Unifi): Voice 400, Internet 500, IPTV 600, CCS 209.

Common Causes:
- Service VLAN not correct on the ONU or OLT
- STB on the wrong PG port
- ONU LAN1 to PG WAN link problem

Required Tools:
- Laptop for diagnostics
- TM work order

Field Procedures:
1. Confirm which service is affected: internet, IPTV or voice
2. Check the ONU LAN1 LED is white and that LAN1 connects to the PG WAN port
3. Check the PG WAN and INTERNET LEDs (general practice)
4. Verify the VLAN for the affected service: internet 500, IPTV 600, voice 400
5. For IPTV, confirm the STB is connected to PG LAN4
6. For voice, confirm the phone is on ONU TEL1 or TEL2 and the VOIP LED is white
7. Reboot in order: ONU, then PG, then STB (general practice)
8. If LINK and AUTH are on but there is still no service, call the field technical centre to check the service VLAN on the ONU and OLT

Safety Notes:
- Changing VLAN settings causes a brief outage, so inform the customer first
- Record the original settings before changing them

Source: Technical content (LED meanings, VLAN IDs, ports, thresholds, fault flow) from the TM Training Centre Unifi FTTH modules review deck; safety reminders are general field-safety practice.
''';

      case 'voip_issue':
        return '''
TM Unifi Voice (VoIP) Fault — Field Procedures:

Common Causes:
- VoIP service not configured on the ONU
- Phone connected to the wrong port
- Voice VLAN (400) not correct

Required Tools:
- DECT or corded phone for a test call
- TM work order

Field Procedures:
1. Check the ONU LEDs: VOIP white and stable means the service is configured
2. Check the TEL1 or TEL2 LED for the port the phone uses
3. Confirm the phone is plugged into the ONU TEL1 or TEL2 (RJ11) port
4. Confirm the voice VLAN is 400
5. Reboot the ONU and re-check the VOIP LED
6. If VOIP stays off, escalate for a service provisioning check

Safety Notes:
- Inform the customer before rebooting the ONU, as internet drops briefly

Source: Technical content (LED meanings, VLAN IDs, ports, thresholds, fault flow) from the TM Training Centre Unifi FTTH modules review deck; safety reminders are general field-safety practice.
''';

      case 'dns_issue':
        return '''
TM DNS Resolution Failure — Field Procedures:

Common Causes:
- TM default DNS servers unresponsive or slow
- Router DNS settings overridden to non-functional address
- DNS cache corruption on router or device
- Firewall blocking DNS queries on port 53
- ISP-level DNS filtering causing selective failures

Required Tools:
- Laptop with command prompt for ping and nslookup
- Router admin panel access (192.168.1.1)

Field Procedures:
1. Test IP connectivity — ping 8.8.8.8; if this works, internet is up but DNS is the issue
2. Test DNS resolution — ping google.com; failure with successful IP ping confirms DNS fault
3. Run nslookup google.com — check which DNS server is queried and response time
4. Log into router admin — note current primary and secondary DNS addresses
5. Temporarily set the DNS on the test device or router to a public DNS, for example 8.8.8.8, to confirm DNS is the cause — do not leave it changed
6. Flush DNS cache — reboot router and run ipconfig /flushdns on Windows laptop
7. Test browsing with the temporary DNS — confirm websites load, then restore the original DNS setting and record the result for escalation
8. If specific websites still fail, check firewall rules blocking port 53 UDP/TCP

Safety Notes:
- Note the original DNS addresses before any test and restore them afterwards

Source: General field practice, not from the TM training deck
''';

      // DEFAULT / OTHER
      default:
        _dbg(
          '[CHECKLIST] USING FALLBACK default knowledge base entry (no entry for subcategory "$subcategory")',
        ); // TEMP-DEBUG [CHECKLIST]
        return '''
TM General Service Request - Standard Procedures:

Common Causes:
- Request is not a clear technical fault (account, billing, package, installation or relocation)
- Fault is not yet identified and needs systematic isolation
- Request details are unclear or incomplete

Required Tools:
- Laptop for diagnostic access
- TM work order

Field Procedures:
1. Gather a detailed description: exact symptoms or request, when it started, and what changed recently
2. Decide whether this is a service request or a fault
3. If it is a billing, account or package request, advise the customer of the correct TM channel and do not make changes on site
4. If it is an installation or relocation, confirm the address and preferred schedule with the customer
5. If it is a fault, inspect all physical connections from the entry point to all customer equipment, and check the ONU and gateway LED status
6. Isolate whether the fault is on TM infrastructure or on the customer's own equipment
7. Apply the fix and verify that service is fully restored
8. If the cause cannot be determined, document all findings on the TM work order and call the field technical centre, or escalate to the supervisor

Safety Notes:
- Follow TM field safety guidelines at all times
- Do not access street cabinets without proper authorisation

Source: General field practice
''';
    }
  }

  // --- Fetch Similar Past Tickets WITH Resolution Notes ---
  /// Past cases of the SAME subcategory only (at most 3), or null when none
  /// qualify, in which case the prompt has no past-cases section at all.
  Future<String?> _getSimilarTicketsContext(
    String category,
    String subcategory,
    String currentTicketId,
  ) async {
    try {
      // Same query as before (category + status, so no new index); the
      // subcategory filter is applied here in Dart.
      final ticketSnapshot = await _firestore
          .collection('tickets')
          .where('category', isEqualTo: category)
          .where('status', whereIn: ['RESOLVED', 'CLOSED'])
          .limit(20)
          .get();

      // Only tickets saved with this subcategory can qualify, so only their
      // reports are read.
      final docs = [
        for (final d in ticketSnapshot.docs)
          if (d.id != currentTicketId &&
              d.data()['detectedSubcategory']?.toString() == subcategory)
            d,
      ];

      if (docs.isEmpty) {
        _dbg(
          '[CHECKLIST] NO past cases section (no RESOLVED/CLOSED ticket of category $category with subcategory $subcategory)',
        ); // TEMP-DEBUG [CHECKLIST]
        return null;
      }

      final reports = await Future.wait([
        for (final d in docs) _firestore.collection('reports').doc(d.id).get(),
      ]);

      final data = <String, Map<String, dynamic>>{};
      final reportOf = <String, Map<String, dynamic>>{};
      final candidates = <SimilarCandidate>[];
      for (var i = 0; i < docs.length; i++) {
        final doc = docs[i];
        final report = reports[i];
        final reportData = report.exists
            ? (report.data() ?? <String, dynamic>{})
            : <String, dynamic>{};
        data[doc.id] = doc.data();
        reportOf[doc.id] = reportData;
        candidates.add(
          SimilarCandidate(
            id: doc.id,
            subcategory: doc.data()['detectedSubcategory']?.toString(),
            // Only the human-written technician notes are used.
            notes: report.exists
                ? reportData['technicianNotes']?.toString()
                : null,
          ),
        );
      }

      final selection = chooseSimilarCases(
        candidates,
        currentSubcategory: subcategory,
        currentTicketId: currentTicketId,
      );

      if (selection.chosen.isEmpty) {
        _dbg(
          '[CHECKLIST] NO past cases section (tickets with subcategory $subcategory had no meaningful technician notes)',
        ); // TEMP-DEBUG [CHECKLIST]
        return null;
      }

      final buffer = StringBuffer();
      buffer.writeln(
        'Past resolved "$category" tickets (same subcategory: $subcategory):',
      );
      buffer.writeln();

      var count = 0;
      for (final candidate in selection.chosen) {
        final notes = (reportOf[candidate.id]?['technicianNotes'] ?? '')
            .toString()
            .trim();
        count++;
        buffer.writeln('--- Past Case $count ---');
        buffer.writeln('Technician note: $notes');
        buffer.writeln();
      }

      return buffer.toString();
    } catch (e, st) {
      // TEMP-DEBUG [CHECKLIST] start
      _dbg('[CHECKLIST] ERROR in _getSimilarTicketsContext: $e');
      _dbg('[CHECKLIST] STACK $st');
      _dbg(
        '[CHECKLIST] ERROR ... leaving the past cases section out of the prompt',
      );
      // TEMP-DEBUG [CHECKLIST] end
      return null;
    }
  }

  // --- Generate Checklist ---
  Future<List<Map<String, String>>> generateChecklist({
    required String ticketId,
    required String category,
    required String title,
    required String description,
  }) async {
    // Reset first, so an earlier fallback never carries into this call.
    lastUsedFallback = false;

    // Step 4: Classify into subcategory
    final subcategory = _detectSubcategory(category, title, description);

    // Step 5: Retrieve subcategory-specific knowledge base
    final knowledgeBase = _getKnowledgeBase(subcategory);

    // TEMP-DEBUG [CHECKLIST] start
    _dbg('[CHECKLIST] category=$category subcategory=$subcategory');
    _dbg('[CHECKLIST] KB length=${knowledgeBase.length}');
    _dbg(
      '[CHECKLIST] KB first 120 chars: ${knowledgeBase.substring(0, knowledgeBase.length < 120 ? knowledgeBase.length : 120).replaceAll('\n', ' ')}',
    );
    // TEMP-DEBUG [CHECKLIST] end

    // Step 5: Retrieve past resolved cases with resolution notes
    final similarTickets = await _getSimilarTicketsContext(
      category,
      subcategory,
      ticketId,
    );

    // The past cases section exists only when same-subcategory cases do.
    final pastCasesSection = similarTickets == null
        ? ''
        : '=== PAST RESOLVED CASES (extra detail only) ===\n'
              '$similarTickets\n';

    // Step 6: Construct prompt
    final prompt =
        '''
You are an AI assistant for TM (Telekom Malaysia) field technicians.
Your job is to generate a specific, actionable troubleshooting checklist based on the ticket below.

=== TM KNOWLEDGE BASE — "$category" / "$subcategory" ISSUE ===
$knowledgeBase

$pastCasesSection=== CURRENT TICKET TO SOLVE ===
Category: $category
Detected Issue Type: $subcategory
Issue Title: $title
Customer Description: $description



=== YOUR TASK ===
Generate a checklist tailored specifically to THIS ticket.
Use the knowledge base for correct TM procedures, tools, and acceptable value ranges.
If past cases are given, use them only to add detail. They must never add steps, tools, systems or values that are not in the knowledge base. If a past case conflicts with the knowledge base, follow the knowledge base.

Each checklist item must have:
- title: short action step (max 8 words)
- detail: specific instruction relevant to this exact ticket (1-2 sentences, mention specific TM tools, settings, or values where applicable)
- priority: exactly one of "High", "Medium", or "Low"
- estimatedTime: realistic time like "5 mins", "10 mins", "15 mins", "30 mins"

Rules:
- Generate between 5 to 8 checklist items
- Keep the items in the order of the knowledge base's Field Procedures. Assign priority so it never rises down the list (all High items first, then Medium, then Low); physical and link checks come before any configuration change.
- Use abbreviations exactly as written in the knowledge base (ONU, PG, STB and so on). Do not expand them or invent new abbreviations.
- High = directly targets most likely root cause for this specific issue type
- Medium = important verification or diagnostic step
- Low = good practice check, less likely root cause
- Reference specific TM values only when they appear in the knowledge base above (e.g. VLAN 400/500/600, ONU sensitivity -28 dBm, throughput at least 90% of plan). Do not invent values.
- Do NOT generate generic steps that could apply to any IT issue
- Every checklist item must be based on a procedure in the knowledge base. Do not add steps from outside it.
- Follow the order of the knowledge base's Field Procedures (physical and link checks before any configuration change). Skip only steps that do not apply to this ticket.
- If the knowledge base has Safety Notes, include each relevant note in the detail of the step it applies to (for example the step that changes settings), or as a final item.

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
      // TEMP-DEBUG [CHECKLIST] start
      _dbg('[CHECKLIST] >>> PROMPT');
      for (final line in prompt.split('\n')) {
        _dbg('[CHECKLIST] $line');
      }
      _dbg('[CHECKLIST] <<< END PROMPT');
      // TEMP-DEBUG [CHECKLIST] end
      final content = [Content.text(prompt)];
      final stopwatch = Stopwatch()..start();
      // One retry after 2 s on 503 / 429 / network errors; never on a timeout.
      // The whole request, retry included, is limited so that a slow Gemini
      // still leaves time for the no-AI fallback below.
      final response = await withGeminiRetry(
        () => _model.generateContent(content),
        label: 'checklist',
      ).timeout(Timeouts.checklistGemini);
      stopwatch.stop();
      _dbg(
        'DEBUG [Checklist] Gemini response time: ${stopwatch.elapsedMilliseconds}ms (${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s)',
      );
      _dbg('DEBUG [Checklist] Subcategory detected: $subcategory');
      final responseText = response.text ?? '';

      // TEMP-DEBUG [CHECKLIST] start
      _dbg('[CHECKLIST] >>> RAW RESPONSE');
      for (final line in responseText.split('\n')) {
        _dbg('[CHECKLIST] $line');
      }
      _dbg('[CHECKLIST] <<< END RESPONSE');
      // TEMP-DEBUG [CHECKLIST] end

      // jsonDecode first, the old regex reader as the backup.
      final items = parseChecklistResponse(responseText);

      // TEMP-DEBUG [CHECKLIST] start
      _dbg('[CHECKLIST] parsed ${items.length} item(s)');
      if (items.isEmpty) {
        _dbg(
          '[CHECKLIST] WARNING parser matched 0 items; using the no-AI fallback checklist',
        );
      }
      // TEMP-DEBUG [CHECKLIST] end

      if (items.isEmpty) {
        throw Exception('No checklist items in the response');
      }
      return items;
    } catch (e, st) {
      // TEMP-DEBUG [CHECKLIST] start
      _dbg('[CHECKLIST] ERROR in generateChecklist: $e');
      _dbg('[CHECKLIST] STACK $st');
      // TEMP-DEBUG [CHECKLIST] end

      // Gemini failed (after its retry), timed out or gave nothing usable:
      // build the checklist from the knowledge base, without the AI.
      final fallback = fallbackChecklistFromKb(knowledgeBase);
      if (fallback.isNotEmpty) {
        lastUsedFallback = true;
        _dbg(
          '[CHECKLIST] USING NO-AI FALLBACK checklist (${fallback.length} items from the knowledge base)',
        ); // TEMP-DEBUG [CHECKLIST]
        return fallback;
      }
      throw Exception('Checklist generation failed: $e');
    }
  }
}
