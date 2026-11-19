/// Cleans a phone number found by the AI: spaces, dashes and brackets are
/// removed, and a leading "+60" or "60" becomes "0". The result is accepted
/// only when it is 9 to 11 digits and starts with 0; otherwise an empty string
/// is returned (the form field is then left alone).
String cleanExtractedPhone(String? raw) {
  var text = (raw ?? '').replaceAll(RegExp(r'[\s\-()\[\]]'), '');
  if (text.isEmpty) return '';

  if (text.startsWith('+60')) {
    text = '0${text.substring(3)}';
  } else if (text.startsWith('60')) {
    text = '0${text.substring(2)}';
  }

  if (!RegExp(r'^0\d{8,10}$').hasMatch(text)) return '';
  return text;
}
