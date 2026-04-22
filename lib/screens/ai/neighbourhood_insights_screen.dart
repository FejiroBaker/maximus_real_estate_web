// lib/screens/ai/neighbourhood_insights_screen.dart
import 'package:flutter/material.dart';
import '../../services/gemini_service.dart';
import '../../models/property_model.dart';

class NeighbourhoodInsightsScreen extends StatefulWidget {
  final PropertyModel property;
  const NeighbourhoodInsightsScreen({super.key, required this.property});

  @override
  State<NeighbourhoodInsightsScreen> createState() =>
      _NeighbourhoodInsightsScreenState();
}

class _NeighbourhoodInsightsScreenState
    extends State<NeighbourhoodInsightsScreen> {
  final GeminiService _gemini = GeminiService();
  String? _insights;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final result = await _gemini.getNeighbourhoodInsights(
      city: widget.property.location.city,
      state: widget.property.location.state,
      address: widget.property.location.address,
    );

    if (mounted) {
      setState(() {
        _insights = result;
        _isLoading = false;
        _hasError = result.contains('Unable to load') ||
            result.contains('check your internet');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Neighbourhood Insights'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInsights,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Location header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF2196F3)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.location_on, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.property.location.fullAddress,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(
                  '${widget.property.location.city}, ${widget.property.location.state}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                          style:
                              TextStyle(color: Colors.white, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const _LoadingState()
                : _hasError
                    ? _ErrorState(onRetry: _loadInsights)
                    : _InsightsContent(insights: _insights!),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            'Analysing neighbourhood...',
            style: TextStyle(
                color: Colors.grey.shade600, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            'Gemini AI is gathering insights',
            style: TextStyle(
                color: Colors.grey.shade400, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('Could not load insights',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Check your internet connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightsContent extends StatelessWidget {
  final String insights;
  const _InsightsContent({required this.insights});

  // Parse the numbered sections out of the AI text
  List<_Section> _parseSections(String text) {
    final sections = <_Section>[];
    final lines = text.split('\n');
    String? currentTitle;
    final bodyLines = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Detect numbered headers like "1. **Safety & Security**" or "1. Safety"
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
        currentTitle = headerMatch.group(2)!
            .replaceAll('**', '')
            .trim();
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
    final sections = _parseSections(insights);

    // If parsing failed, show raw text
    if (sections.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(insights,
            style: const TextStyle(fontSize: 15, height: 1.6)),
      );
    }

    final icons = [
      Icons.shield_outlined,
      Icons.construction,
      Icons.storefront,
      Icons.directions_bus,
      Icons.trending_up,
    ];
    final colors = [
      Colors.green,
      Colors.orange,
      Colors.blue,
      Colors.purple,
      Colors.teal,
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sections.length + 1, // +1 for disclaimer
      itemBuilder: (context, index) {
        if (index == sections.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline,
                    color: Colors.amber, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI-generated insights. Always verify with local agents '
                    'and conduct your own due diligence.',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
              ]),
            ),
          );
        }

        final section = sections[index];
        final icon = index < icons.length ? icons[index] : Icons.info;
        final color = index < colors.length ? colors[index] : Colors.grey;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.title,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        section.body,
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                            height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Section {
  final String title;
  final String body;
  const _Section({required this.title, required this.body});
}