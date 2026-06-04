import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

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

    final file = File(result.files.single.path!);

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/auto/upload'),
    );

    request.fields['upload_preset'] = uploadPreset;

    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await request.send();

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Upload failed');
    }

    final responseData = await response.stream.bytesToString();
    final jsonData = jsonDecode(responseData);

    return jsonData['secure_url'];
  }
}
