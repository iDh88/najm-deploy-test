import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Connectivity Provider ─────────────────────────────────────────────────
final connectivityProvider =
    StateNotifierProvider<ConnectivityNotifier, ConnectivityState>(
        (ref) => ConnectivityNotifier());

enum ConnectivityStatus { online, offline, checking }

class ConnectivityState {
  final ConnectivityStatus status;
  final DateTime? lastOnline;

  const ConnectivityState({
    required this.status,
    this.lastOnline,
  });

  bool get isOnline  => status == ConnectivityStatus.online;
  bool get isOffline => status == ConnectivityStatus.offline;

  ConnectivityState copyWith({
    ConnectivityStatus? status,
    DateTime? lastOnline,
  }) => ConnectivityState(
    status:     status     ?? this.status,
    lastOnline: lastOnline ?? this.lastOnline,
  );
}

class ConnectivityNotifier extends StateNotifier<ConnectivityState> {
  Timer? _timer;

  ConnectivityNotifier()
      : super(const ConnectivityState(status: ConnectivityStatus.checking)) {
    _startMonitoring();
  }

  void _startMonitoring() {
    _checkConnectivity();
    // Check every 5 seconds
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkConnectivity();
    });
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        if (!state.isOnline) {
          state = state.copyWith(
            status:     ConnectivityStatus.online,
            lastOnline: DateTime.now(),
          );
        }
      }
    } catch (_) {
      if (!state.isOffline) {
        state = state.copyWith(status: ConnectivityStatus.offline);
      }
    }
  }

  Future<void> checkNow() => _checkConnectivity();

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
