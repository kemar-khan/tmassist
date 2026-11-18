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
