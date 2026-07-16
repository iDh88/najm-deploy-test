import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../admin/knowledge_center/models/knowledge_models.dart';
import '../admin/knowledge_center/providers/knowledge_providers.dart';
import '../admin/knowledge_center/widgets/knowledge_widgets.dart';

/// "Ask Operations AI" — crew-facing chat that answers trade, legality,
/// fatigue, scheduling, and policy questions using ONLY the knowledge base.
/// Documents are never visible here — only answers + citations.
class AskOperationsScreen extends ConsumerStatefulWidget {
  const AskOperationsScreen({super.key});

  @override
  ConsumerState<AskOperationsScreen> createState() =>
      _AskOperationsScreenState();
}

class _AskOperationsScreenState extends ConsumerState<AskOperationsScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  DocumentCategory? _categoryFilter;

  static const _suggestions = [
    'What is the minimum rest after an international flight?',
    'How does carry-over affect my next month\'s schedule?',
    'What are the rules for trading an open day?',
    'How is fatigue calculated for early sign-ins?',
  ];

  Future<void> _send([String? text]) async {
    final query = (text ?? _inputCtrl.text).trim();
    if (query.isEmpty) return;
    _inputCtrl.clear();
    await ref.read(askChatProvider.notifier)
        .send(query, category: _categoryFilter);
    await Future.delayed(const Duration(milliseconds: 100));
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(askChatProvider);

    return Scaffold(
      backgroundColor: CIPTheme.surface,
      appBar: AppBar(
        backgroundColor: CIPTheme.surface,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🤖', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            const Text('Ask Operations AI',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (chat.messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: ref.read(askChatProvider.notifier).clear,
            ),
        ],
      ),
      body: Column(
        children: [
          // Category filter
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: CategoryFilterBar(
              selected: _categoryFilter,
              onChanged: (c) => setState(() => _categoryFilter = c),
            ),
          ),

          // Chat area
          Expanded(
            child: chat.messages.isEmpty
                ? _SuggestionsView(onTap: _send)
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: chat.messages.length + (chat.isLoading ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i >= chat.messages.length) {
                        return const _TypingIndicator();
                      }
                      return _MessageBubble(message: chat.messages[i]);
                    },
                  ),
          ),

          // Input bar
          _InputBar(controller: _inputCtrl, onSend: _send,
              isLoading: chat.isLoading),
        ],
      ),
    );
  }
}

// ── Suggestions (empty state) ───────────────────────────────────────────────

class _SuggestionsView extends StatelessWidget {
  final ValueChanged<String> onTap;
  const _SuggestionsView({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 20),
        const Center(child: Text('🤖', style: TextStyle(fontSize: 56))),
        const SizedBox(height: 16),
        const Text(
          'Ask anything about scheduling, trades,\nlegality, fatigue, or company policy.',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: CIPTheme.textPrimary,
              fontSize: 15, fontWeight: FontWeight.w600, height: 1.5),
        ),
        const SizedBox(height: 28),
        const Text('Try asking',
            style: TextStyle(
                color: CIPTheme.textMuted, fontSize: 11,
                fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 10),
        ..._AskOperationsScreenState._suggestions.map((s) => GestureDetector(
          onTap: () => onTap(s),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: CIPTheme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CIPTheme.divider),
            ),
            child: Row(children: [
              const Icon(Icons.chat_bubble_outline,
                  color: CIPTheme.primary, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(s,
                    style: const TextStyle(
                        color: CIPTheme.textSecondary, fontSize: 13)),
              ),
            ]),
          ),
        )),
      ],
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 60),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: CIPTheme.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(message.text,
              style: const TextStyle(color: Colors.white, fontSize: 13)),
        ),
      ).animate().fadeIn(duration: 200.ms).slideX(begin: 0.05, end: 0);
    }

    final answer = message.answer;
    final confColor = answer?.confidence == 'HIGH'
        ? CIPTheme.success
        : (answer?.confidence == 'MEDIUM' ? CIPTheme.warning : CIPTheme.textMuted);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 30),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CIPTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CIPTheme.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text('🤖', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              const Text('Najm AI',
                  style: TextStyle(
                      color: CIPTheme.primary, fontSize: 11,
                      fontWeight: FontWeight.w700)),
              if (answer != null) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: confColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(answer.confidence,
                      style: TextStyle(
                          color: confColor, fontSize: 8,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ]),
            const SizedBox(height: 8),
            Text(message.text,
                style: const TextStyle(
                    color: CIPTheme.textPrimary, fontSize: 13, height: 1.6)),

            if (answer != null && answer.citations.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: CIPTheme.divider),
              const SizedBox(height: 8),
              const Text('Sources',
                  style: TextStyle(
                      color: CIPTheme.textMuted, fontSize: 9,
                      fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              const SizedBox(height: 6),
              SizedBox(
                height: 28,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: answer.citations
                      .map((c) => CitationCard(citation: c))
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.05, end: 0);
  }
}

// ── Typing indicator ───────────────────────────────────────────────────────────

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 30),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: CIPTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CIPTheme.divider),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: CIPTheme.primary)),
          SizedBox(width: 10),
          Text('Searching knowledge base…',
              style: TextStyle(color: CIPTheme.textMuted, fontSize: 12)),
        ]),
      ),
    );
  }
}

// ── Input bar ──────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String?> onSend;
  final bool isLoading;

  const _InputBar({
    required this.controller, required this.onSend, required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 10, 12, 10 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: CIPTheme.surface,
        border: Border(top: BorderSide(color: CIPTheme.divider)),
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: controller,
            style: const TextStyle(color: CIPTheme.textPrimary, fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Ask about trades, legality, fatigue…',
              isDense: true,
            ),
            onSubmitted: (_) => onSend(null),
            textInputAction: TextInputAction.send,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: isLoading ? null : () => onSend(null),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: isLoading ? CIPTheme.textMuted : CIPTheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.send, color: Colors.white, size: 18),
          ),
        ),
      ]),
    );
  }
}
