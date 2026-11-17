/// What a technician sees about how a job reached them, from the ticket's
/// `assignmentType`: "MANUAL" or "AUTO". Anything else (missing, empty,
/// unknown) gives null, and nothing is shown.
String? assignmentSourceLabel(String? type) {
  switch (type) {
    case 'MANUAL':
      return 'Assigned by Your Supervisor';
    case 'AUTO':
      return 'Assigned Automatically';
    default:
      return null;
  }
}
