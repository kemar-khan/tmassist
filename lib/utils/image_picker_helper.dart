import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

enum _PickChoice { camera, gallery, pdf }

/// Shows a bottom sheet so the user can take a photo or choose from the
/// gallery, and returns the picked file, or null if they cancelled.
///
/// A third option keeps PDF attachments working (the old picker allowed
/// jpg, jpeg, png and pdf). Errors, such as a denied camera permission, are
/// shown in a snackbar and null is returned, so callers never crash.
Future<XFile?> pickImageWithChoice(BuildContext context) async {
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

    return await ImagePicker().pickImage(
      source: choice == _PickChoice.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
    );
  } catch (e) {
    if (context.mounted) {
      // Only blame the permission when the plugin says so; otherwise show the
      // real error (a generic message hid a missing-plugin error before).
      final deniedCamera =
          e is PlatformException && e.code == 'camera_access_denied';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deniedCamera
                ? 'Camera permission is denied. Allow it in the app settings and try again.'
                : 'Could not pick the file: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
    return null;
  }
}
