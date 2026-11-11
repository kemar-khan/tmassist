import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_tokens.dart';
import '../../widgets/app_snack.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/picker_sheet.dart';
import '../../widgets/section_card.dart';
import '../../core/services/ticket_service.dart';
import '../../core/services/cloudinary_service.dart';
import '../../utils/image_picker_helper.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../core/services/ai_extraction_service.dart';
import '../../core/constants/service_areas.dart';
import '../../utils/friendly_error.dart';
import 'dart:async';
import '../../core/config/timeouts.dart';
import '../../utils/photo_check.dart';
import '../../utils/slow_hint.dart';
import '../../widgets/slow_hint_text.dart';

class SubmitTicketScreen extends StatefulWidget {
  /// A photo that Android kept after killing the app (see recoverLostPhoto);
  /// it is uploaded as the attachment when the screen opens.
  final String? recoveredPhotoPath;

  const SubmitTicketScreen({super.key, this.recoveredPhotoPath});

  @override
  State<SubmitTicketScreen> createState() => _SubmitTicketScreenState();
}

class _SubmitTicketScreenState extends State<SubmitTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final TicketService _ticketService = TicketService();
  final TextEditingController _addressController = TextEditingController();

  String? _category;
  String? _title;
  String? _description;
  String? _address;
  String? _contactNumber;
  String? _attachmentUrl;
  String? _attachmentFileName;
  bool _isUploadingAttachment = false;
  bool _isGettingLocation = false;

  bool _isSubmitting = false;

  // AI Mode variables
  bool _isAiMode = false;
  bool _isExtracting = false;

  // "Still working…" shows when the AI suggestion takes longer than 10 s.
  final SlowHint _slowHint = SlowHint(after: Timeouts.slowHint);
  bool _showSlowHint = false;
  final TextEditingController _aiInputController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  final AiExtractionService _aiExtractionService = AiExtractionService();
  String? _selectedCategory;
  String? _selectedArea;
  String? _area;

  Future<void> _submitForm() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();

    setState(() {
      _isSubmitting = true;
    });

    try {
      // The timeout only stops WAITING. Firestore keeps the write queued while
      // the phone is offline, so the ticket may still be created: the call is
      // never repeated from here.
      await _ticketService
          .createTicket(
            category: _category!,
            title: _title!,
            description: _description!,
            address: _address!,
            area: _area!,
            contactNumber: _contactNumber!,
            attachmentUrl: _attachmentUrl, // add file upload later
          )
          .timeout(Timeouts.ticketCreate);

      if (!mounted) return;

      showAppSnack(
        context,
        'Ticket submitted successfully!',
        kind: SnackKind.success,
      );

      Navigator.pop(context);
    } on TimeoutException {
      // Not a failure: the form stays as it is, and the user is told to check
      // My Tickets before submitting again.
      if (!mounted) return;
      showAppSnack(
        context,
        'Your network is slow. Your ticket may still be submitted once you '
        'are back online. Please check My Tickets before submitting again.',
        kind: SnackKind.info,
      );
    } catch (e, st) {
      if (!mounted) return;

      showAppSnack(
        context,
        friendlyError(
          e,
          fallback: 'Could not submit your ticket. Please try again.',
          stackTrace: st,
        ),
        kind: SnackKind.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();

        if (permission == LocationPermission.denied) {
          throw const FriendlyException(
            'Location permission is denied. Allow it in the app settings.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw const FriendlyException(
          'Location permission is permanently denied. Allow it in the app settings.',
        );
      }

      // Position and address lookup share one 15 second limit.
      final address = await () async {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isEmpty) {
          throw const FriendlyException(
            'We could not find an address for your location. '
            'Please type the address yourself.',
          );
        }

        final place = placemarks.first;
        return '${place.street}, ${place.locality}, ${place.country}';
      }().timeout(Timeouts.location);

      if (!mounted) return;

      setState(() {
        _address = address;
        _addressController.text = address;
      });

      showAppSnack(
        context,
        'Location added successfully',
        kind: SnackKind.success,
      );
    } on TimeoutException {
      if (!mounted) return;
      showAppSnack(
        context,
        'Could not get your location in time. Please type the address yourself.',
        kind: SnackKind.error,
      );
    } catch (e, st) {
      if (!mounted) return;
      showAppSnack(
        context,
        friendlyError(
          e,
          fallback: 'Could not get your location. Please try again.',
          stackTrace: st,
        ),
        kind: SnackKind.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isGettingLocation = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    final path = widget.recoveredPhotoPath;
    if (path != null && path.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showAppSnack(context, 'Your photo was recovered.');
        _uploadAttachmentFile(XFile(path));
      });
    }
  }

  Future<void> _uploadAttachment() async {
    final picked = await pickImageWithChoice(context, purpose: 'ticket');
    if (!mounted) return;
    if (picked == null) {
      showAppSnack(context, 'No photo selected');
      return;
    }
    await _uploadAttachmentFile(picked);
  }

  Future<void> _uploadAttachmentFile(XFile picked) async {
    // Only images and PDF up to 5 MB are uploaded.
    try {
      final bytes = await picked.length();
      final name = picked.name.isNotEmpty ? picked.name : picked.path;
      if (!isAcceptableAttachment(fileName: name, bytes: bytes)) {
        if (!mounted) return;
        showAppSnack(
          context,
          'Please choose an image or PDF under 5 MB.',
          kind: SnackKind.error,
        );
        return;
      }
    } catch (_) {
      if (!mounted) return;
      showAppSnack(
        context,
        'Please choose an image or PDF under 5 MB.',
        kind: SnackKind.error,
      );
      return;
    }
    if (!mounted) return;

    setState(() => _isUploadingAttachment = true);

    try {
      final url = await CloudinaryService().uploadFromPath(picked.path);
      if (!mounted) return;

      setState(() {
        _attachmentUrl = url;
        _attachmentFileName = url.split('/').last;
      });

      showAppSnack(
        context,
        'Attachment uploaded successfully',
        kind: SnackKind.success,
      );
    } catch (e, st) {
      if (!mounted) return;
      showAppSnack(
        context,
        friendlyError(
          e,
          fallback: 'Could not upload the file. Please try again.',
          stackTrace: st,
        ),
        kind: SnackKind.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingAttachment = false);
      }
    }
  }

  void _removeAttachment() {
    setState(() {
      _attachmentUrl = null;
      _attachmentFileName = null;
    });
  }

  Future<void> _extractDetails() async {
    if (_aiInputController.text.trim().isEmpty) {
      showAppSnack(context, 'Please describe your issue first');
      return;
    }

    setState(() => _isExtracting = true);
    _slowHint.start(() {
      if (mounted) setState(() => _showSlowHint = true);
    });

    try {
      final result = await _aiExtractionService.extractTicketDetails(
        _aiInputController.text.trim(),
      );

      // Edge case — irrelevant or gibberish input
      if (result['isRelevant'] == 'false') {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => const InvalidInputDialog(),
        );
        return;
      }

      // Valid input — fill the form
      setState(() {
        _selectedCategory = result['category'];
        _titleController.text = result['title'] ?? '';
        _descriptionController.text = result['description'] ?? '';

        if (result['address'] != null && result['address']!.isNotEmpty) {
          _addressController.text = result['address']!;
          _address = result['address'];
        }
        final aiArea = result['area'];
        if (aiArea != null && ServiceAreas.all.contains(aiArea)) {
          _selectedArea = aiArea;
        }
      });

      showAppSnack(
        context,
        'Details extracted! Please review and complete the form.',
        kind: SnackKind.success,
      );
    } catch (e, st) {
      // Timeout or any failure: the form stays usable, so the customer can
      // choose the category themselves. The raw error is only logged.
      friendlyError(e, stackTrace: st);
      if (!mounted) return;
      showAppSnack(
        context,
        'Could not get an AI suggestion. You can choose the category yourself.',
        kind: SnackKind.error,
      );
    } finally {
      _slowHint.stop();
      if (mounted) {
        setState(() {
          _isExtracting = false;
          _showSlowHint = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _aiInputController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _slowHint.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submit Ticket')),
      body: SafeArea(
        // The bottom inset is added to the scroll padding below.
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.s4,
            AppSpacing.s4,
            AppSpacing.s4,
            MediaQuery.paddingOf(context).bottom + AppSpacing.s6,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildModeToggle(),
                const SizedBox(height: AppSpacing.s4),
                if (_isAiMode) ...[
                  _buildAiInputSection(),
                  const SizedBox(height: AppSpacing.s4),
                ],
                SectionCard(
                  title: 'Issue Details',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildPickerField(
                        label: 'Issue Category',
                        hint: 'Select a category',
                        icon: Icons.category_outlined,
                        options: _categories,
                        value: _selectedCategory,
                        iconBuilder: _categoryIcon,
                        errorMessage: 'Please select a category',
                        onSaved: () => _category = _selectedCategory,
                        onChanged: (value) {
                          setState(() => _selectedCategory = value);
                        },
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      AppTextField(
                        label: 'Ticket Title',
                        hint: 'Enter Your Ticket Title',
                        prefixIcon: Icons.title_outlined,
                        controller: _titleController,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                        onSaved: (val) => _title = val?.trim(),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      AppTextField(
                        label: 'Description',
                        hint: 'e.g. My Internet has been down since morning..',
                        prefixIcon: Icons.notes_outlined,
                        controller: _descriptionController,
                        maxLines: 4,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please describe the issue';
                          }
                          return null;
                        },
                        onSaved: (val) => _description = val?.trim(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                SectionCard(
                  title: 'Location',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        label: 'Service Address',
                        hint:
                            'e.g. No.5 Jalan Bayu Indah 5 Taman Bayu Cemerlang...',
                        prefixIcon: Icons.location_on_outlined,
                        controller: _addressController,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter an address';
                          }
                          return null;
                        },
                        onSaved: (val) => _address = val?.trim(),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      _buildPickerField(
                        label: 'Area',
                        hint: 'Select an area',
                        icon: Icons.map_outlined,
                        options: ServiceAreas.all,
                        value: _selectedArea,
                        errorMessage: 'Please select an area',
                        onSaved: () => _area = _selectedArea,
                        onChanged: (val) => setState(() => _selectedArea = val),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      OutlinedButton.icon(
                        onPressed: _isGettingLocation
                            ? null
                            : _getCurrentLocation,
                        icon: _isGettingLocation
                            ? const _ButtonSpinner(color: AppColors.primary)
                            : const Icon(Icons.my_location),
                        label: Text(
                          _isGettingLocation
                              ? 'Getting Location...'
                              : 'Use Current Location',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                SectionCard(
                  title: 'Additional Info',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        label: 'Contact Number',
                        hint: '0123456789',
                        prefixIcon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter a contact number';
                          }
                          if (val.trim().length < 10) {
                            return 'Please enter a valid contact number';
                          }
                          return null;
                        },
                        onSaved: (val) => _contactNumber = val?.trim(),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      _buildAttachment(),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s2),
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitForm,
                    child: _isSubmitting
                        ? const _ButtonSpinner(color: AppColors.onPrimary)
                        : const Text('Submit Ticket'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const List<String> _categories = [
    'Network',
    'Hardware',
    'Software',
    'Other',
  ];

  static IconData? _categoryIcon(String category) {
    switch (category) {
      case 'Network':
        return Icons.wifi;
      case 'Software':
        return Icons.apps;
      case 'Hardware':
        return Icons.memory;
      case 'Other':
        return Icons.more_horiz;
    }
    return null;
  }

  /// A picker field that behaves like the dropdown it replaces: the chosen
  /// value lives in the screen's state, it is validated and saved with the
  /// form, and the same message shows under it when nothing is chosen.
  Widget _buildPickerField({
    required String label,
    required String hint,
    required IconData icon,
    required List<String> options,
    required String? value,
    required String errorMessage,
    required VoidCallback onSaved,
    required ValueChanged<String?> onChanged,
    IconData? Function(String option)? iconBuilder,
  }) {
    return FormField<String>(
      validator: (_) => value == null ? errorMessage : null,
      onSaved: (_) => onSaved(),
      builder: (state) {
        return AppPickerField(
          label: label,
          value: value,
          hint: hint,
          prefixIcon: icon,
          errorText: state.errorText,
          onTap: () async {
            final picked = await showPickerSheet<String>(
              context,
              title: label,
              options: options,
              selected: value,
              iconBuilder: iconBuilder,
            );
            if (picked == null) return;
            onChanged(picked);
            state.didChange(picked);
          },
        );
      },
    );
  }

  Widget _buildAttachment() {
    final hasFile = _attachmentUrl != null;
    final borderColor = hasFile ? AppColors.resolvedFg : AppColors.borderStrong;
    final accent = _isUploadingAttachment
        ? AppColors.primary
        : hasFile
        ? AppColors.resolvedFg
        : AppColors.primary;
    final isPdf = _attachmentFileName?.toLowerCase().endsWith('.pdf') ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Attachment',
          style: AppText.caption.copyWith(color: AppColors.inkMuted),
        ),
        const SizedBox(height: AppSpacing.s1),
        Material(
          color: AppColors.surfaceCard,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.brMd,
            side: BorderSide(color: borderColor, width: 1.5),
          ),
          child: InkWell(
            onTap: _isUploadingAttachment ? null : _uploadAttachment,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 88),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isUploadingAttachment
                          ? Icons.hourglass_top_rounded
                          : hasFile
                          ? Icons.check_circle_outline
                          : Icons.cloud_upload_outlined,
                      color: accent,
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      _isUploadingAttachment
                          ? 'Uploading attachment...'
                          : _attachmentFileName ??
                                'Tap to upload image or file',
                      style: AppText.bodyStrong.copyWith(
                        color: hasFile ? AppColors.resolvedFg : AppColors.ink,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (hasFile) ...[
          const SizedBox(height: AppSpacing.s3),
          isPdf
              ? Container(
                  padding: const EdgeInsets.all(AppSpacing.s4),
                  decoration: BoxDecoration(
                    color: AppColors.cancelledBg,
                    borderRadius: AppRadius.brMd,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.picture_as_pdf,
                        color: AppColors.cancelledFg,
                      ),
                      const SizedBox(width: AppSpacing.s3),
                      Expanded(
                        child: Text(
                          _attachmentFileName ?? 'PDF File',
                          style: AppText.bodyStrong.copyWith(
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Container(
                  height: 180,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.brMd,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Image.network(
                    _attachmentUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) {
                        return child;
                      }

                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(
                          Icons.broken_image,
                          color: AppColors.inkFaint,
                        ),
                      );
                    },
                  ),
                ),
          const SizedBox(height: AppSpacing.s2),
          Row(
            children: [
              TextButton.icon(
                onPressed: _isUploadingAttachment ? null : _uploadAttachment,
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Replace'),
              ),
              const Spacer(),
              IconButton(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                tooltip: 'Remove',
                color: AppColors.cancelledFg,
                icon: const Icon(Icons.delete_outline),
                onPressed: _isUploadingAttachment ? null : _removeAttachment,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildModeToggle() {
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: AppColors.borderStrong, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.brMd,
        child: Row(
          children: [
            Expanded(
              child: _ModeSegment(
                icon: Icons.edit_note_rounded,
                label: 'Fill Form',
                selected: !_isAiMode,
                onTap: () => setState(() => _isAiMode = false),
              ),
            ),
            Expanded(
              child: _ModeSegment(
                icon: Icons.chat_bubble_outline,
                label: 'Auto Fill',
                selected: _isAiMode,
                onTap: () => setState(() => _isAiMode = true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiInputSection() {
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
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.primaryTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chat_bubble_outline,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: Text(
                  'Describe Your Issue',
                  style: AppText.heading.copyWith(color: AppColors.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s1),
          Text(
            'Tell us what happened in your own words. AI will extract the details for you.',
            style: AppText.body.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.s3),
          AppTextField(
            label: '',
            controller: _aiInputController,
            maxLines: 5,
            hint:
                'e.g. My internet has been down since morning, I\'m at Puchong...',
          ),
          const SizedBox(height: AppSpacing.s3),
          OutlinedButton.icon(
            onPressed: _isExtracting ? null : _extractDetails,
            icon: _isExtracting
                ? const _ButtonSpinner(color: AppColors.primary)
                : const Icon(Icons.fact_check_outlined),
            label: Text(_isExtracting ? 'Extracting...' : 'Extract Details'),
          ),
          if (_isExtracting && _showSlowHint) const SlowHintText(),
        ],
      ),
    );
  }
}

/// One half of the Fill Form / AI Mode toggle.
class _ModeSegment extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeSegment({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.onPrimary : AppColors.inkMuted;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.primary : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s2,
                vertical: AppSpacing.s3,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: AppSpacing.s2),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: (selected ? AppText.bodyStrong : AppText.body)
                          .copyWith(color: color),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 20px progress ring shown inside a button while its action runs.
class _ButtonSpinner extends StatelessWidget {
  final Color color;

  const _ButtonSpinner({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2, color: color),
    );
  }
}

/// Shown when the AI says the description is not about a service issue.
class InvalidInputDialog extends StatelessWidget {
  const InvalidInputDialog({super.key});

  static const List<String> _examples = [
    '"My internet is not working since this morning"',
    '"The WiFi router keeps disconnecting"',
    '"My TV box shows no signal"',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.brLg),
      contentPadding: const EdgeInsets.all(AppSpacing.s6),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.s6,
        0,
        AppSpacing.s6,
        AppSpacing.s6,
      ),
      // The button stays pinned below the scrolling message on short screens.
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Try Again'),
          ),
        ),
      ],
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.primaryTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.info_outline,
                size: 28,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            'Invalid Input',
            textAlign: TextAlign.center,
            style: AppText.title.copyWith(color: AppColors.ink),
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            'Your description doesn\'t seem to be related to a service issue. '
            'Please describe your actual problem, for example:',
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.s3),
          for (final example in _examples) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.s3),
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: AppRadius.brMd,
              ),
              child: Text(
                example,
                style: AppText.body.copyWith(color: AppColors.ink),
              ),
            ),
            if (example != _examples.last)
              const SizedBox(height: AppSpacing.s2),
          ],
        ],
      ),
    );
  }
}
