import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/constants/constants.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/roster_sync/sync_models.dart';
import '../../../core/services/ai_status_service.dart';

/// Profile state.
///
/// COMPOSES existing providers — it does not re-implement them:
///   subscription → features/subscription/providers (entitlementProvider,
///                  usageStatusProvider)
///   roster       → core/roster_sync/roster_sync_providers (syncStatusProvider,
///                  healthMonitorProvider, rosterSyncServiceProvider)
///   auth         → core/auth/auth_provider (currentUserProvider, authService)
/// Only genuinely new sources are declared here: AI status and package info.

final aiStatusServiceProvider =
    Provider<AiStatusService>((ref) => AiStatusService());

final aiStatusProvider = FutureProvider<AiStatus>(
    (ref) => ref.watch(aiStatusServiceProvider).getStatus());

/// Real app version + build number (package_info_plus is already a dependency).
final packageInfoProvider =
    FutureProvider<PackageInfo>((_) => PackageInfo.fromPlatform());

// ── Pure view-model logic (unit-tested; no Flutter, no I/O) ─────────────────

/// The subscription card's fields, derived from the real `Entitlement`.
///
/// The brief asks for a Start Date. The backend stores `trialStartedAt` for
/// trials, but paid plans have no start date on the entitlement payload — so
/// [startDate] is nullable and the card renders "—" rather than inventing one.
class SubscriptionCardView {
  final String planName;
  final String statusLabel;
  final DateTime? startDate;
  final DateTime? renewalDate;
  final int? remainingDays;
  final bool isActive;

  const SubscriptionCardView({
    required this.planName,
    required this.statusLabel,
    required this.isActive,
    this.startDate,
    this.renewalDate,
    this.remainingDays,
  });

  /// [now] is injected so the calculation is deterministic in tests.
  static int? daysRemaining(DateTime? renewal, DateTime now) {
    if (renewal == null) return null;
    final days = renewal.difference(now).inDays;
    return days < 0 ? 0 : days;
  }
}

/// Health of the roster sync, for the Synchronization card's badge.
/// 🟢 healthy · 🟡 waiting · 🔴 failed — mapped from REAL connection state.
enum ProfileSyncBadge { healthy, waiting, failed, none }

ProfileSyncBadge syncBadgeFor(SyncStatus? status, {DateTime? now}) {
  if (status == null) return ProfileSyncBadge.none;
  final connections =
      status.connections.where((c) => c.status != 'disconnected').toList();
  if (connections.isEmpty) return ProfileSyncBadge.none;

  final hasError = connections.any(
      (c) => c.lastError != null && c.lastError!.isNotEmpty);
  if (hasError) return ProfileSyncBadge.failed;

  final anySuccess = connections.any((c) => c.lastSuccessAt != null);
  if (!anySuccess) return ProfileSyncBadge.waiting;

  return ProfileSyncBadge.healthy;
}

/// The provider that actually fed the latest roster — `preferred_source`
/// computed server-side from the priority order (CAE → ICS → PDF → Excel).
String? activeSourceOf(SyncStatus? status) {
  if (status == null) return null;
  final conn = status.connection(status.preferredSource);
  return conn == null ? null : status.preferredSource;
}

/// mailto: URI for the two support addresses. Built here (not inline in the
/// widget) so it is unit-testable and cannot silently break.
Uri supportMailto(String address, {required String subject}) => Uri(
      scheme: 'mailto',
      path: address,
      queryParameters: {'subject': subject},
    );

// Single source of truth: AppConstants. These were previously declared
// here AS WELL, so the same address existed twice — update one, and the
// other quietly keeps routing crew mail to a stale inbox. Re-exported
// (not re-declared) so the literal lives in exactly one place.
const supportEmail = AppConstants.supportEmail;
const administratorEmail = AppConstants.administratorEmail;
