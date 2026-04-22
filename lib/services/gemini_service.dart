// lib/services/gemini_service.dart
// Central AI service — all four AI features route through here.
// Model: gemini-2.0-flash (fast, cheap, multimodal).
//
// 🔐 API key is loaded from .env via AppConfig.geminiApiKey — never hardcoded.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class GeminiService {
  // Key is read once per instance from AppConfig (which reads .env at startup).
  // It is NOT stored as a static const — that would bake it into the binary.
  String get _apiKey => AppConfig.geminiApiKey;

  static const String _modelId = 'gemini-2.0-flash';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  // ── Shared POST helper ────────────────────────────────────────────────────
  Future<String?> _generate(List<Map<String, dynamic>> contents,
      {String? systemInstruction}) async {
    try {
      final body = <String, dynamic>{
        'contents': contents,
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 1024,
        },
      };
      if (systemInstruction != null) {
        body['systemInstruction'] = {
          'parts': [
            {'text': systemInstruction}
          ]
        };
      }

      final response = await http
          .post(
            Uri.parse('$_baseUrl/$_modelId:generateContent?key=$_apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        if (kDebugMode) {
          print('Gemini error ${response.statusCode}: ${response.body}');
        }
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;
      final parts = candidates[0]['content']['parts'] as List?;
      if (parts == null || parts.isEmpty) return null;
      return parts[0]['text'] as String?;
    } catch (e) {
      if (kDebugMode) print('GeminiService error: $e');
      return null;
    }
  }

  // ── 1. Neighbourhood Insights ─────────────────────────────────────────────
  Future<String> getNeighbourhoodInsights({
    required String city,
    required String state,
    required String address,
  }) async {
    final prompt =
        'You are a Nigerian real estate expert. Give a concise, '
        'practical neighbourhood analysis for: $address, $city, $state, Nigeria. '
        'Cover: (1) Safety & security, (2) Infrastructure (roads, power, water), '
        '(3) Nearby amenities (schools, hospitals, markets, banks), '
        '(4) Transport & commute, (5) Price trend (rising/stable/falling). '
        'Keep each point to 1–2 sentences. Be factual and helpful. '
        'Format as 5 numbered sections with bold headers.';

    final result = await _generate([
      {
        'role': 'user',
        'parts': [
          {'text': prompt}
        ]
      }
    ]);

    return result ??
        'Unable to load neighbourhood insights at this time. '
            'Please check your internet connection and try again.';
  }

  // ── 2. Lead Scoring for Sellers ──────────────────────────────────────────
  Future<Map<String, dynamic>> scoreLead({
    required String buyerName,
    required String buyerEmail,
    required String buyerPhone,
    required String propertyTitle,
    required double propertyPrice,
    required String bookingStatus,
    required String paymentStatus,
    required DateTime inspectionDate,
    required bool hasUnlockedContact,
    required int savedPropertiesCount,
  }) async {
    final prompt = '''
You are a real estate lead-scoring AI. Score this buyer lead from 0–100 
and give 2–3 sentences of advice for the seller.

Property: $propertyTitle (₦${propertyPrice.toStringAsFixed(0)})
Buyer: $buyerName | $buyerEmail | Phone: $buyerPhone
Inspection booked: ${inspectionDate.toLocal().toString().substring(0, 10)}
Booking status: $bookingStatus
Payment status: $paymentStatus  
Has unlocked seller contact: ${hasUnlockedContact ? 'YES' : 'NO'}
Saved properties in app: $savedPropertiesCount

Scoring criteria (total 100 pts):
- Payment made (paid inspection or unlock): +40 pts
- Booking confirmed or completed: +20 pts
- Contact unlocked: +15 pts
- Has phone number: +10 pts
- Active in app (saved many properties): +15 pts

Reply ONLY with valid JSON, no markdown:
{"score": <int 0-100>, "label": "<Hot|Warm|Cold>", "advice": "<2-3 sentences>"}
''';

    final result = await _generate([
      {
        'role': 'user',
        'parts': [
          {'text': prompt}
        ]
      }
    ]);

    if (result == null) {
      return {'score': 0, 'label': 'Unknown', 'advice': 'Could not score lead.'};
    }

    try {
      final clean = result.replaceAll(RegExp(r'```json|```'), '').trim();
      return jsonDecode(clean) as Map<String, dynamic>;
    } catch (_) {
      return {'score': 50, 'label': 'Warm', 'advice': result};
    }
  }

  // ── 3. PDF Document Summariser ────────────────────────────────────────────
  Future<String> summarisePdfDocument(File pdfFile) async {
    try {
      final bytes = await pdfFile.readAsBytes();
      final base64Data = base64Encode(bytes);

      final contents = [
        {
          'role': 'user',
          'parts': [
            {
              'inline_data': {
                'mime_type': 'application/pdf',
                'data': base64Data,
              }
            },
            {
              'text':
                  'You are a Nigerian real estate legal assistant. '
                  'Analyse this property document and extract: '
                  '(1) Document type (C of O, Survey Plan, Deed of Assignment, etc.), '
                  '(2) Property address/location, '
                  '(3) Owner name(s), '
                  '(4) Plot/land size, '
                  '(5) Title number or reference, '
                  '(6) Key dates (issue date, expiry if any), '
                  '(7) Any encumbrances, restrictions or red flags, '
                  '(8) Overall assessment (Looks clean / Needs verification / Red flag). '
                  'If the document is not a property document, say so clearly. '
                  'Format as 8 numbered sections with bold headers. '
                  'This is for informational purposes only, not legal advice.'
            }
          ]
        }
      ];

      final result = await _generate(contents);
      return result ??
          'Could not read the document. Make sure it is a valid PDF and try again.';
    } catch (e) {
      if (kDebugMode) print('PDF summarise error: $e');
      return 'Failed to process document: $e';
    }
  }

  // ── 4. AI Chatbot (multi-turn) ────────────────────────────────────────────
  Future<String> chat({
    required List<Map<String, String>> history,
    required String userMessage,
    String? propertyContext,
  }) async {
    const system =
        'You are Maximus AI, a friendly real estate assistant for Maximus Real Estate Nigeria. '
        'You help buyers find properties, answer questions about the Nigerian property market, '
        'explain legal terms, guide sellers, and assist with inspections and payments. '
        'Keep answers concise (3–5 sentences max unless a list is needed). '
        'Always be professional and use Nigerian context (₦ for currency, Lagos/Abuja/PH etc). '
        'If asked something outside real estate, politely redirect to property topics.';

    final contents = <Map<String, dynamic>>[];

    if (propertyContext != null && propertyContext.isNotEmpty) {
      contents.add({
        'role': 'user',
        'parts': [
          {
            'text':
                '[Context about the property currently being viewed: $propertyContext]'
          }
        ]
      });
      contents.add({
        'role': 'model',
        'parts': [
          {'text': 'Understood. I have the property details. How can I help?'}
        ]
      });
    }

    for (final msg in history) {
      contents.add({
        'role': msg['role'] == 'user' ? 'user' : 'model',
        'parts': [
          {'text': msg['content']!}
        ]
      });
    }

    contents.add({
      'role': 'user',
      'parts': [
        {'text': userMessage}
      ]
    });

    final result = await _generate(contents, systemInstruction: system);
    return result ??
        'Sorry, I could not process your request right now. Please try again.';
  }
}