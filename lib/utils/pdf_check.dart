import 'dart:typed_data';

/// Whether [bytes] look like a real PDF file: not empty and starting with the
/// ASCII bytes "%PDF" (0x25 0x50 0x44 0x46).
bool isValidPdfBytes(Uint8List bytes) {
  if (bytes.length < 4) return false;
  return bytes[0] == 0x25 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x44 &&
      bytes[3] == 0x46;
}
