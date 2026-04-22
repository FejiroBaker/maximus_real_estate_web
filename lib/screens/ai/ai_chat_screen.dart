// lib/screens/ai/ai_chat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/gemini_service.dart';
import '../../models/property_model.dart';

class AiChatScreen extends StatefulWidget {
  /// Pass the current property if opened from a property details page.
  final PropertyModel? property;

  const AiChatScreen({super.key, this.property});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final GeminiService _gemini = GeminiService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;

  // Conversation history in Gemini format
  final List<Map<String, String>> _history = [];

  String? get _propertyContext {
    final p = widget.property;
    if (p == null) return null;
    return 'Title: ${p.title} | Price: ₦${p.price.toStringAsFixed(0)} | '
        'Type: ${p.propertyType} | Bedrooms: ${p.bedrooms} | '
        'Bathrooms: ${p.bathrooms} | Area: ${p.area.toInt()} sqft | '
        'Location: ${p.location.fullAddress} | '
        'Listing type: ${p.listingType} | Status: ${p.status} | '
        'Inspection fee: ₦${p.inspectionFee.toStringAsFixed(0)}';
  }

  @override
  void initState() {
    super.initState();
    // Greeting message
    final greeting = widget.property != null
        ? 'Hi! I\'m Maximus AI. I can see you\'re viewing **${widget.property!.title}**. '
            'Ask me anything about this property, the neighbourhood, pricing, or the buying process!'
        : 'Hi! I\'m Maximus AI, your real estate assistant. '
            'I can help you find properties, understand the Nigerian property market, '
            'explain legal terms, and guide you through buying or selling. How can I help?';

    _messages.add(_ChatMessage(text: greeting, isUser: false));

    // Suggested questions
    _messages.add(const _ChatMessage(
      text: '__suggestions__',
      isUser: false,
    ));
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<String> get _suggestions {
    if (widget.property != null) {
      return [
        'Is this a good price?',
        'What is the buying process?',
        'How do I book an inspection?',
        'What should I check before buying?',
      ];
    }
    return [
      'Best areas to buy in Lagos?',
      'What is a Certificate of Occupancy?',
      'How does property inspection work?',
      'What are typical agent fees?',
    ];
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userText = text.trim();
    _inputController.clear();

    setState(() {
      _messages.removeWhere((m) => m.text == '__suggestions__');
      _messages.add(_ChatMessage(text: userText, isUser: true));
      _isLoading = true;
    });

    _scrollToBottom();

    // Add to history BEFORE calling API
    _history.add({'role': 'user', 'content': userText});

    final reply = await _gemini.chat(
      history: List.from(_history),
      userMessage: userText,
      propertyContext: _propertyContext,
    );

    // Add model reply to history
    _history.add({'role': 'model', 'content': reply});

    if (mounted) {
      setState(() {
        _isLoading = false;
        _messages.add(_ChatMessage(text: reply, isUser: false));
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Maximus AI',
                style: TextStyle(fontWeight: FontWeight.bold)),
            if (widget.property != null)
              Text(
                widget.property!.title,
                style: const TextStyle(fontSize: 11, color: Colors.white70),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear chat',
            onPressed: () {
              setState(() {
                _history.clear();
                _messages
                  ..clear()
                  ..add(_ChatMessage(
                    text: 'Chat cleared. How can I help you?',
                    isUser: false,
                  ));
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Property context banner
          if (widget.property != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.blue.shade50,
              child: Row(children: [
                Icon(Icons.home, size: 16, color: Colors.blue.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Context: ${widget.property!.title}',
                    style: TextStyle(
                        fontSize: 12, color: Colors.blue.shade700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ),

          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return const _TypingIndicator();
                }
                final msg = _messages[index];
                if (msg.text == '__suggestions__') {
                  return _SuggestionsRow(
                    suggestions: _suggestions,
                    onTap: _sendMessage,
                  );
                }
                return _MessageBubble(message: msg);
              },
            ),
          ),

          // Input bar
          _InputBar(
            controller: _inputController,
            focusNode: _focusNode,
            isLoading: _isLoading,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

// ── Message bubble ─────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: EdgeInsets.only(
        bottom: 12,
        left: isUser ? 60 : 0,
        right: isUser ? 0 : 60,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF1565C0),
              child: const Icon(Icons.auto_awesome,
                  size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: message.text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Copied to clipboard'),
                      duration: Duration(seconds: 1)),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isUser
                      ? const Color(0xFF1565C0)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isUser ? 16 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 16),
                  ),
                ),
                child: _buildText(message.text, isUser),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  // Render **bold** markdown inline
  Widget _buildText(String text, bool isUser) {
    final baseStyle = TextStyle(
      color: isUser ? Colors.white : Colors.black87,
      fontSize: 14,
      height: 1.5,
    );

    final boldStyle = baseStyle.copyWith(fontWeight: FontWeight.bold);
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.*?)\*\*');
    int last = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(
            text: text.substring(last, match.start), style: baseStyle));
      }
      spans.add(TextSpan(text: match.group(1), style: boldStyle));
      last = match.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: baseStyle));
    }

    return RichText(text: TextSpan(children: spans));
  }
}

// ── Typing indicator ──────────────────────────────────────────────────────────
class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 60),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF1565C0),
            child: const Icon(Icons.auto_awesome,
                size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(delay: 0),
                SizedBox(width: 4),
                _Dot(delay: 200),
                SizedBox(width: 4),
                _Dot(delay: 400),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _anim,
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
              color: Colors.grey, shape: BoxShape.circle),
        ),
      );
}

// ── Suggestion chips ──────────────────────────────────────────────────────────
class _SuggestionsRow extends StatelessWidget {
  final List<String> suggestions;
  final void Function(String) onTap;
  const _SuggestionsRow(
      {required this.suggestions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: suggestions
            .map((s) => GestureDetector(
                  onTap: () => onTap(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(s,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade700)),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final void Function(String) onSend;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -3)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.send,
              maxLines: 4,
              minLines: 1,
              onSubmitted: isLoading ? null : onSend,
              decoration: InputDecoration(
                hintText: 'Ask Maximus AI anything...',
                hintStyle:
                    const TextStyle(color: Colors.grey, fontSize: 14),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isLoading
                  ? Colors.grey.shade300
                  : const Color(0xFF1565C0),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send, color: Colors.white),
              onPressed: isLoading
                  ? null
                  : () => onSend(controller.text),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────
class _ChatMessage {
  final String text;
  final bool isUser;
  const _ChatMessage({required this.text, required this.isUser});
}