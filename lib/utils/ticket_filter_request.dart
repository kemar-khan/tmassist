/// Asks a tickets tab to select a status filter. [id] must change for every
/// new request, so asking for the same [status] again applies it again.
/// [status] is one of the chip values: 'All', 'NEW', 'ASSIGNED',
/// 'IN_PROGRESS', 'RESOLVED', 'CLOSED', 'CANCELLED'.
class TicketFilterRequest {
  final String status;
  final int id;

  const TicketFilterRequest({required this.status, required this.id});
}
