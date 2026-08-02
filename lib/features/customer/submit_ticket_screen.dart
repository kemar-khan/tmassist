import 'package:flutter/material.dart';
import '../../core/services/ticket_service.dart';
import '../../core/services/cloudinary_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../core/services/ai_extraction_service.dart';

class SubmitTicketScreen extends StatefulWidget {
  const SubmitTicketScreen({super.key});

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
  final TextEditingController _aiInputController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  final AiExtractionService _aiExtractionService = AiExtractionService();
  String? _selectedCategory;

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _ticketService.createTicket(
        category: _category!,
        title: _title!,
        description: _description!,
        address: _address!,
        contactNumber: _contactNumber!,
        attachmentUrl: _attachmentUrl, // add file upload later
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ticket submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit ticket: $e'),
          backgroundColor: Colors.red,
        ),
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
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      Placemark place = placemarks[0];

      final address = '${place.street}, ${place.locality}, ${place.country}';

      setState(() {
        _address = address;
        _addressController.text = address;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to get location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGettingLocation = false);
      }
    }
  }

  Future<void> _uploadAttachment() async {
    setState(() => _isUploadingAttachment = true);

    try {
      final url = await CloudinaryService().uploadFile();

      setState(() {
        _attachmentUrl = url;
        _attachmentFileName = url.split('/').last;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attachment uploaded successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingAttachment = false);
      }
    }
  }

  Future<void> _extractDetails() async {
    if (_aiInputController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please describe your issue first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isExtracting = true);

    try {
      final result = await _aiExtractionService.extractTicketDetails(
        _aiInputController.text.trim(),
      );

      setState(() {
        _selectedCategory = result['category'];
        _titleController.text = result['title'] ?? '';
        _descriptionController.text = result['description'] ?? '';

        if (result['address'] != null && result['address']!.isNotEmpty) {
          _addressController.text = result['address']!;
          _address = result['address'];
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Details extracted! Please review and complete the form.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Extraction failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _aiInputController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Submit Ticket',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF005CAB),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildModeToggle(),
              const SizedBox(height: 16),
              if (_isAiMode) _buildAiInputSection(),
              _buildSectionTitle('Issue Details'),
              _buildCard(
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: _inputDecoration(
                        'Issue Category',
                        Icons.category_outlined,
                      ),
                      value: _selectedCategory,
                      items: ['Network', 'Hardware', 'Software', 'Other']
                          .map(
                            (e) => DropdownMenuItem<String>(
                              value: e,
                              child: Text(e),
                            ),
                          )
                          .toList(),
                      validator: (val) =>
                          val == null ? 'Please select a category' : null,
                      onSaved: (val) => _category = val,
                      onChanged: (String? value) {
                        setState(() => _selectedCategory = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      decoration: _inputDecoration(
                        'Ticket Title',
                        Icons.title_outlined,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                      onSaved: (val) => _title = val?.trim(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: _inputDecoration(
                        'Description',
                        Icons.description_outlined,
                      ),
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
              const SizedBox(height: 24),

              _buildSectionTitle('Location'),
              _buildCard(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _addressController,
                      decoration: _inputDecoration(
                        'Service Address',
                        Icons.location_on_outlined,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter an address';
                        }
                        return null;
                      },
                      onSaved: (val) => _address = val?.trim(),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _isGettingLocation
                          ? null
                          : _getCurrentLocation,
                      icon: _isGettingLocation
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.my_location,
                              color: Color(0xFF005CAB),
                            ),
                      label: Text(
                        _isGettingLocation
                            ? 'Getting Location...'
                            : 'Use Current Location',
                        style: const TextStyle(
                          color: Color(0xFF005CAB),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFF005CAB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              _buildSectionTitle('Additional Info'),
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      decoration: _inputDecoration(
                        'Contact Number',
                        Icons.phone_outlined,
                      ),
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
                    const SizedBox(height: 16),
                    const Text(
                      'Attachment',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _isUploadingAttachment ? null : _uploadAttachment,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          border: Border.all(
                            color: _attachmentUrl == null
                                ? Colors.grey[300]!
                                : Colors.green,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _isUploadingAttachment
                                  ? Icons.hourglass_top_rounded
                                  : _attachmentUrl == null
                                  ? Icons.cloud_upload_outlined
                                  : Icons.check_circle_outline,
                              size: 32,
                              color: _isUploadingAttachment
                                  ? Colors.orange
                                  : _attachmentUrl == null
                                  ? Colors.grey[400]
                                  : Colors.green,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isUploadingAttachment
                                  ? 'Uploading attachment...'
                                  : _attachmentFileName ??
                                        'Tap to upload image or file',
                              style: TextStyle(
                                color: _attachmentUrl == null
                                    ? Colors.grey[500]
                                    : Colors.green,
                                fontWeight: _attachmentUrl == null
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (_attachmentUrl != null) ...[
                      const SizedBox(height: 12),

                      (_attachmentFileName?.toLowerCase().endsWith('.pdf') ??
                              false)
                          ? Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.picture_as_pdf,
                                    color: Colors.red,
                                    size: 40,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _attachmentFileName ?? 'PDF File',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Container(
                              width: double.infinity,
                              height: 180,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Image.network(
                                _attachmentUrl!,
                                fit: BoxFit.cover,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) {
                                        return child;
                                      }

                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    },
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(Icons.broken_image, size: 50),
                                  );
                                },
                              ),
                            ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6600),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit Ticket',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF333333),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey[600]),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF005CAB), width: 2),
      ),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isAiMode = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: !_isAiMode
                      ? const Color(0xFF005CAB)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.edit_note_rounded,
                      color: !_isAiMode ? Colors.white : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Fill Form',
                      style: TextStyle(
                        color: !_isAiMode ? Colors.white : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isAiMode = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _isAiMode
                      ? const Color(0xFF005CAB)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: _isAiMode ? Colors.white : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AI Mode',
                      style: TextStyle(
                        color: _isAiMode ? Colors.white : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFF005CAB),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Describe Your Issue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Tell us what happened in your own words. AI will extract the details for you.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _aiInputController,
                maxLines: 5,
                decoration: _inputDecoration(
                  'e.g. My internet has been down since morning, I\'m at Puchong...',
                  Icons.chat_bubble_outline,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isExtracting ? null : _extractDetails,
                  icon: _isExtracting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome, color: Colors.white),
                  label: Text(
                    _isExtracting ? 'Extracting...' : 'Extract Details',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF005CAB),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
