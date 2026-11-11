import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import '../../utils/friendly_error.dart';
import '../config/timeouts.dart';

/// The secure URL from a Cloudinary upload response. A status other than 200
/// or 201, or a body without a usable https URL, gives a [FriendlyException]
/// (never the raw status or body).
String parseUploadResponse(int statusCode, String body) {
  const failure = FriendlyException(
    'Could not upload the file. Please try again.',
  );
  if (statusCode != 200 && statusCode != 201) throw failure;
  try {
    final json = jsonDecode(body);
    final url = json is Map ? json['secure_url'] : null;
    if (url is String && url.startsWith('https://')) return url;
  } catch (_) {}
  throw failure;
}

class CloudinaryService {
  static const String cloudName = 'dhhkuoadu';
  static const String uploadPreset = 'tmassist_unsigned_upload';

  Future<String> uploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result == null || result.files.single.path == null) {
      throw Exception('No file selected');
    }

    return uploadFromPath(result.files.single.path!);
  }

  /// Uploads the file at [filePath] (for example from the camera or gallery).
  /// Gives up after [Timeouts.fileUpload].
  Future<String> uploadFromPath(String filePath) {
    return _upload(filePath).timeout(Timeouts.fileUpload);
  }

  Future<String> _upload(String filePath) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/auto/upload'),
    );

    request.fields['upload_preset'] = uploadPreset;
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    final response = await request.send();
    final body = await response.stream.bytesToString();
    return parseUploadResponse(response.statusCode, body);
  }
}
