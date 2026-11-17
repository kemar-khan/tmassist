class ServiceAreas {
  // The main urban centres of the Klang Valley: Kuala Lumpur, Putrajaya and the
  // Selangor districts Petaling, Klang, Hulu Langat, Gombak and Sepang. The
  // names are stored as exact strings on tickets and technician profiles, so
  // existing spellings must never change. "Other" stays last.
  static const List<String> all = [
    'Kuala Lumpur',
    'Putrajaya',
    'Petaling Jaya',
    'Subang Jaya',
    'Shah Alam',
    'Puchong',
    'Klang',
    'Kajang',
    'Rawang',
    'Cyberjaya',
    'Other',
  ];

  /// The areas a technician can choose as coverage: every area except "Other".
  static List<String> get coverageChoices =>
      all.where((a) => a != 'Other').toList();
}
