import 'package:google_generative_ai/google_generative_ai.dart';
import '../../config/app_constants.dart';

class AiExtractionService {
  late final GenerativeModel _model;

  AiExtractionService() {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: AppConstants.geminiApiKey,
    );
  }

  Future<Map<String, String>> extractTicketDetails(String userInput) async {
    final prompt =
        '''
You are an AI assistant for a telecommunications company called TM (Telekom Malaysia).
A customer has described their issue in natural language.

First, determine if the input is a relevant technical or service complaint (network, hardware, software, billing, location, or general service issues).
If the input is random words, gibberish, or completely unrelated to any service issue, set isRelevant to "false" and leave all other fields empty.

Your job is to extract the following fields:
- isRelevant: "true" if the input is a valid issue description, "false" if it is gibberish or irrelevant
- category: must be exactly one of these values: "Network", "Hardware", "Software", "Other"
- title: a short, clear summary of the issue (max 10 words)
- description: a clean, professional version of the customer's description
- address: the location mentioned by the customer, or empty string if not mentioned

Customer input:
"$userInput"

Respond ONLY with a valid JSON object. No explanation, no markdown, no extra text.
Example format:
{
  "isRelevant": "true",
  "category": "Network",
  "title": "Internet Connection Down",
  "description": "Customer reports that their internet connection has been down since morning.",
  "address": "Puchong, Selangor"
}
''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final responseText = response.text ?? '';

      final cleaned = responseText
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final Map<String, dynamic> parsed = _parseJson(cleaned);

      return {
        'isRelevant': parsed['isRelevant']?.toString() ?? 'true',
        'category': parsed['category']?.toString() ?? '',
        'title': parsed['title']?.toString() ?? '',
        'description': parsed['description']?.toString() ?? '',
        'address': parsed['address']?.toString() ?? '',
      };
    } catch (e) {
      throw Exception('AI extraction failed: $e');
    }
  }

  Map<String, dynamic> _parseJson(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');

    if (start == -1 || end == -1) {
      throw Exception('No valid JSON found in response');
    }

    final jsonString = text.substring(start, end + 1);

    return {
      'isRelevant': _extractField(jsonString, 'isRelevant'),
      'category': _extractField(jsonString, 'category'),
      'title': _extractField(jsonString, 'title'),
      'description': _extractField(jsonString, 'description'),
      'address': _extractField(jsonString, 'address'),
    };
  }

  String _extractField(String json, String field) {
    final pattern = RegExp('"$field"\\s*:\\s*"(.*?)"', dotAll: true);
    final match = pattern.firstMatch(json);
    return match?.group(1)?.trim() ?? '';
  }
}
