// lib/features/supervisor/pending_technicians_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';
import '../../utils/friendly_error.dart';
import '../../utils/pending_technicians.dart';
import '../../widgets/app_snack.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/stream_error.dart';

/// A technician request read from a users document.
class _PendingRequest {
  final String id;
  final String name;
  final String? staffId;
  final String? email;
  final String? phone;
  final String? specialization;
  final List<String> areas;
  final DateTime? requestedAt;

  const _PendingRequest({
    required this.id,
    required this.name,
    required this.staffId,
    required this.email,
    required this.phone,
    required this.specialization,
    required this.areas,
    required this.requestedAt,
  });

  static String? _text(Object? v) {
    final t = v?.toString().trim();
    return t == null || t.isEmpty ? null : t;
  }

  factory _PendingRequest.fromDoc(String id, Map<String, dynamic> data) {
    final areas = data['coverageAreas'];
    final created = data['createdAt'];
    return _PendingRequest(
      id: id,
      name: _text(data['fullName']) ?? 'Unnamed Technician',
      staffId: _text(data['staffId']) ?? _text(data['employeeId']),
      email: _text(data['email']),
      phone: _text(data['phone']),
      specialization: _text(data['specialization']),
      areas: areas is List ? [for (final a in areas) a.toString()] : const [],
      requestedAt: created is Timestamp ? created.toDate() : null,
    );
  }
}

class PendingTechniciansScreen extends StatefulWidget {
  const PendingTechniciansScreen({super.key});

  @override
  State<PendingTechniciansScreen> createState() =>
      _PendingTechniciansScreenState();
}

class _PendingTechniciansScreenState extends State<PendingTechniciansScreen> {
  late Stream<QuerySnapshot> _stream;

  // Requests with a write in progress: their buttons are disabled, so a double
  // tap cannot send two writes.
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _createStream();
  }

  void _createStream() {
    _stream = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'technician')
        .where('approved', isEqualTo: false)
        .snapshots();
  }

  /// Writes only [field] on the user's document. The row leaves the list on its
  /// own, because the stream no longer matches it.
  Future<void> _write(
    _PendingRequest r,
    String field,
    String successMessage,
  ) async {
    if (_busy.contains(r.id)) return;
    setState(() => _busy.add(r.id));

    try {
      await FirebaseFirestore.instance.collection('users').doc(r.id).update({
        field: true,
      });
      if (!mounted) return;
      showAppSnack(context, successMessage, kind: SnackKind.success);
    } catch (e, st) {
      if (!mounted) return;
      showAppSnack(
        context,
        friendlyError(
          e,
          fallback: 'Could not save the change. Please try again.',
          stackTrace: st,
        ),
        kind: SnackKind.error,
      );
    } finally {
      if (mounted) setState(() => _busy.remove(r.id));
    }
  }

  Future<void> _approve(_PendingRequest r) =>
      _write(r, 'approved', '${r.name} approved');

  Future<void> _reject(_PendingRequest r) async {
    if (_busy.contains(r.id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _RejectDialog(name: r.name),
    );
    if (confirmed != true || !mounted) return;
    await _write(r, 'rejected', '${r.name} rejected');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Pending Technicians',
          style: AppText.heading.copyWith(color: AppColors.ink),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return StreamError(
              error: snapshot.error,
              onRetry: () => setState(_createStream),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final requests = [
            for (final d in snapshot.data!.docs)
              if (isPendingTechnician(d.data() as Map<String, dynamic>))
                _PendingRequest.fromDoc(d.id, d.data() as Map<String, dynamic>),
          ];
          // Newest request first; a missing date goes last.
          requests.sort((a, b) {
            final x = a.requestedAt, y = b.requestedAt;
            if (x == null && y == null) return 0;
            if (x == null) return 1;
            if (y == null) return -1;
            return y.compareTo(x);
          });

          if (requests.isEmpty) {
            return const EmptyState(
              icon: Icons.how_to_reg_outlined,
              title: 'No Pending Requests',
              subtitle: 'New technician requests will show up here.',
            );
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.s4),
            children: [
              Text(
                requests.length == 1
                    ? '1 request waiting'
                    : '${requests.length} requests waiting',
                style: AppText.caption.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.s3),
              for (final r in requests) ...[
                _RequestCard(
                  request: r,
                  busy: _busy.contains(r.id),
                  onApprove: () => _approve(r),
                  onReject: () => _reject(r),
                ),
                const SizedBox(height: AppSpacing.s3),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final _PendingRequest request;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _RequestCard({
    required this.request,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  Widget _line(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.s2),
    child: Row(
      children: [
        Icon(icon, size: 18, color: AppColors.inkMuted),
        const SizedBox(width: AppSpacing.s2),
        Expanded(
          child: Text(text, style: AppText.body.copyWith(color: AppColors.ink)),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final r = request;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: AppRadius.brLg,
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  r.name,
                  style: AppText.heading.copyWith(color: AppColors.ink),
                ),
              ),
              if (r.requestedAt != null) ...[
                const SizedBox(width: AppSpacing.s2),
                Text(
                  'Requested ${formatRequestedDate(r.requestedAt!)}',
                  style: AppText.caption.copyWith(color: AppColors.inkMuted),
                ),
              ],
            ],
          ),
          if (r.staffId != null) _line(Icons.badge_outlined, r.staffId!),
          if (r.email != null) _line(Icons.mail_outline, r.email!),
          if (r.phone != null) _line(Icons.phone_outlined, r.phone!),
          if (r.specialization != null)
            _line(Icons.home_repair_service_outlined, r.specialization!),
          if (r.areas.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s3),
            Text(
              'Coverage Areas',
              style: AppText.caption.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.s1),
            Wrap(
              spacing: AppSpacing.s2,
              runSpacing: AppSpacing.s2,
              children: [
                for (final a in r.areas)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s3,
                      vertical: AppSpacing.s1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: AppRadius.brPill,
                    ),
                    child: Text(
                      a,
                      style: AppText.caption.copyWith(color: AppColors.primary),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.s4),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentStrong,
                    side: const BorderSide(
                      color: AppColors.accentStrong,
                      width: 1.5,
                    ),
                    minimumSize: const Size(64, 48),
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
                    textStyle: AppText.bodyStrong,
                  ),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: ElevatedButton(
                  onPressed: busy ? null : onApprove,
                  style: busy
                      ? ElevatedButton.styleFrom(
                          disabledBackgroundColor: AppColors.accentStrong,
                          disabledForegroundColor: AppColors.onPrimary,
                        )
                      : null,
                  child: busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: AppColors.onPrimary,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RejectDialog extends StatelessWidget {
  final String name;

  const _RejectDialog({required this.name});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.brLg),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.cancelledBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_off_outlined,
              size: 22,
              color: AppColors.cancelledFg,
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            'Reject This Request?',
            style: AppText.heading.copyWith(color: AppColors.ink),
          ),
          const SizedBox(height: AppSpacing.s2),
          Text.rich(
            TextSpan(
              style: AppText.body.copyWith(color: AppColors.inkMuted),
              children: [
                TextSpan(
                  text: name,
                  style: AppText.bodyStrong.copyWith(color: AppColors.ink),
                ),
                const TextSpan(text: ' will not get technician access.'),
              ],
            ),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.s4,
        0,
        AppSpacing.s4,
        AppSpacing.s4,
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cancelledFg,
                  foregroundColor: AppColors.onPrimary,
                ),
                child: const Text('Reject'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
