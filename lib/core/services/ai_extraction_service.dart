import 'package:google_generative_ai/google_generative_ai.dart';
import '../../config/app_constants.dart';
import '../constants/service_areas.dart';
import '../../utils/gemini_retry.dart';
import '../config/timeouts.dart';
import '../../utils/phone_clean.dart';

class AiExtractionService {
  late final GenerativeModel _model;

  AiExtractionService() {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: AppConstants.geminiApiKey,
      generationConfig: GenerationConfig(temperature: 0.2),
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
- category: must be exactly one of "Network", "Hardware", "Software", "Other", using these definitions:
    * Network: no internet, red light or LOS, slow or unstable internet, frequent disconnections, wifi coverage or weak wifi signal.
    * Hardware: modem, ONU, router or TV box not powering on, dead or damaged devices, damaged cables, ports or connectors, loose or broken parts.
    * Software: TV or IPTV problems (no signal on the TV box, channels not loading), home phone or voice problems (no dial tone, cannot make or receive calls), websites not opening or DNS problems, login, password or PPPoE problems, service or VLAN configuration.
    * Other: relevant service requests that are not a technical fault, such as billing or account enquiries, new installation or relocation, package changes, or general questions.
- title: a short, clear summary of the issue (max 10 words)
- description: a clean version of the customer's description in English, keeping the customer's own words for symptoms and devices
- address: the location mentioned by the customer, or empty string if not mentioned
- area: must be exactly one of these values: ${ServiceAreas.all.map((a) => '"$a"').join(', ')}. Pick the closest match to the location mentioned. Use "Other" if the location is unclear or not in the list.
- phone: the customer's phone number, ONLY if the customer wrote one in their message. If no phone number is written, return an empty string. Never guess, never invent, and never copy a number from anywhere else.
  * Do not return other numbers as a phone number, such as account numbers, ticket IDs, house or lot numbers, port numbers, VLAN IDs, speeds (for example 300Mbps), dates or times.
  * Malaysian numbers look like 012-345 6789, 0123456789, 03-1234 5678, +60 12-345 6789 or 6012 3456789. Return it exactly as the customer wrote it.

Category rules:
- TV, home phone, website or DNS, and account or configuration problems are Software, even if the customer says "no signal" or "not working".
- Use Network only for connectivity or line problems affecting the internet itself.
- Prefer Network, Hardware or Software whenever the complaint is a technical fault. Use Other only as a last resort.
- If the ticket mentions more than one issue, choose the category of the main complaint.

Language rules:
- The customer may write in English or Malay. Always write title and description in English.
- In the description, keep the customer's own key terms for devices and services unchanged (for example "TV box", "home phone", "website", "wifi", "router", "ONU", "VLAN"). Do not replace them with generic words.
- Keep the customer's own words for the symptom (for example 'internet is down', 'red light', 'slow', 'keeps disconnecting'). Do not replace them with different wording.

Customer input:
"$userInput"

Respond ONLY with a valid JSON object. No explanation, no markdown, no extra text.
Format (this is only a template; never copy any text from it, and use only what the customer wrote):
{
  "isRelevant": "true or false",
  "category": "one of Network, Hardware, Software, Other",
  "title": "short summary in English, max 10 words",
  "description": "the customer's description in English, keeping their own key words",
  "address": "location mentioned, or empty string",
  "area": "one value from the area list above",
  "phone": "phone number written by the customer, or empty string"
}
''';

    try {
      final content = [Content.text(prompt)];
      // One retry after 2 s on 503 / 429 / network errors; never on a timeout.
      final response = await withGeminiRetry(
        () => _model.generateContent(content).timeout(Timeouts.aiSuggestion),
        label: 'suggestion',
      );
      return parseExtraction(response.text ?? '');
    } catch (e) {
      throw Exception('AI extraction failed: $e');
    }
  }

  /// Reads the AI's answer (code fences are removed first). Every key is
  /// always present; a missing value is an empty string. `phone` is cleaned
  /// by [cleanExtractedPhone] and is empty unless it is a valid number.
  static Map<String, String> parseExtraction(String responseText) {
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
      'area': parsed['area']?.toString() ?? '',
      'phone': cleanExtractedPhone(parsed['phone']?.toString()),
    };
  }

  static Map<String, dynamic> _parseJson(String text) {
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
      'area': _extractField(jsonString, 'area'),
      'phone': _extractField(jsonString, 'phone'),
    };
  }

  static String _extractField(String json, String field) {
    final pattern = RegExp('"$field"\\s*:\\s*"(.*?)"', dotAll: true);
    final match = pattern.firstMatch(json);
    return match?.group(1)?.trim() ?? '';
  }
}
