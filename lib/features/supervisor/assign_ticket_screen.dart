import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';
import '../../utils/cancelled_status.dart';
import '../../widgets/app_snack.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/picker_sheet.dart';
import '../../widgets/status_badge.dart';

class AssignTicketScreen extends StatefulWidget {
  final String ticketId;

  const AssignTicketScreen({super.key, required this.ticketId});

  @override
  State<AssignTicketScreen> createState() => _AssignTicketScreenState();
}

class _AssignTicketScreenState extends State<AssignTicketScreen> {
  String? _selectedTechnicianId;
  String? _selectedTechnicianName;
  bool _isLoading = false;

  // The streams are created once: creating them inside build() would
  // re-subscribe (and flash the spinner) every time a technician is picked.
  late final Stream<DocumentSnapshot> _ticketStream;
  late final Stream<QuerySnapshot> _techStream;

  @override
  void initState() {
    super.initState();
    _ticketStream = FirebaseFirestore.instance
        .collection('tickets')
        .doc(widget.ticketId)
        .snapshots();
    _techStream = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'technician')
        .snapshots();
  }

  Future<void> _handleAssign() async {
    if (_selectedTechnicianId == null || _selectedTechnicianName == null) {
      showAppSnack(
        context,
        "Please select a technician",
        kind: SnackKind.error,
      );
      return;
    }

    final supervisor = FirebaseAuth.instance.currentUser;
    if (supervisor == null) {
      showAppSnack(
        context,
        "No logged in supervisor found",
        kind: SnackKind.error,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final ref = FirebaseFirestore.instance
          .collection('tickets')
          .doc(widget.ticketId);

      // The customer may have cancelled while this screen was open; never
      // overwrite CANCELLED with ASSIGNED.
      final current = await ref.get();
      if (CancelledStatus.isCancelled(current.data()?['status'])) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        showAppSnack(context, "This ticket was cancelled by the customer.");
        return;
      }

      await ref.update({
        'technicianId': _selectedTechnicianId,
        'technicianName': _selectedTechnicianName,
        'supervisorId': supervisor.uid,
        'status': 'ASSIGNED',
        'assignmentType': 'MANUAL',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.pop(context);

      showAppSnack(
        context,
        "Ticket assigned to $_selectedTechnicianName",
        kind: SnackKind.success,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      showAppSnack(context, "Error: $e", kind: SnackKind.error);
    }
  }

  Widget _messageScaffold(String title, Widget body) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: body,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _ticketStream,
      builder: (context, ticketSnapshot) {
        if (!ticketSnapshot.hasData &&
            ticketSnapshot.connectionState == ConnectionState.waiting) {
          return _messageScaffold(
            'Assign Ticket',
            const Center(child: CircularProgressIndicator()),
          );
        }

        if (ticketSnapshot.hasError) {
          return _messageScaffold(
            "Error",
            EmptyState(
              icon: Icons.error_outline_rounded,
              title: "Error: ${ticketSnapshot.error}",
            ),
          );
        }

        if (!ticketSnapshot.hasData || !ticketSnapshot.data!.exists) {
          return _messageScaffold(
            "Error",
            const EmptyState(
              icon: Icons.confirmation_number_outlined,
              title: "Ticket not found",
            ),
          );
        }

        final ticketData = ticketSnapshot.data!.data() as Map<String, dynamic>;
        final ticketTitle = (ticketData['title'] ?? 'No Title').toString();
        final ticketDescription =
            (ticketData['description'] ?? 'No description').toString();
        final ticketStatus = (ticketData['status'] ?? 'NEW')
            .toString()
            .toUpperCase();
        final createdAt = ticketData['createdAt'];

        return StreamBuilder<QuerySnapshot>(
          stream: _techStream,
          builder: (context, techSnapshot) {
            if (!techSnapshot.hasData &&
                techSnapshot.connectionState == ConnectionState.waiting) {
              return _messageScaffold(
                'Assign Ticket',
                const Center(child: CircularProgressIndicator()),
              );
            }

            if (techSnapshot.hasError) {
              return _messageScaffold(
                "Error",
                EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: "Error: ${techSnapshot.error}",
                ),
              );
            }

            final technicians = techSnapshot.data?.docs ?? [];

            return AssignTicketView(
              ticketId: widget.ticketId,
              title: ticketTitle,
              description: ticketDescription,
              status: ticketStatus,
              createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
              showAutoNotice:
                  ticketData['assignmentType'] == 'AUTO' &&
                  ticketData['technicianId'] != null,
              technicians: [
                for (final techDoc in technicians)
                  AssignTechnicianOption(
                    id: techDoc.id,
                    name:
                        ((techDoc.data() as Map<String, dynamic>)['fullName'] ??
                                'Unnamed Technician')
                            .toString(),
                    specialization:
                        ((techDoc.data()
                                    as Map<
                                      String,
                                      dynamic
                                    >)['specialization'] ??
                                '')
                            .toString(),
                  ),
              ],
              selectedTechnicianId: _selectedTechnicianId,
              isLoading: _isLoading,
              onTechnicianPicked: (val) {
                final selectedDoc = technicians.firstWhere(
                  (doc) => doc.id == val,
                );
                final data = selectedDoc.data() as Map<String, dynamic>;

                setState(() {
                  _selectedTechnicianId = val;
                  _selectedTechnicianName =
                      (data['fullName'] ?? 'Unnamed Technician').toString();
                });
              },
              onConfirm: _handleAssign,
              onCancel: () => Navigator.pop(context),
            );
          },
        );
      },
    );
  }
}

