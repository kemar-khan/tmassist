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

  // --- Step 4: Issue Classification via Keyword Detection ---
  String _detectSubcategory(String category, String title, String description) {
    final text = '$title $description'.toLowerCase();

    switch (category.toLowerCase()) {
      case 'network':
        if (text.contains('los') ||
            text.contains('fiber') ||
            text.contains('fibre') ||
            text.contains('no internet') ||
            text.contains('red light') ||
            text.contains('no connection') ||
            text.contains('signal loss') ||
            text.contains('completely down') ||
            text.contains('total outage'))
          return 'fiber_loss';

        if (text.contains('wifi') ||
            text.contains('wi-fi') ||
            text.contains('wireless') ||
            text.contains('weak signal') ||
            text.contains('cannot connect') ||
            text.contains('no wifi'))
          return 'wifi_issue';

        if (text.contains('slow') ||
            text.contains('speed') ||
            text.contains('buffering') ||
            text.contains('mbps') ||
            text.contains('lagging') ||
            text.contains('loading slowly') ||
            text.contains('low speed'))
          return 'speed_degradation';

        if (text.contains('disconnect') ||
            text.contains('dropping') ||
            text.contains('unstable') ||
            text.contains('intermittent') ||
            text.contains('keeps cutting') ||
            text.contains('on and off') ||
            text.contains('random'))
          return 'intermittent';

        return 'fiber_loss'; // default network

      case 'hardware':
        if (text.contains('ont') ||
            text.contains('no light') ||
            text.contains('no power') ||
            text.contains('dead') ||
            text.contains('not turning on') ||
            text.contains('power'))
          return 'ont_failure';

        if (text.contains('router') ||
            text.contains('lan') ||
            text.contains('ethernet') ||
            text.contains('admin page') ||
            text.contains('cannot access'))
          return 'router_failure';

        if (text.contains('cable') ||
            text.contains('port') ||
            text.contains('loose') ||
            text.contains('damaged') ||
            text.contains('broken') ||
            text.contains('connector'))
          return 'cable_damage';

        return 'ont_failure'; // default hardware

      case 'software':
        if (text.contains('password') ||
            text.contains('pppoe') ||
            text.contains('authentication') ||
            text.contains('login') ||
            text.contains('credential') ||
            text.contains('username'))
          return 'pppoe_auth';

        if (text.contains('vlan') ||
            text.contains('iptv') ||
            text.contains('hypptv') ||
            text.contains('tv') ||
            text.contains('setup') ||
            text.contains('configuration') ||
            text.contains('misconfigured'))
          return 'vlan_config';

        if (text.contains('dns') ||
            text.contains('website') ||
            text.contains('browsing') ||
            text.contains('cannot open') ||
            text.contains('ping') ||
            text.contains('domain'))
          return 'dns_issue';

        return 'pppoe_auth'; // default software

      default:
        return 'general';
    }
  }

  // --- Step 5: Knowledge Base Retrieval by Subcategory ---
  String _getKnowledgeBase(String category, String subcategory) {
    final key = '${category.toLowerCase()}_$subcategory';

    switch (key) {
      // NETWORK SUBCATEGORIES
      case 'network_fiber_loss':
        return '''
TM Fiber/GPON Signal Loss — Field Procedures:

Common Causes:
- Physical fiber optic cable cut or bent beyond minimum bend radius
- Dirty or damaged fiber connector end-face at ONT input
- Failed optical splitter upstream in the distribution network
- ONT hardware failure (optical module degraded)
- Loose fiber patch cord at ONT or wall socket

Required Tools:
- Optical Power Meter (OPM) and light source
- OTDR (Optical Time Domain Reflectometer)
- Fiber inspection probe / USB microscope
- IPA cleaning wipes and fiber cleaning kit
- Spare fiber patch cord for swap test

Field Procedures:
1. Confirm ONT LOS indicator — solid red LOS light = no optical signal received
2. Check fiber patch cord from ONT to wall socket — look for sharp bends, kinks, or physical damage
3. Re-seat fiber patch cord connectors at both ends firmly
4. Use OPM to measure optical Rx power at ONT input (acceptable GPON range: -8 to -27 dBm)
5. If power is absent or below -27 dBm, inspect fiber end-face with probe — clean with IPA wipe if dirty
6. Swap patch cord with known-good spare — re-measure power after swap
7. If still no signal, use OTDR from nearest access point to locate fiber break distance
8. If break is outside customer premises, escalate to TM outside plant team with OTDR trace

Safety Notes:
- Never look directly into a fiber end-face or active light source — risk of permanent eye injury
- Power down ONT before cleaning or swapping fiber connectors
''';

      case 'network_wifi_issue':
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
''';

      case 'network_speed_degradation':
        return '''
TM Internet Speed Degradation — Field Procedures:

Common Causes:
- Optical signal level weak but above minimum threshold (marginal link)
- Router CPU overloaded from too many connected devices
- ISP-side port throughput issue
- DNS server slow causing perceived slowness
- QoS misconfiguration throttling specific traffic

Required Tools:
- Optical Power Meter (OPM)
- Laptop for speed test via wired connection
- Router admin panel access (192.168.1.1)

Field Procedures:
1. Run speed test via wired LAN connection — eliminates WiFi as the cause
2. Run speed test via WiFi — compare with wired result
3. Measure optical Rx power with OPM — weak signal below -24 dBm causes speed issues
4. Log into router admin — check active connections and bandwidth usage per device
5. Check for background applications consuming bandwidth (torrents, cloud backups)
6. Change DNS to 8.8.8.8 and 1.1.1.1 — test browsing speed after change
7. Check router QoS settings — disable or reconfigure if throttling traffic
8. If wired speed still below plan, escalate to TM NOC with speed test results and OPM reading

Safety Notes:
- Run speed test at off-peak hours for baseline comparison
- Document speed test results with timestamps for escalation
''';

      case 'network_intermittent':
        return '''
TM Intermittent Disconnection — Field Procedures:

Common Causes:
- Marginal optical signal causing link to drop under load
- Faulty or loose fiber patch cord causing micro-interruptions
- Router overheating causing periodic resets
- PPPoE session timeout misconfiguration
- Upstream port instability at TM exchange

Required Tools:
- Optical Power Meter (OPM)
- Laptop for continuous ping test
- Router admin panel access for log review

Field Procedures:
1. Run continuous ping test (ping -t 8.8.8.8) — observe drop pattern (consistent vs random)
2. Check router system log — look for PPPoE disconnection events with timestamps
3. Measure optical Rx power with OPM — note if reading is near -27 dBm threshold
4. Physically check fiber patch cord — re-seat both connectors, look for intermittent contact
5. Check router temperature — if hot, power off 10 minutes; reposition for ventilation
6. Check PPPoE keepalive settings in router admin — ensure session timeout is correct
7. If drops follow consistent time pattern, suspect upstream port — escalate to TM NOC with ping log
8. Replace fiber patch cord as preventive measure if no other cause found

Safety Notes:
- Keep ping log running at least 30 minutes to capture drop pattern
- Note exact times of disconnection for NOC escalation
''';

      // HARDWARE SUBCATEGORIES
      case 'hardware_ont_failure':
        return '''
TM ONT (Optical Network Terminal) Failure — Field Procedures:

Common Causes:
- Power adapter failure or wrong voltage output
- ONT optical module degraded or failed
- ONT firmware corruption causing boot loop
- Physical damage to ONT unit
- Power surge damage to ONT internal components

Required Tools:
- Multimeter for power adapter voltage check
- Spare ONT unit for swap test
- Optical Power Meter to confirm signal present before blaming ONT
- TM asset replacement form

Field Procedures:
1. Check ONT power LED — no LED indicates power supply issue not ONT failure
2. Test power adapter output with multimeter — verify voltage matches ONT rated input (typically 12V DC)
3. Replace power adapter with known-good unit — observe if ONT boots
4. If ONT has power but LOS is red, measure optical signal with OPM to confirm signal is present
5. If signal present (-8 to -27 dBm) but ONT still shows LOS, ONT optical module has failed
6. Perform ONT unit swap with spare — configure with correct GPON SN and PLOAM password
7. Confirm all services restore after swap — internet, IPTV, VoIP if applicable
8. Record faulty ONT serial number and complete TM CPE replacement form

Safety Notes:
- Do not open ONT casing — sealed unit, TM policy violation
- Power off ONT before disconnecting fiber patch cord
''';

      case 'hardware_router_failure':
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
''';

      case 'hardware_cable_damage':
        return '''
TM Cable and Port Inspection — Field Procedures:

Common Causes:
- LAN cable damaged by physical stress or pinching
- RJ45 connector crimped incorrectly or clip broken
- Wall socket RJ45 port damaged or corroded
- Fiber patch cord bent sharply causing internal fracture
- Router port physically damaged

Required Tools:
- RJ45 cable tester
- Spare Cat5e/Cat6 patch cables
- Spare fiber patch cord
- Fiber inspection probe
- Replacement RJ45 wall socket if needed

Field Procedures:
1. Visual inspection of all cables — check full length for cuts, kinks, sharp bends
2. Inspect all RJ45 connectors — check retaining clip, look for bent pins or corrosion
3. Test LAN cable with cable tester — check all 8 pins for continuity
4. Replace suspect LAN cable with known-good spare — test connectivity after swap
5. Inspect fiber patch cord end-faces with probe — look for scratches or contamination
6. Test each router LAN port individually — swap cable between ports to identify dead port
7. Inspect wall socket RJ45 port — test with cable tester; replace if port fails
8. Document all replaced components with part numbers for TM inventory records

Safety Notes:
- Never force an RJ45 connector — inspect port for obstruction if resistance felt
- Power off equipment before replacing wall sockets
''';

      // SOFTWARE SUBCATEGORIES
      case 'software_pppoe_auth':
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
3. Verify PPPoE username format — TM format: [account]@unifi.my or [account]@streamyx.com
4. Re-enter PPPoE password manually — do not rely on saved credentials
5. Check TM account status via technician portal — confirm account is active
6. Set VLAN ID to 500 for internet WAN — missing VLAN causes authentication failure
7. If still failing after correct credentials, check for TM RADIUS server issue with NOC
8. If account suspended, advise customer to contact TM billing

Safety Notes:
- Never share customer PPPoE credentials outside TM systems
- Confirm with customer before resetting any credentials
''';

      case 'software_vlan_config':
        return '''
TM VLAN and Service Configuration — Field Procedures:

Common Causes:
- Internet VLAN ID not set to 500
- IPTV VLAN ID not set to 600
- VLAN tagging disabled after factory reset
- HyppTV subscription mismatch in TM middleware
- Multicast settings disabled causing IPTV failure

Required Tools:
- Laptop for router admin panel access (192.168.1.1)
- TM technician portal for subscription verification

Field Procedures:
1. Log into router admin — navigate to WAN/VLAN settings
2. Confirm Internet WAN VLAN ID = 500 with PPPoE connection type
3. Confirm IPTV WAN VLAN ID = 600 with multicast settings enabled
4. Check IPTV port assignment — correct LAN port must be tagged for IPTV traffic (usually LAN4)
5. Verify HyppTV STB is connected to correct router port
6. Check HyppTV subscription status via TM portal — confirm IPTV package is active
7. Reboot in sequence — router first, wait 2 minutes, then power STB
8. If still fails, escalate to TM IPTV middleware team with STB MAC address

Safety Notes:
- Changing VLAN settings causes brief outage — inform customer before changes
- Document original VLAN configuration before modifying
''';

      case 'software_dns_issue':
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
5. Change primary DNS to 8.8.8.8 and secondary to 1.1.1.1 — apply and save
6. Flush DNS cache — reboot router and run ipconfig /flushdns on Windows laptop
7. Test browsing after DNS change — confirm websites load correctly
8. If specific websites still fail, check firewall rules blocking port 53 UDP/TCP

Safety Notes:
- Note original DNS addresses before changing — revert if custom DNS was intentional
- DNS changes take effect immediately — no extended outage expected
''';

      // DEFAULT / OTHER
      default:
        return '''
TM General Troubleshooting — Standard Field Procedures:

Common Causes:
- Undetermined fault requiring systematic layer-by-layer isolation
- Issue may span multiple systems (physical, network, software, account)
- External factor such as weather, construction, or third-party interference

Required Tools:
- Optical Power Meter and fiber inspection probe
- Cable tester and multimeter
- Laptop for configuration and diagnostic access
- TM technician portal for account and line status verification

Field Procedures:
1. Gather detailed issue description — exact symptoms, when it started, what changed recently
2. Verify TM account status and active services via technician portal
3. Check TM service outage dashboard — confirm no active area outage
4. Inspect all physical connections from entry point to all CPE units
5. Test systematically: physical → optical signal → network → application layer
6. Isolate whether fault is on TM infrastructure or customer premises equipment
7. Apply fix at identified fault layer and verify full service restoration
8. If root cause undetermined, document all findings and escalate to TM NOC

Safety Notes:
- Follow TM field safety guidelines at all times
- Do not access street cabinets without proper authorisation
''';
    }
  }

  // --- Fetch Similar Past Tickets WITH Resolution Notes ---
  Future<String> _getSimilarTicketsContext(
    String category,
    String subcategory,
    String currentTicketId,
  ) async {
    try {
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
      buffer.writeln(
        'Past resolved "$category" tickets (subcategory: $subcategory):',
      );
      buffer.writeln();

      int count = 0;
      for (final ticketDoc in ticketSnapshot.docs) {
        if (ticketDoc.id == currentTicketId) continue;
        if (count >= 3) break;

        final ticketData = ticketDoc.data();
        final title = ticketData['title']?.toString() ?? '';
        final description = ticketData['description']?.toString() ?? '';

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
    // Step 4: Classify into subcategory
    final subcategory = _detectSubcategory(category, title, description);

    // Step 5: Retrieve subcategory-specific knowledge base
    final knowledgeBase = _getKnowledgeBase(category, subcategory);

    // Step 5: Retrieve past resolved cases with resolution notes
    final similarTickets = await _getSimilarTicketsContext(
      category,
      subcategory,
      ticketId,
    );

    final existingContext = addToExisting && existingItems != null
        ? '''
Current checklist items already generated (DO NOT repeat these):
${existingItems.map((e) => '- ${e['title']}').join('\n')}
'''
        : '';

    // Step 6: Construct prompt
    final prompt =
        '''
You are an AI assistant for TM (Telekom Malaysia) field technicians.
Your job is to generate a specific, actionable troubleshooting checklist based on the ticket below.

=== TM KNOWLEDGE BASE — "$category" / "$subcategory" ISSUE ===
$knowledgeBase

=== PAST RESOLVED CASES (learn from these resolutions) ===
$similarTickets

=== CURRENT TICKET TO SOLVE ===
Category: $category
Detected Issue Type: $subcategory
Issue Title: $title
Customer Description: $description

$existingContext

=== YOUR TASK ===
Generate a checklist tailored specifically to THIS ticket.
Use the knowledge base for correct TM procedures, tools, and acceptable value ranges.
Use the past resolved cases to inform likely root causes and proven fix steps.

Each checklist item must have:
- title: short action step (max 8 words)
- detail: specific instruction relevant to this exact ticket (1-2 sentences, mention specific TM tools, settings, or values where applicable)
- priority: exactly one of "High", "Medium", or "Low"
- estimatedTime: realistic time like "5 mins", "10 mins", "15 mins", "30 mins"

Rules:
- Generate between 5 to 8 checklist items
- Order from highest to lowest priority
- High = directly targets most likely root cause for this specific issue type
- Medium = important verification or diagnostic step
- Low = good practice check, less likely root cause
- Reference specific TM values where relevant (e.g. VLAN 500, GPON Rx: -8 to -27 dBm, 192.168.1.1)
- Do NOT generate generic steps that could apply to any IT issue

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
        final map = item is Map<String, dynamic>
            ? item
            : Map<String, dynamic>.from(
                (item as Map).map((k, v) => MapEntry(k.toString(), v)),
              );
        return {
          'title': map['title']?.toString() ?? '',
          'detail': map['detail']?.toString() ?? '',
          'priority': map['priority']?.toString() ?? 'Medium',
          'estimatedTime': map['estimatedTime']?.toString() ?? '10 mins',
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
