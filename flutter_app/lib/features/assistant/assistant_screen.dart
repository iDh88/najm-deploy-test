import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:uuid/uuid.dart';

import '../../app/theme.dart';
import '../../core/services/connectivity_service.dart';
import '../../shared/widgets/offline_widgets.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/models/models.dart';
import '../../core/services/ai_service.dart';
import '../../shared/widgets/skeleton_loader.dart';

// ─── Assistant State ──────────────────────────────────────────────────────────

class AssistantState {
  final List<AIMessage> messages;
  final bool isLoading;
  final bool isListening;
  final String? error;

  const AssistantState({
    this.messages = const [],
    this.isLoading = false,
    this.isListening = false,
    this.error,
  });

  AssistantState copyWith({
    List<AIMessage>? messages, bool? isLoading, bool? isListening, String? error
  }) => AssistantState(
    messages: messages ?? this.messages,
    isLoading: isLoading ?? this.isLoading,
    isListening: isListening ?? this.isListening,
    error: error,
  );
}

class AssistantNotifier extends StateNotifier<AssistantState> {
  final AIService _aiService;
  final String _userId;
  final _uuid = const Uuid();

  AssistantNotifier({required AIService aiService, required String userId})
      : _aiService = aiService,
        _userId = userId,
        super(const AssistantState());

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    final userMessage = AIMessage(
      id: _uuid.v4(),
      role: 'user',
      content: content,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
      error: null,
    );

    try {
      final response = await _aiService.chat(
        userId: _userId,
        message: content,
        history: state.messages,
      );

      final assistantMessage = AIMessage(
        id: _uuid.v4(),
        role: 'assistant',
        content: response.text,
        intentType: response.intentType,
        timestamp: DateTime.now(),
        responseTimeMs: response.responseTimeMs,
        lineCard: response.lineCard,
        legalityCard: response.legalityCard,
      );

      state = state.copyWith(
        messages: [...state.messages, assistantMessage],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void setListening(bool listening) {
    state = state.copyWith(isListening: listening);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final assistantProvider = StateNotifierProvider<AssistantNotifier, AssistantState>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  final aiService = ref.watch(aiServiceProvider);
  return AssistantNotifier(aiService: aiService, userId: user?.id ?? '');
});

// ─── Assistant Screen ─────────────────────────────────────────────────────────

class AssistantScreen extends ConsumerStatefulWidget {
  final String? initialQuery;
  const AssistantScreen({super.key, this.initialQuery});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _speechToText = SpeechToText();
  bool _speechAvailable = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    if (widget.initialQuery != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(assistantProvider.notifier).sendMessage(widget.initialQuery!);
      });
    }
  }

  void _initSpeech() async {
    _speechAvailable = await _speechToText.initialize();
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    ref.read(assistantProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  void _toggleListening() async {
    final notifier = ref.read(assistantProvider.notifier);
    if (_speechToText.isListening) {
      await _speechToText.stop();
      notifier.setListening(false);
    } else {
      notifier.setListening(true);
      await _speechToText.listen(
        onResult: (result) {
          _controller.text = result.recognizedWords;
          if (result.finalResult) {
            notifier.setListening(false);
            _send();
          }
        },
        localeId: 'ar_SA',
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final assistantState = ref.watch(assistantProvider);

    ref.listen(assistantProvider, (_, next) {
      if (next.messages.length != assistantState.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: CIPTheme.grey50,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: CIPTheme.saudiGold,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(child: Text('⭐', style: TextStyle(fontSize: 16))),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Najm', style: TextStyle(fontSize: 16, fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                Text('AI Assistant', style: TextStyle(fontSize: 11, color: CIPTheme.grey500)),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: assistantState.messages.isEmpty
                ? _WelcomeView(onSuggestionTap: (q) {
                    _controller.text = q;
                    _send();
                  })
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: assistantState.messages.length +
                        (assistantState.isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == assistantState.messages.length) {
                        return const _TypingIndicator();
                      }
                      final msg = assistantState.messages[index];
                      return msg.role == 'user'
                          ? _UserBubble(message: msg)
                          : _AssistantBubble(message: msg);
                    },
                  ),
          ),

          // Error banner
          if (assistantState.error != null)
            Container(
              color: CIPTheme.violationRedBg,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: CIPTheme.violationRed, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(assistantState.error!, style: const TextStyle(fontSize: 12))),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => ref.read(assistantProvider.notifier).clearError(),
                  ),
                ],
              ),
            ),

          // Input area
          _InputBar(
            controller: _controller,
            isListening: assistantState.isListening,
            isLoading: assistantState.isLoading,
            speechAvailable: _speechAvailable,
            onSend: _send,
            onMicTap: _toggleListening,
          ),
        ],
      ),
    );
  }
}

// ─── Welcome View ─────────────────────────────────────────────────────────────
class _WelcomeView extends StatelessWidget {
  final ValueChanged<String> onSuggestionTap;
  const _WelcomeView({required this.onSuggestionTap});

