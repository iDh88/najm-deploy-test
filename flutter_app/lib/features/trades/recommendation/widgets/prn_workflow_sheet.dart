import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../app/theme.dart';
import '../models.dart';
import '../trade_recommendation_service.dart';

class PRNWorkflowSheet extends ConsumerStatefulWidget {
  final TradeMatch match;
  final String tradeId;
  final String userId;

  const PRNWorkflowSheet({
    super.key,
    required this.match,
    required this.tradeId,
    required this.userId,
  });

  @override
  ConsumerState<PRNWorkflowSheet> createState() => _PRNWorkflowSheetState();
}

class _PRNWorkflowSheetState extends ConsumerState<PRNWorkflowSheet> {
  final _svc           = TradeRecommendationService();
  final _phoneCtrl     = TextEditingController();
  PRNContactStatus _status = PRNContactStatus.pending;
  bool _phoneLookedUp  = false;
  bool _saving         = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _openOutlook() async {
    final url = Uri.parse(
        'https://outlook.office.com/contacts/search?q=${widget.match.prn}');
    if (await canLaunchUrl(url)) launchUrl(url);
  }

  Future<void> _openWhatsApp() async {
    final phone = _phoneCtrl.text.trim().replaceAll(RegExp(r'\D'), '');
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paste the phone number first')),
      );
      return;
    }
    final msg = Uri.encodeComponent(
        'Hello, I found your line through Najm. '
        'I would like to discuss a trade — '
        'PRN: ${widget.match.prn}. Please let me know if you are interested.');
    final url = Uri.parse('https://wa.me/$phone?text=$msg');
    if (await canLaunchUrl(url)) launchUrl(url);
    await _saveStatus(PRNContactStatus.sent);
  }

  Future<void> _saveStatus(PRNContactStatus status) async {
    setState(() { _saving = true; _status = status; });
    await _svc.updatePRNStatus(
      userId:  widget.userId,
      tradeId: widget.tradeId,
      prn:     widget.match.prn,
      status:  status,
    );
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize:     0.5,
      maxChildSize:     0.95,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: CIPTheme.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Contact via PRN',
                          style: TextStyle(
                              color: CIPTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      Text('PRN: ${widget.match.prn}  ·  ${widget.match.compatibilityLabel} match',
                          style: const TextStyle(
                              color: CIPTheme.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                // Status indicator
                _StatusBadge(status: _status),
              ],
            ),
          ),

          const Divider(height: 1, color: CIPTheme.divider),

          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.all(20),
              children: [
                // ── Step 1 ─────────────────────────────────────────────────
                _Step(
                  number: '1',
                  title:  'Copy the PRN',
                  child: Row(children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: CIPTheme.navLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: CIPTheme.divider),
                        ),
                        child: Text(
                          widget.match.prn,
                          style: const TextStyle(
                              color: CIPTheme.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _CopyButton(text: widget.match.prn),
                  ]),
                ),
                const SizedBox(height: 20),

                // ── Step 2 ─────────────────────────────────────────────────
                _Step(
                  number: '2',
                  title:  'Search in Outlook to get their phone',
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _openOutlook,
                          icon: const Text('📧',
                              style: TextStyle(fontSize: 16)),
                          label: const Text('Open Outlook Contact Search'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: CIPTheme.primary,
                            side: BorderSide(
                                color: CIPTheme.primary.withOpacity(0.5)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Search for PRN ${0} in the Outlook directory to find the crew member\'s phone number.',
                        style: TextStyle(
                            color: CIPTheme.textMuted,
                            fontSize: 11, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Step 3 ─────────────────────────────────────────────────
                _Step(
                  number: '3',
                  title:  'Paste phone number',
                  child: TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(
                        color: CIPTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: '+966 5X XXX XXXX',
                      prefixIcon: const Text('📱',
                          style: TextStyle(fontSize: 18)),
                      prefixIconConstraints: const BoxConstraints(
                          minWidth: 44, minHeight: 44),
                      suffixIcon: GestureDetector(
                        onTap: () async {
                          final data = await Clipboard.getData('text/plain');
                          if (data?.text != null) {
                            _phoneCtrl.text = data!.text!;
                            setState(() => _phoneLookedUp = true);
                          }
                        },
                        child: const Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: Text('Paste',
                              style: TextStyle(
                                  color: CIPTheme.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                    onChanged: (_) => setState(() => _phoneLookedUp = true),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Step 4 ─────────────────────────────────────────────────
                _Step(
                  number: '4',
                  title:  'Send WhatsApp message',
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _phoneLookedUp ? _openWhatsApp : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Text('💬',
                              style: TextStyle(fontSize: 18)),
                          label: const Text('Open WhatsApp',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'A pre-written trade message will open in WhatsApp. '
                        'Edit as needed before sending.',
                        style: TextStyle(
                            color: CIPTheme.textMuted,
                            fontSize: 11, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Status buttons ────────────────────────────────────────
                const Text('Update status',
                    style: TextStyle(
                        color: CIPTheme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: _StatusBtn(
                      label:  '✅ Sent',
                      active: _status == PRNContactStatus.sent,
                      color:  CIPTheme.success,
                      onTap:  () => _saveStatus(PRNContactStatus.sent),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatusBtn(
                      label:  '⏳ Pending',
                      active: _status == PRNContactStatus.pending,
                      color:  CIPTheme.warning,
                      onTap:  () => _saveStatus(PRNContactStatus.pending),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatusBtn(
                      label:  '❌ Failed',
                      active: _status == PRNContactStatus.failed,
                      color:  CIPTheme.error,
                      onTap:  () => _saveStatus(PRNContactStatus.failed),
                    ),
                  ),
                ]),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String number, title;
  final Widget child;
  const _Step({required this.number, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
                color: CIPTheme.primary,
                shape: BoxShape.circle),
            child: Center(
              child: Text(number,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  color: CIPTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
        ]),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(left: 30),
          child: child,
        ),
      ],
    );
  }
}

class _CopyButton extends StatefulWidget {
  final String text;
  const _CopyButton({required this.text});
  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: widget.text));
        setState(() => _copied = true);
        Future.delayed(const Duration(seconds: 2),
            () { if (mounted) setState(() => _copied = false); });
      },
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: _copied
              ? CIPTheme.success.withOpacity(0.12)
              : CIPTheme.primary.withOpacity(0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: _copied ? CIPTheme.success : CIPTheme.primary),
        ),
        child: Icon(
          _copied ? Icons.check : Icons.copy,
          color: _copied ? CIPTheme.success : CIPTheme.primary,
          size: 18,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final PRNContactStatus status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    Color c;
    String label;
    switch (status) {
      case PRNContactStatus.sent:
        c = CIPTheme.success; label = '✅ Sent'; break;
      case PRNContactStatus.failed:
        c = CIPTheme.error; label = '❌ Failed'; break;
      case PRNContactStatus.pending:
        c = CIPTheme.warning; label = '⏳ Pending'; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withOpacity(0.35)),
      ),
      child: Text(label,
          style: TextStyle(
              color: c, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _StatusBtn extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _StatusBtn({required this.label, required this.active,
    required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.15) : CIPTheme.navLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: active ? color : CIPTheme.divider,
              width: active ? 1.5 : 1),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  color: active ? color : CIPTheme.textSecondary,
                  fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
