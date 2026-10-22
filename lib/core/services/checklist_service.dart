import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // TEMP-DEBUG [CHECKLIST] (for debugPrint)
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
  // Short terms (4 chars or fewer) match whole words; longer terms use contains
  bool _has(String text, List<String> terms) {
    for (final t in terms) {
      if (t.length <= 4) {
        if (RegExp('\\b${RegExp.escape(t)}(s|ed|ing|ly)?\\b').hasMatch(text)) {
          return true;
        }
      } else if (text.contains(t)) {
        return true;
      }
    }
    return false;
  }

  String _detectSubcategory(String category, String title, String description) {
    final text = '$title $description'.toLowerCase();

    // Pass 1: distinctive service keywords, matched regardless of the
    // category Gemini chose. Gemini often files TV/phone/DNS issues under
    // "Network", so we don't let the category block these.
    if (_has(text, [
      'onu password',
      'auth led',
      'auth light',
      'not authenticated',
    ])) {
      return 'onu_auth_failure';
    }

    if (_has(text, [
      'voip',
      'telephone',
      'landline',
      'dial tone',
      'tel1',
      'tel2',
      'home phone',
      'phone line',
      'voice',
    ])) {
      return 'voip_issue';
    }

    if (_has(text, [
      'not turning on',
      'no power',
      'not powering',
      'power led',
      'power adapter',
    ])) {
      return 'ont_failure';
    }

    final powerFault = _has(text, [
      'not turning on',
      'no power',
      'not powering',
      'power led',
      'power adapter',
    ]);

    if (!powerFault &&
        _has(text, [
          'iptv',
          'hypptv',
          'vlan',
          'tv box',
          'tv channel',
          'set top box',
          'set-top',
        ])) {
      return 'vlan_config';
    }

    if (_has(text, ['dns', 'website'])) {
      return 'dns_issue';
    }

    if (_has(text, ['pppoe'])) {
      return 'pppoe_auth';
    }

    // Pass 2: category-specific rules (your existing switch, unchanged)

    switch (category.toLowerCase()) {
      case 'network':
        if (_has(text, [
          'auth led',
          'auth light',
          'not authenticated',
          'onu password',
        ]))
          return 'onu_auth_failure';

        if (_has(text, [
          'los',
          'fiber',
          'fibre',
          'no internet',
          'red light',
          'no connection',
          'signal loss',
          'completely down',
          'total outage',
          'link led',
          'no signal',
        ]))
          return 'fiber_loss';

        if (_has(text, [
          'wifi',
          'wi-fi',
          'wireless',
          'weak signal',
          'cannot connect',
          'no wifi',
        ]))
          return 'wifi_issue';

        if (_has(text, [
          'slow',
          'slower',
          'speed',
          'buffering',
          'mbps',
          'lagging',
          'low speed',
        ]))
          return 'speed_degradation';

        if (_has(text, [
          'disconnect',
          'dropping',
          'unstable',
          'intermittent',
          'keeps cutting',
          'on and off',
          'random',
        ]))
          return 'intermittent';

        debugPrint(
          '[CHECKLIST] USING FALLBACK default subcategory fiber_loss (no network keyword matched)',
        ); // TEMP-DEBUG [CHECKLIST]
        return 'fiber_loss'; // default network

      case 'hardware':
        if (_has(text, [
          'ont',
          'onu',
          'no light',
          'no power',
          'power led',
          'power adapter',
          'dead',
          'not turning on',
        ]))
          return 'ont_failure';

        if (_has(text, [
          'router',
          'lan',
          'ethernet',
          'admin page',
          'cannot access',
        ]))
          return 'router_failure';

        if (_has(text, [
          'cable',
          'port',
          'loose',
          'damaged',
          'broken',
          'connector',
          'patch cord',
          'bent',
        ]))
          return 'cable_damage';

        debugPrint(
          '[CHECKLIST] USING FALLBACK default subcategory ont_failure (no hardware keyword matched)',
        ); // TEMP-DEBUG [CHECKLIST]
        return 'ont_failure'; // default hardware

      case 'software':
        if (_has(text, [
          'voip',
          'telephone',
          'landline',
          'dial tone',
          'tel1',
          'tel2',
          'home phone',
          'voice',
        ]))
          return 'voip_issue';

        if (_has(text, [
          'password',
          'pppoe',
          'authentication',
          'login',
          'credential',
          'username',
        ]))
          return 'pppoe_auth';

        if (_has(text, [
          'vlan',
          'iptv',
          'hypptv',
          'tv',
          'setup',
          'configuration',
          'misconfigured',
        ]))
          return 'vlan_config';

        if (_has(text, [
          'dns',
          'website',
          'browsing',
          'cannot open',
          'ping',
          'domain',
        ]))
          return 'dns_issue';

        debugPrint(
          '[CHECKLIST] USING FALLBACK default subcategory pppoe_auth (no software keyword matched)',
        ); // TEMP-DEBUG [CHECKLIST]
        return 'pppoe_auth'; // default software

      default:
        debugPrint(
          '[CHECKLIST] USING FALLBACK subcategory general (category "$category" is not network/hardware/software)',
        ); // TEMP-DEBUG [CHECKLIST]
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

Source: TM Training Centre, Unifi FTTH module (ONU LED table, PON power budget, tools)
''';

      case 'network_onu_auth_failure':
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

Source: TM Training Centre, Unifi FTTH module (ONU normal working condition, fault test method)
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

Source: TM Training Centre, Unifi FTTH module (QoS internet speed slides, PON technology)
''';

      case 'network_intermittent':
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
4. Check the power adapter and power port (the deck lists changing the adapter or power port)
5. Measure received power with the power meter (sensitivity -28 dBm)
6. Run a continuous ping for about 30 minutes and compare against the TM standard: packet loss up to 1%, latency up to 85 ms (general practice for the test)
7. Replace the patch cord if no other cause is found
8. If drops continue with a healthy link, escalate with the ping log and drop times

Safety Notes:
- Never look into a fibre end-face
- Note the exact times of each disconnection

Source: TM Training Centre, Unifi FTTH module (ONU LED table, QoS slides, ONU fault test method)
''';

      // HARDWARE SUBCATEGORIES
      case 'hardware_ont_failure':
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

Source: TM Training Centre, Unifi FTTH module (ONU back and front panel, fault test method)
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

Source: TM Training Centre, Unifi FTTH module (fibre cleaning kits, inspection scope, FWS, fibre types)
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
3. Check the PG WAN and INTERNET LEDs
4. Verify the VLAN for the affected service: internet 500, IPTV 600, voice 400
5. For IPTV, confirm the STB is connected to PG LAN4
6. For voice, confirm the phone is on ONU TEL1 or TEL2 and the VOIP LED is white
7. Reboot in order: ONU, then PG, then STB (general practice)
8. If LINK and AUTH are on but there is still no service, call the field technical centre to check the service VLAN on the ONU and OLT

Safety Notes:
- Changing VLAN settings causes a brief outage, so inform the customer first
- Record the original settings before changing them

Source: TM Training Centre, Unifi FTTH module (HSBB VLAN table, CPE layout, ONU fault test method)
''';

      case 'software_voip_issue':
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

Source: TM Training Centre, Unifi FTTH module (ONU front panel, HSBB VLAN table)
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
        debugPrint(
          '[CHECKLIST] USING FALLBACK default knowledge base entry (no entry for key "$key")',
        ); // TEMP-DEBUG [CHECKLIST]
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
        debugPrint(
          '[CHECKLIST] USING FALLBACK (similar-tickets context: no RESOLVED tickets for category $category)',
        ); // TEMP-DEBUG [CHECKLIST]
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
        debugPrint(
          '[CHECKLIST] USING FALLBACK (similar-tickets context: resolved tickets found but none had a report with rootCause/stepsTaken)',
        ); // TEMP-DEBUG [CHECKLIST]
        return 'No similar resolved tickets with resolution details found.';
      }

      return buffer.toString();
    } catch (e, st) {
      // TEMP-DEBUG [CHECKLIST] start
      debugPrint('[CHECKLIST] ERROR in _getSimilarTicketsContext: $e');
      debugPrint('[CHECKLIST] STACK $st');
      debugPrint(
        '[CHECKLIST] ERROR ... returning fallback context string "Could not retrieve similar tickets."',
      );
      debugPrint('[CHECKLIST] USING FALLBACK (similar-tickets context)');
      // TEMP-DEBUG [CHECKLIST] end
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

    // TEMP-DEBUG [CHECKLIST] start
    debugPrint('[CHECKLIST] category=$category subcategory=$subcategory');
    debugPrint('[CHECKLIST] KB length=${knowledgeBase.length}');
    debugPrint(
      '[CHECKLIST] KB first 120 chars: ${knowledgeBase.substring(0, knowledgeBase.length < 120 ? knowledgeBase.length : 120).replaceAll('\n', ' ')}',
    );
    // TEMP-DEBUG [CHECKLIST] end

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
- Reference specific TM values only when they appear in the knowledge base above (e.g. VLAN 400/500/600, ONU sensitivity -28 dBm, throughput at least 90% of plan). Do not invent values.
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
      // TEMP-DEBUG [CHECKLIST] start
      debugPrint('[CHECKLIST] >>> PROMPT');
      for (final line in prompt.split('\n')) {
        debugPrint('[CHECKLIST] $line');
      }
      debugPrint('[CHECKLIST] <<< END PROMPT');
      // TEMP-DEBUG [CHECKLIST] end
      final content = [Content.text(prompt)];
      final stopwatch = Stopwatch()..start();
      final response = await _model.generateContent(content);
      stopwatch.stop();
      print(
        'DEBUG [Checklist] Gemini response time: ${stopwatch.elapsedMilliseconds}ms (${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s)',
      );
      print('DEBUG [Checklist] Subcategory detected: $subcategory');
      final responseText = response.text ?? '';

      // TEMP-DEBUG [CHECKLIST] start
      debugPrint('[CHECKLIST] >>> RAW RESPONSE');
      for (final line in responseText.split('\n')) {
        debugPrint('[CHECKLIST] $line');
      }
      debugPrint('[CHECKLIST] <<< END RESPONSE');
      // TEMP-DEBUG [CHECKLIST] end

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

      // TEMP-DEBUG [CHECKLIST] start
      debugPrint('[CHECKLIST] parsed ${parsed.length} item(s)');
      if (parsed.isEmpty) {
        debugPrint(
          '[CHECKLIST] WARNING parser matched 0 items; the checklist returned is EMPTY (no fallback list exists)',
        );
      }
      // TEMP-DEBUG [CHECKLIST] end

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
    } catch (e, st) {
      // TEMP-DEBUG [CHECKLIST] start
      debugPrint('[CHECKLIST] ERROR in generateChecklist: $e');
      debugPrint('[CHECKLIST] STACK $st');
      debugPrint(
        '[CHECKLIST] ERROR ... no fallback checklist exists; rethrowing "Checklist generation failed"',
      );
      // TEMP-DEBUG [CHECKLIST] end
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