/// One technician in the picker.
class AssignTechnicianOption {
  final String id;
  final String name;

  /// Empty when the technician has none.
  final String specialization;

  const AssignTechnicianOption({
    required this.id,
    required this.name,
    this.specialization = '',
  });
}

/// The Assign Ticket page. Separate from [AssignTicketScreen] so it can be
/// built without Firebase; the screen loads the data and does the saving.
class AssignTicketView extends StatelessWidget {
  final String ticketId;
  final String title;
  final String description;
  final String status;
  final DateTime? createdAt;

  /// Show the "auto-assigned" notice (the ticket was assigned automatically).
  final bool showAutoNotice;
  final List<AssignTechnicianOption> technicians;
  final String? selectedTechnicianId;
  final bool isLoading;

  /// Called with the technician's id when one is chosen in the picker.
  final ValueChanged<String> onTechnicianPicked;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const AssignTicketView({
    super.key,
    required this.ticketId,
    required this.title,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.showAutoNotice,
    required this.technicians,
    required this.selectedTechnicianId,
    required this.isLoading,
    required this.onTechnicianPicked,
    required this.onConfirm,
    required this.onCancel,
  });

  AssignTechnicianOption? get _selected {
    for (final t in technicians) {
      if (t.id == selectedTechnicianId) return t;
    }
    return null;
  }

  Future<void> _openPicker(BuildContext context) async {
    final picked = await showPickerSheet<String>(
      context,
      title: 'Select technician',
      options: [for (final t in technicians) t.id],
      selected: selectedTechnicianId,
      labelBuilder: (id) => technicians.firstWhere((t) => t.id == id).name,
      subtitleBuilder: (id) =>
          technicians.firstWhere((t) => t.id == id).specialization,
      showRadio: true,
    );
    if (picked != null) onTechnicianPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm =
        !isLoading && technicians.isNotEmpty && selectedTechnicianId != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Assign Ticket')),
      body: SafeArea(
        // The confirm bar below handles the bottom inset.
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SummaryCard(
                ticketId: ticketId,
                title: title,
                description: description,
                status: status,
                createdAt: createdAt,
              ),
              if (showAutoNotice) ...[
                const SizedBox(height: AppSpacing.s3),
                const _AutoAssignNotice(),
              ],
              const SizedBox(height: AppSpacing.s6),
              Text(
                "Override Assignment",
                style: AppText.title.copyWith(color: AppColors.ink),
              ),
              const SizedBox(height: AppSpacing.s2),
              if (technicians.isEmpty)
                const EmptyState(
                  icon: Icons.person_off_rounded,
                  title: "No technicians available.",
                )
              else
                AppPickerField(
                  label: "Available Technicians",
                  value: _selected?.name,
                  hint: 'Select technician',
                  prefixIcon: Icons.person_search_outlined,
                  onTap: isLoading ? null : () => _openPicker(context),
                ),
              const SizedBox(height: AppSpacing.s4),
              Center(
                child: TextButton(
                  onPressed: onCancel,
                  child: const Text("Cancel"),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surfaceCard,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s4,
              AppSpacing.s3,
              AppSpacing.s4,
              AppSpacing.s4,
            ),
            child: ElevatedButton(
              onPressed: canConfirm ? onConfirm : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : const Text("CONFIRM ASSIGNMENT"),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String ticketId;
  final String title;
  final String description;
  final String status;
  final DateTime? createdAt;

  const _SummaryCard({
    required this.ticketId,
    required this.title,
    required this.description,
    required this.status,
    required this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    final date = createdAt == null
        ? '-'
        : '${createdAt!.day}/${createdAt!.month}/${createdAt!.year}';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: AppRadius.brLg,
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ticketId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(color: AppColors.inkFaint),
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(title, style: AppText.heading.copyWith(color: AppColors.ink)),
          if (description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s1),
            Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppText.body.copyWith(color: AppColors.inkMuted),
            ),
          ],
          const SizedBox(height: AppSpacing.s3),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.s3),
          Row(
            children: [
              const ExcludeSemantics(
                child: Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: AppColors.inkFaint,
                ),
              ),
              const SizedBox(width: AppSpacing.s1),
              Text(
                date,
                style: AppText.caption.copyWith(color: AppColors.inkFaint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AutoAssignNotice extends StatelessWidget {
  const _AutoAssignNotice();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s3),
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: AppRadius.brMd,
        ),
        child: Row(
          children: [
            const ExcludeSemantics(
              child: Icon(
                Icons.info_outline,
                size: 24,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Text(
                'This ticket was auto-assigned. You can override it below.',
                style: AppText.body.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
