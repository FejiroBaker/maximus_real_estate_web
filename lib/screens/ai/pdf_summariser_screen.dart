// lib/screens/ai/pdf_summariser_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/gemini_service.dart';

class PdfSummariserScreen extends StatefulWidget {
  const PdfSummariserScreen({super.key});

  @override
  State<PdfSummariserScreen> createState() => _PdfSummariserScreenState();
}

class _PdfSummariserScreenState extends State<PdfSummariserScreen> {
  final GeminiService _gemini = GeminiService();

  File? _selectedFile;
  String? _fileName;
  String? _summary;
  bool _isLoading = false;
  bool _hasError = false;

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result == null || result.files.isEmpty) return;

    final path = result.files.single.path;
    if (path == null) return;

    setState(() {
      _selectedFile = File(path);
      _fileName = result.files.single.name;
      _summary = null;
      _hasError = false;
    });
  }

  Future<void> _summarise() async {
    if (_selectedFile == null) return;

    // Check file size (Gemini supports up to ~20MB inline)
    final sizeBytes = await _selectedFile!.length();
    if (sizeBytes > 20 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('File too large. Maximum size is 20MB.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
      _summary = null;
    });

    final result = await _gemini.summarisePdfDocument(_selectedFile!);

    if (mounted) {
      setState(() {
        _isLoading = false;
        _summary = result;
        _hasError = result.contains('Could not read') ||
            result.contains('Failed to process');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Analyser'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF2196F3)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.description, color: Colors.white, size: 28),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('AI Property Document Analyser',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  const Text(
                    'Upload a Certificate of Occupancy, Survey Plan, Deed of Assignment, '
                    'or any property document. Gemini AI will extract the key details.',
                    style:
                        TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome,
                            color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text('Powered by Gemini AI',
                            style: TextStyle(
                                color: Colors.white, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Supported formats
            const Text('Supported document types:',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                'Certificate of Occupancy',
                'Survey Plan',
                'Deed of Assignment',
                'Property Purchase Agreement',
                'Building Plan',
                'FMBN Offer Letter',
              ]
                  .map((t) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.blue.shade100),
                        ),
                        child: Text(t,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700)),
                      ))
                  .toList(),
            ),

            const SizedBox(height: 24),

            // File picker area
            GestureDetector(
              onTap: _pickPdf,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _selectedFile != null
                      ? Colors.green.shade50
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _selectedFile != null
                        ? Colors.green
                        : Colors.grey.shade300,
                    width: _selectedFile != null ? 2 : 1,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _selectedFile != null
                          ? Icons.check_circle
                          : Icons.upload_file,
                      size: 48,
                      color: _selectedFile != null
                          ? Colors.green
                          : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _selectedFile != null
                          ? _fileName ?? 'Document selected'
                          : 'Tap to select PDF document',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _selectedFile != null
                            ? Colors.green.shade700
                            : Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_selectedFile != null) ...[
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: _pickPdf,
                        child: const Text('Change file'),
                      ),
                    ] else ...[
                      const SizedBox(height: 4),
                      Text(
                        'PDF files only • Max 20MB',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade400),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Analyse button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    _selectedFile == null || _isLoading ? null : _summarise,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.document_scanner),
                label: Text(
                  _isLoading
                      ? 'Analysing document...'
                      : 'Analyse Document with AI',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF1565C0),
                ),
              ),
            ),

            // Loading state
            if (_isLoading) ...[
              const SizedBox(height: 24),
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Gemini AI is reading your document...',
                        style: TextStyle(color: Colors.grey)),
                    SizedBox(height: 4),
                    Text('This may take 15–30 seconds',
                        style:
                            TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ],

            // Error state
            if (_hasError && _summary != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_summary!,
                        style: const TextStyle(color: Colors.red)),
                  ),
                ]),
              ),
            ],

            // Summary result
            if (_summary != null && !_hasError) ...[
              const SizedBox(height: 24),
              _SummaryResult(summary: _summary!, fileName: _fileName ?? ''),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── Summary result widget ─────────────────────────────────────────────────────
class _SummaryResult extends StatelessWidget {
  final String summary;
  final String fileName;
  const _SummaryResult({required this.summary, required this.fileName});

  List<_Section> _parseSections(String text) {
    final sections = <_Section>[];
    final lines = text.split('\n');
    String? currentTitle;
    final bodyLines = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final headerMatch =
          RegExp(r'^(\d)\.\s+\*?\*?(.+?)\*?\*?$').firstMatch(trimmed);
      if (headerMatch != null) {
        if (currentTitle != null) {
          sections.add(_Section(
            title: currentTitle,
            body: bodyLines.join(' ').trim(),
          ));
          bodyLines.clear();
        }
        currentTitle =
            headerMatch.group(2)!.replaceAll('**', '').trim();
      } else if (currentTitle != null) {
        bodyLines.add(trimmed.replaceAll('**', ''));
      }
    }

    if (currentTitle != null && bodyLines.isNotEmpty) {
      sections.add(_Section(
        title: currentTitle,
        body: bodyLines.join(' ').trim(),
      ));
    }

    return sections;
  }

  @override
  Widget build(BuildContext context) {
    final sections = _parseSections(summary);

    final icons = [
      Icons.article_outlined,
      Icons.location_on_outlined,
      Icons.person_outline,
      Icons.square_foot,
      Icons.tag,
      Icons.calendar_today,
      Icons.warning_amber_outlined,
      Icons.verified_outlined,
    ];
    final colors = [
      Colors.blue,
      Colors.teal,
      Colors.purple,
      Colors.orange,
      Colors.indigo,
      Colors.grey,
      Colors.red,
      Colors.green,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Result header
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Document analysed successfully',
                      style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold)),
                  Text(fileName,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ]),
        ),

        const SizedBox(height: 16),

        if (sections.isEmpty)
          // Fallback: show raw text
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(summary,
                style: const TextStyle(fontSize: 14, height: 1.6)),
          )
        else
          ...List.generate(sections.length, (i) {
            final section = sections[i];
            final icon = i < icons.length ? icons[i] : Icons.info;
            final color = i < colors.length ? colors[i] : Colors.grey;
            // Flag section (index 6 = red flags) gets special styling
            final isRedFlag = i == 6;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isRedFlag
                    ? Colors.red.shade50
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isRedFlag
                      ? Colors.red.shade200
                      : Colors.grey.shade200,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(section.title,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isRedFlag
                                    ? Colors.red.shade700
                                    : Colors.black87)),
                        const SizedBox(height: 4),
                        Text(section.body,
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                                height: 1.5)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

        // Legal disclaimer
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.gavel, color: Colors.amber, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'For informational purposes only. This is not legal advice. '
                  'Always consult a qualified solicitor before any property transaction.',
                  style:
                      TextStyle(fontSize: 12, color: Colors.black87, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Section {
  final String title;
  final String body;
  const _Section({required this.title, required this.body});
}