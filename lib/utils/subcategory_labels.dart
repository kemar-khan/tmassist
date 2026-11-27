/// Readable names for the subcategory ids saved on a ticket
/// (`detectedSubcategory`), in one place.
const subcategoryNames = <String, String>{
  'fiber_loss': 'Fiber loss / no connection',
  'onu_auth_failure': 'ONU authentication failure',
  'speed_degradation': 'Speed degradation',
  'intermittent': 'Intermittent connection',
  'ont_failure': 'ONT / power failure',
  'cable_damage': 'Cable damage',
  'vlan_config': 'IPTV / VLAN configuration',
  'voip_issue': 'Home phone (VoIP)',
  'wifi_issue': 'Wi-Fi issue',
  'router_failure': 'Router failure',
  'pppoe_auth': 'Login / authentication',
  'dns_issue': 'DNS / website access',
  'general': 'General service request',
};

/// The "Based on" line for the checklist screen, or null when the ticket has
/// no saved detection (an older ticket), so nothing is shown.
///
/// - high / medium confidence: "Based on: NAME | Confidence: High".
/// - low confidence, `general` or an unknown id:
///   "General procedure: the issue was not clearly identified".
String? basedOnLine(String? subcategory, String? confidence) {
  final id = (subcategory ?? '').trim();
  final level = (confidence ?? '').trim().toLowerCase();
  if (id.isEmpty || level.isEmpty) return null;

  final name = subcategoryNames[id];
  if (name == null || id == 'general' || level == 'low') {
    return 'General procedure: the issue was not clearly identified';
  }
  if (level != 'high' && level != 'medium') {
    return 'General procedure: the issue was not clearly identified';
  }
  final shown = level == 'high' ? 'High' : 'Medium';
  return 'Based on: $name | Confidence: $shown';
}

/// Shown instead of a name when the issue type was not clearly identified.
const generalProcedureText =
    'General procedure: the issue was not clearly identified';

/// The parts of the "Based on" card. [level] is "High", "Medium" or "Low",
/// or null when no confidence bar should be shown.
typedef BasedOnInfo = ({String title, String? level});

/// What the "Based on" card shows, or null when the ticket has no saved
/// detection (an older ticket), so there is no card.
///
/// - a known subcategory with high / medium confidence: its name and level;
/// - `general` or low confidence: [generalProcedureText] with "Low";
/// - an unknown subcategory or confidence: [generalProcedureText], no level.
BasedOnInfo? basedOnInfo(String? subcategory, String? confidence) {
  final id = (subcategory ?? '').trim();
  final level = (confidence ?? '').trim().toLowerCase();
  if (id.isEmpty || level.isEmpty) return null;

  final name = subcategoryNames[id];
  if (name == null) return (title: generalProcedureText, level: null);
  if (id == 'general' || level == 'low') {
    return (title: generalProcedureText, level: 'Low');
  }
  return switch (level) {
    'high' => (title: name, level: 'High'),
    'medium' => (title: name, level: 'Medium'),
    _ => (title: generalProcedureText, level: null),
  };
}
