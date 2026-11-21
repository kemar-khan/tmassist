final RegExp _emailPattern = RegExp(
  r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9](?:[A-Za-z0-9\-]*[A-Za-z0-9])?'
  r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9\-]*[A-Za-z0-9])?)*\.[A-Za-z]{2,}$',
);

/// A form validator for an email address: null when it looks like a real
/// address (name, "@", a domain with a dot and a 2+ letter ending).
String? validateEmail(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return 'Enter your email';
  if (text.contains('..') || !_emailPattern.hasMatch(text)) {
    return 'Enter a valid email';
  }
  return null;
}

/// A form validator for a phone number. Same rule as the customer
/// registration: spaces, dashes and brackets are ignored, then 10 to 15
/// digits with an optional leading +.
String? validatePhone(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Enter your phone number';
  }
  final digitsOnly = value.trim().replaceAll(RegExp(r'[\s\-()]'), '');
  if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(digitsOnly)) {
    return 'Enter a valid phone number';
  }
  return null;
}
