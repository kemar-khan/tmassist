/// How long the app waits for slow operations before giving up. Reads of
/// Firestore data, login, register and supervisor writes deliberately have no
/// limit here.
class Timeouts {
  Timeouts._();

  /// Gemini: the category / title suggestion on Submit Ticket.
  static const aiSuggestion = Duration(seconds: 45);

  /// Gemini: checklist generation on the technician Checklist screen.
  static const checklistGeneration = Duration(seconds: 45);

  /// Cloudinary uploads (customer attachment and technician proof photo).
  static const fileUpload = Duration(seconds: 45);

  /// Current position and reverse address lookup on Submit Ticket.
  static const location = Duration(seconds: 15);

  /// Creating a ticket. A timeout here does not mean the write failed: the
  /// write stays queued while the phone is offline.
  static const ticketCreate = Duration(seconds: 20);

  /// Reading the signed-in user's profile after the app starts. A bad network
  /// must not leave the start screen spinning for ever.
  static const profileLoad = Duration(seconds: 15);

  /// Waiting for Firebase to hand back the session saved on the phone at
  /// startup (no network is needed for this).
  static const authRestore = Duration(seconds: 3);

  /// How long a Gemini call may run before the "Still working…" hint shows.
  static const slowHint = Duration(seconds: 10);
}