  static const suggestions = [
    ('🔍', 'Show lines with London layovers', 'Show lines with London layovers'),
    ('💰', 'Which line has the highest salary?', 'Which line has the highest salary?'),
    ('😴', 'Lines with no flights on Fridays', 'Lines with no flights on Fridays'),
    ('⚖️', 'Compare Line 411 vs Line 208', 'Compare Line 411 vs Line 208'),
    ('⚠️', 'Is Line 317 legal for me?', 'Is Line 317 legal for me?'),
    ('📊', 'How many hours will I have this month?', 'How many hours will I have this month?'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          const Text('⭐', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          const Text('Hi, I am Najm', style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Inter'
          )),
          const Text("I'm your intelligent crew scheduling assistant",
            style: TextStyle(color: CIPTheme.grey500, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          const Align(
            alignment: Alignment.centerRight,
            child: Text('Try asking:', style: TextStyle(
              fontWeight: FontWeight.w600, color: CIPTheme.grey700, fontSize: 13
            )),
          ),
          const SizedBox(height: 12),
          ...suggestions.map((s) => _SuggestionChip(
            emoji: s.$1, en: s.$2, ar: s.$3, onTap: () => onSuggestionTap(s.$2),
          )),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String emoji, en, ar;
  final VoidCallback onTap;
  const _SuggestionChip({required this.emoji, required this.en, required this.ar, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: CIPTheme.grey200),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ar, style: const TextStyle(fontSize: 13, fontFamily: 'Inter')),
                  Text(en, style: const TextStyle(fontSize: 12, color: CIPTheme.grey500)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: CIPTheme.grey300, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─── Message Bubbles ──────────────────────────────────────────────────────────
class _UserBubble extends StatelessWidget {
  final AIMessage message;
  const _UserBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 48),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: CIPTheme.saudiNavy,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16), topRight: Radius.circular(16),
              bottomRight: Radius.circular(16), bottomLeft: Radius.circular(4),
            ),
          ),
          child: Text(
            message.content,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  final AIMessage message;
  const _AssistantBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: CIPTheme.saudiGold,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Center(child: Text('⭐', style: TextStyle(fontSize: 14))),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4), topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16), bottomLeft: Radius.circular(16),
                    ),
                    border: Border.all(color: CIPTheme.grey200),
                  ),
                  child: Text(message.content, style: const TextStyle(fontSize: 14, height: 1.5)),
                ),
              ),
            ],
          ),
          // Rich content cards
          if (message.lineCard != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 36),
              child: _LineRichCard(line: message.lineCard!),
            ),
          if (message.legalityCard != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 36),
              child: _LegalityRichCard(result: message.legalityCard!),
            ),
        ],
      ),
    );
  }
}

class _LineRichCard extends StatelessWidget {
  final FlightLine line;
  const _LineRichCard({required this.line});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CIPTheme.saudiNavy.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CIPTheme.saudiNavy.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.flight, color: CIPTheme.saudiNavy, size: 20),
          const SizedBox(width: 8),
          Text('Line ${line.lineNumber}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: CIPTheme.saudiNavy)),
          const SizedBox(width: 8),
          Text('${line.summary.totalLegs} legs · ${line.summary.estimatedSalaryMin.toStringAsFixed(0)} SAR',
            style: const TextStyle(fontSize: 12, color: CIPTheme.grey700)),
        ],
      ),
    );
  }
}

class _LegalityRichCard extends StatelessWidget {
  final LegalityResult result;
  const _LegalityRichCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: result.passed ? CIPTheme.legalGreenBg : CIPTheme.violationRedBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: result.passed ? CIPTheme.legalGreen : CIPTheme.violationRed,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            result.passed ? Icons.check_circle : Icons.cancel,
            color: result.passed ? CIPTheme.legalGreen : CIPTheme.violationRed,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            result.passed ? 'Legally compliant ✓' : '${result.violations.length} violation(s) found',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: result.passed ? CIPTheme.legalGreen : CIPTheme.violationRed,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: CIPTheme.saudiGold,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Center(child: Text('⭐', style: TextStyle(fontSize: 14))),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CIPTheme.grey200),
            ),
            child: const SkeletonLoader(width: 80, height: 12),
          ),
        ],
      ),
    );
  }
}

// ─── Input Bar ────────────────────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isListening, isLoading, speechAvailable;
  final VoidCallback onSend, onMicTap;

  const _InputBar({
    required this.controller, required this.isListening, required this.isLoading,
    required this.speechAvailable, required this.onSend, required this.onMicTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: CIPTheme.grey200)),
      ),
      child: Row(
        children: [
          if (speechAvailable)
            GestureDetector(
              onTap: onMicTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: isListening ? CIPTheme.violationRed : CIPTheme.grey100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isListening ? Icons.stop : Icons.mic_outlined,
                  color: isListening ? Colors.white : CIPTheme.grey700,
                  size: 20,
                ),
              ),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              textAlign: TextAlign.right,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'Ask Najm...',
                hintStyle: const TextStyle(fontSize: 13, color: CIPTheme.grey500),
                filled: true,
                fillColor: CIPTheme.grey100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isLoading ? null : onSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: isLoading ? CIPTheme.grey300 : CIPTheme.saudiNavy,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isLoading ? Icons.hourglass_empty : Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
