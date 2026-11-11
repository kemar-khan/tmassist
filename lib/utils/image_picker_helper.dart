import 'dart:io' show Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pending_photo.dart';
import 'friendly_error.dart';

const _pendingKey = 'pending_photo';

enum _PickChoice { camera, gallery, pdf }

/// Shows a bottom sheet so the user can take a photo or choose from the
/// gallery, and returns the picked file, or null if they cancelled.
///
/// A third option keeps PDF attachments working (the old picker allowed
/// jpg, jpeg, png and pdf). Errors, such as a denied camera permission, are
/// shown in a snackbar and null is returned, so callers never crash.
///
/// [purpose] ('report' or 'ticket', plus [ticketId] for a report) is stored
/// locally while the camera or gallery is open, so [recoverLostPhoto] can
/// match a photo to its screen if Android kills the app in the meantime.
Future<XFile?> pickImageWithChoice(
  BuildContext context, {
  required String purpose,
  String? ticketId,
}) async {
  final choice = await showModalBottomSheet<_PickChoice>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take photo'),
            onTap: () => Navigator.pop(sheetContext, _PickChoice.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(sheetContext, _PickChoice.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('Choose PDF'),
            onTap: () => Navigator.pop(sheetContext, _PickChoice.pdf),
          ),
        ],
      ),
    ),
  );

  if (choice == null) return null;

  try {
    if (choice == _PickChoice.pdf) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      final path = result?.files.single.path;
      return path == null ? null : XFile(path);
    }

    await _savePending(purpose, ticketId);
    try {
      return await ImagePicker().pickImage(
        source: choice == _PickChoice.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
        maxHeight: 1600,
        requestFullMetadata: false,
      );
    } finally {
      // Reached only when the app was NOT killed: a file or a cancel.
      await _clearPending();
    }
  } catch (e, st) {
    if (context.mounted) {
      // Only blame the permission when the plugin says so; otherwise a
      // friendly message (the raw error is printed in debug builds only).
      final deniedCamera =
          e is PlatformException && e.code == 'camera_access_denied';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deniedCamera
                ? 'Camera permission is denied. Allow it in the app settings and try again.'
                : friendlyError(
                    e,
                    fallback: 'Could not pick the file. Please try again.',
                    stackTrace: st,
                  ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
    return null;
  }
}

Future<void> _savePending(String purpose, String? ticketId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _pendingKey,
      PendingPhoto(
        purpose: purpose,
        ticketId: ticketId,
        timestamp: DateTime.now(),
      ).encode(),
    );
  } catch (_) {}
}

Future<void> _clearPending() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingKey);
  } catch (_) {}
}

bool _recoveryChecked = false;

/// Android only. After the app was killed while the camera was open, returns
/// the photo that the system kept, with the stored note of what it was for.
/// Runs once per app start; returns null when nothing was lost, the note is
/// missing or older than 30 minutes, or anything fails. The note is always
/// cleared afterwards.
Future<RecoveredPhoto?> recoverLostPhoto() async {
  if (_recoveryChecked) return null;
  _recoveryChecked = true;
  try {
    if (!Platform.isAndroid) return null;
    final prefs = await SharedPreferences.getInstance();
    final pending = PendingPhoto.tryParse(prefs.getString(_pendingKey));
    await prefs.remove(_pendingKey);

    final response = await ImagePicker().retrieveLostData();
    if (response.isEmpty || response.exception != null) return null;
    final path = response.file?.path ?? '';
    if (path.isEmpty) return null;
    if (pending == null || !pending.isFresh(DateTime.now())) return null;

    return RecoveredPhoto(
      path: path,
      purpose: pending.purpose,
      ticketId: pending.ticketId,
    );
  } catch (_) {
    return null;
  }
}
