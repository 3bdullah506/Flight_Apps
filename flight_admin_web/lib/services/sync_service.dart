import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/flight_model.dart';
import 'firebase_service.dart';
import 'local_db_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final AdminFirebaseService _firebase = AdminFirebaseService();
  final StreamController<bool> _onlineController =
      StreamController<bool>.broadcast();

  StreamSubscription? _connectivitySub;
  Timer? _autoSyncTimer;
  bool _isSyncing = false;
  bool _isOnline = false;

  Stream<bool> get onlineStream => _onlineController.stream;
  bool get isOnline => _isOnline;

  void startMonitoring() {
    if (_connectivitySub != null) {
      _checkNow();
      return;
    }

    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((results) async {
      final online = results.any((r) => r != ConnectivityResult.none);
      await _handleConnectivityState(online);
    }, onError: (_) {
      _isOnline = false;
      _emitOnlineState(false);
    });

    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkNow(),
    );

    _checkNow();
  }

  void stopMonitoring() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  Future<void> _checkNow() async {
    try {
      final results = await Connectivity().checkConnectivity();
      final online = results.any((r) => r != ConnectivityResult.none);
      await _handleConnectivityState(online);
    } catch (_) {
      _isOnline = false;
      _emitOnlineState(false);
    }
  }

  Future<void> _handleConnectivityState(bool online) async {
    _isOnline = online;
    if (online) {
      await syncPendingOperations();
    }
    _emitOnlineState(online);
  }

  Future<int> syncPendingOperations() async {
    if (_isSyncing) return 0;
    _isSyncing = true;
    int synced = 0;

    try {
      final ops = await LocalDbService.getPendingOperations();
      if (ops.isEmpty) return 0;

      for (final op in ops) {
        try {
          final type = op['op_type'] as String;
          final flightId = op['flight_id'] as String;
          final opId = op['id'] as int;
          final rawData = op['data'] as String?;

          switch (type) {
            case 'add':
            case 'update':
              if (rawData != null) {
                final data = _parseData(rawData);
                final flight = _dataToFlight(flightId, data);
                if (type == 'add') {
                  await _firebase.addFlight(flight);
                } else {
                  await _firebase.updateFlight(flightId, flight.toFirestore());
                }
              }
              break;
            case 'delete':
              await _firebase.deleteFlight(flightId);
              break;
          }

          await LocalDbService.deletePendingOp(opId);
          synced++;
        } catch (_) {
          continue;
        }
      }

      if (synced > 0) {
        await _refreshLocalFromFirebase();
      }
    } finally {
      _isSyncing = false;
    }

    return synced;
  }

  void _emitOnlineState(bool online) {
    if (!_onlineController.isClosed) {
      _onlineController.add(online);
    }
  }

  Future<void> _refreshLocalFromFirebase() async {
    try {
      final flights = await _firebase.getFlightsOnce();
      await LocalDbService.syncFromFirebase(flights);
    } catch (_) {}
  }

  Map<String, dynamic> _parseData(String raw) {
    final map = <String, dynamic>{};
    for (final part in raw.split('||')) {
      final idx = part.indexOf('=');
      if (idx == -1) continue;
      map[part.substring(0, idx)] = part.substring(idx + 1);
    }
    return map;
  }

  FlightModel _dataToFlight(String id, Map<String, dynamic> d) => FlightModel(
        id: id,
        flightNumber: d['flightNumber']?.toString() ?? '',
        origin: d['origin']?.toString() ?? '',
        destination: d['destination']?.toString() ?? '',
        date: DateTime.tryParse(d['date']?.toString() ?? '') ?? DateTime.now(),
        departureTime: d['departureTime']?.toString() ?? '',
        arrivalTime: d['arrivalTime']?.toString() ?? '',
        boardingTime: d['boardingTime']?.toString() ?? '',
        duration: d['duration']?.toString() ?? '',
        price: double.tryParse(d['price']?.toString() ?? '0') ?? 0,
        totalSeats: int.tryParse(d['totalSeats']?.toString() ?? '0') ?? 0,
        availableSeats:
            int.tryParse(d['availableSeats']?.toString() ?? '0') ?? 0,
      );
}
