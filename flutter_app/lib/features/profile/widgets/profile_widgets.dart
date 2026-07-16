import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

/// Shared Profile UI atoms (NajmTheme: dark navy, gold accents, rounded
/// cards). Declared once and reused across every section — the brief's
/// "No duplicated widgets".

class ProfileSectionLabel extends StatelessWidget {
  final String text;
  final bool danger;
  const ProfileSectionLabel(this.text, {super.key, this.danger = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          color: danger ? NajmTheme.error : NajmTheme.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class ProfileCard extends StatelessWidget {
  final Widget child;
  final bool accent;
  final bool padded;
  final Color? borderColor;

  const ProfileCard({
    super.key,
    required this.child,
    this.accent = false,
    this.padded = true,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padded ? const EdgeInsets.all(16) : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: NajmTheme.navyCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor ??
              (accent ? NajmTheme.gold : NajmTheme.cardBorder),
          width: accent || borderColor != null ? 1.2 : 1,
        ),
      ),
      child: child,
    );
  }
}

class ProfileKeyValue extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasise;

  const ProfileKeyValue({
    super.key,
    required this.label,
    required this.value,
    this.emphasise = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 150,
              child: Text(
                label,
                style: const TextStyle(
                    color: NajmTheme.textMuted, fontSize: 13),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color: emphasise ? NajmTheme.warning : NajmTheme.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool dense;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: dense ? 7 : 10, vertical: dense ? 2 : 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: dense ? 10.5 : 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class HealthDot extends StatelessWidget {
  final Color color;
  const HealthDot({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.5), blurRadius: 6, spreadRadius: 1),
        ],
      ),
    );
  }
}

class EngineChip extends StatelessWidget {
  final String label;
  final String trigger; // triggered | queued | on_demand
  const EngineChip({super.key, required this.label, required this.trigger});

  @override
  Widget build(BuildContext context) {
    final color = switch (trigger) {
      'triggered' => NajmTheme.success,
      'queued' => NajmTheme.info,
      _ => NajmTheme.textMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: NajmTheme.navyMid,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: NajmTheme.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
                color: NajmTheme.textSecondary, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

/// Shimmering loading skeleton (the brief's "Loading skeletons").
class ProfileSkeleton extends StatefulWidget {
  final double height;
  const ProfileSkeleton({super.key, required this.height});

  @override
  State<ProfileSkeleton> createState() => _ProfileSkeletonState();
}

class _ProfileSkeletonState extends State<ProfileSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(
              NajmTheme.navyCard, NajmTheme.navyMid, _c.value),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: NajmTheme.cardBorder),
        ),
      ),
    );
  }
}

class ProfileErrorNote extends StatelessWidget {
  final String message;
  const ProfileErrorNote(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, color: NajmTheme.warning, size: 17),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
                color: NajmTheme.textSecondary, fontSize: 12.5, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool danger;
  final bool enabled;

  const ProfileTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.danger = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? NajmTheme.error : NajmTheme.textPrimary;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: (danger ? NajmTheme.error : NajmTheme.gold)
                .withOpacity(0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon,
              color: danger ? NajmTheme.error : NajmTheme.gold, size: 19),
        ),
        title: Text(
          title,
          style: TextStyle(
              color: color, fontSize: 14.5, fontWeight: FontWeight.w600),
        ),
        subtitle: subtitle == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  subtitle!,
                  style: TextStyle(
                    color: danger
                        ? NajmTheme.error.withOpacity(0.8)
                        : NajmTheme.textMuted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
        trailing: onTap == null
            ? null
            : const Icon(Icons.chevron_right,
                color: NajmTheme.textMuted, size: 20),
        onTap: (!enabled || onTap == null)
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
      ),
    );
  }
}

/// The Security card — reinforces the Zero-Knowledge architecture.
///
/// Note what this widget does NOT do: it never reads secure storage. It has
/// no access to a CredentialManager and no way to obtain a credential, so it
/// cannot leak one even by accident. It states the guarantee; it does not
/// handle the secret.
class SecurityCard extends StatelessWidget {
  const SecurityCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfileCard(
      accent: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: NajmTheme.success.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.verified_user,
                    color: NajmTheme.success, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Zero-Knowledge Credentials',
                  style: TextStyle(
                      color: NajmTheme.textPrimary,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const StatusBadge(label: 'Protected', color: NajmTheme.success),
            ],
          ),
          const SizedBox(height: 14),
          const _SecurityPoint('Stored only in Apple Keychain / Android '
              'Keystore on this device'),
          const _SecurityPoint('Never uploaded to NAJM servers, never written '
              'to logs or analytics'),
          const _SecurityPoint('Your roster is normalized on-device — the raw '
              'calendar never leaves your phone'),
          const _SecurityPoint('Disconnecting a source securely erases every '
              'stored credential'),
        ],
      ),
    );
  }
}

class _SecurityPoint extends StatelessWidget {
  final String text;
  const _SecurityPoint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.check, color: NajmTheme.success, size: 15),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  color: NajmTheme.textSecondary, fontSize: 12.5, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
