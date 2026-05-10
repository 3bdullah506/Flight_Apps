import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/flight_model.dart';

/// نوع العملية المعلقة
enum PendingOpType { add, update, delete }

class LocalDbService {
  static const String _flightsKey = 'admin_cached_flights';
  static const String _pendingOpsKey = 'admin_pending_operations';

  // ════════════════════════════════
  //  CRUD الرحلات محلياً
  // ════════════════════════════════

  /// جلب كل الرحلات من التخزين المحلي.
  static Future<List<FlightModel>> getAllFlights() async {
    final rows = await _readFlightRows();
    rows.sort((a, b) => _readText(a['date']).compareTo(_readText(b['date'])));
    return rows.map(_rowToFlight).toList();
  }

  /// إضافة رحلة محلياً + تسجيل عملية معلقة
  static Future<void> addFlight(FlightModel flight) async {
    final rows = await _readFlightRows();
    rows.removeWhere((row) => row['id'] == flight.id);
    rows.add(_flightToRow(flight));
    await _writeFlightRows(rows);
    await _addPendingOp(PendingOpType.add, flight.id, _flightToRow(flight));
  }

  /// تعديل رحلة محلياً + تسجيل عملية معلقة
  static Future<void> updateFlight(String id, FlightModel flight) async {
    final rows = await _readFlightRows();
    final updatedRow = _flightToRow(flight);
    final index = rows.indexWhere((row) => row['id'] == id);

    if (index == -1) {
      rows.add(updatedRow);
    } else {
      rows[index] = updatedRow;
    }

    await _writeFlightRows(rows);
    await _addPendingOp(PendingOpType.update, id, updatedRow);
  }

  /// حذف رحلة محلياً + تسجيل عملية معلقة
  static Future<void> deleteFlight(String id) async {
    final rows = await _readFlightRows();
    rows.removeWhere((row) => row['id'] == id);
    await _writeFlightRows(rows);
    await _addPendingOp(PendingOpType.delete, id, null);
  }

  // ════════════════════════════════
  //  العمليات المعلقة
  // ════════════════════════════════

  /// جلب كل العمليات المعلقة
  static Future<List<Map<String, dynamic>>> getPendingOperations() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingOpsKey);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];

    return decoded
        .whereType<Map>()
        .map((op) => Map<String, dynamic>.from(op))
        .toList();
  }

  /// حذف عملية معلقة بعد رفعها
  static Future<void> deletePendingOp(int opId) async {
    final ops = await getPendingOperations();
    ops.removeWhere((op) => op['id'] == opId);
    await _writePendingOperations(ops);
  }

  /// حذف كل العمليات المعلقة (بعد مزامنة ناجحة)
  static Future<void> clearPendingOperations() async {
    await _writePendingOperations([]);
  }

  /// مزامنة الرحلات من Firebase إلى التخزين المحلي (عند الاتصال)
  static Future<void> syncFromFirebase(List<FlightModel> flights) async {
    await _writeFlightRows(flights.map(_flightToRow).toList());
  }

  // ════════════════════════════════
  //  Helpers
  // ════════════════════════════════

  static Future<List<Map<String, dynamic>>> _readFlightRows() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_flightsKey);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];

    return decoded
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  static Future<void> _writeFlightRows(List<Map<String, dynamic>> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_flightsKey, jsonEncode(rows));
  }

  static Future<void> _writePendingOperations(
    List<Map<String, dynamic>> ops,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingOpsKey, jsonEncode(ops));
  }

  static Future<void> _addPendingOp(
    PendingOpType type,
    String flightId,
    Map<String, dynamic>? data,
  ) async {
    final ops = await getPendingOperations();
    final nextId = ops.fold<int>(
          0,
          (maxId, op) {
            final id = (op['id'] as num?)?.toInt() ?? 0;
            return id > maxId ? id : maxId;
          },
        ) +
        1;

    ops.add({
      'id': nextId,
      'op_type': type.name,
      'flight_id': flightId,
      'data': data?.entries.map((e) => '${e.key}=${e.value}').join('||'),
      'created_at': DateTime.now().toIso8601String(),
    });

    await _writePendingOperations(ops);
  }

  static Map<String, dynamic> _flightToRow(FlightModel f) => {
        'id': f.id,
        'flightNumber': f.flightNumber,
        'origin': f.origin,
        'destination': f.destination,
        'date': f.date.toIso8601String(),
        'departureMinutes': f.departureMinutes,
        'arrivalMinutes': f.arrivalMinutes,
        'boardingMinutes': f.boardingMinutes,
        'durationMinutes': f.durationMinutes,
        'departureTime': f.departureTime,
        'arrivalTime': f.arrivalTime,
        'boardingTime': f.boardingTime,
        'duration': f.duration,
        'price': f.price,
        'totalSeats': f.totalSeats,
        'availableSeats': f.availableSeats,
      };

  static FlightModel _rowToFlight(Map<String, dynamic> row) {
    final totalSeats = _readInt(row['totalSeats']);
    final availableSeats = _readInt(row['availableSeats']).clamp(0, totalSeats);
    final departureMinutes = _readIntOrNull(row['departureMinutes']) ??
        FlightModel.parseClockMinutes(_readText(row['departureTime'])) ??
        -1;
    final arrivalMinutes = _readIntOrNull(row['arrivalMinutes']) ??
        FlightModel.parseClockMinutes(_readText(row['arrivalTime'])) ??
        -1;
    final boardingMinutes = _readIntOrNull(row['boardingMinutes']) ??
        FlightModel.parseClockMinutes(_readText(row['boardingTime'])) ??
        -1;
    final durationMinutes = _readIntOrNull(row['durationMinutes']) ??
        _durationBetween(departureMinutes, arrivalMinutes);

    return FlightModel.typed(
      id: _readText(row['id']),
      flightNumber: _readText(row['flightNumber']),
      origin: _readText(row['origin']),
      destination: _readText(row['destination']),
      date: DateTime.tryParse(_readText(row['date'])) ?? DateTime.now(),
      departureMinutes: departureMinutes,
      arrivalMinutes: arrivalMinutes,
      boardingMinutes: boardingMinutes,
      durationMinutes: durationMinutes,
      price: _readDouble(row['price']),
      totalSeats: totalSeats,
      availableSeats: availableSeats,
    );
  }

  static String _readText(dynamic value) => value?.toString() ?? '';

  static int _readInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _readIntOrNull(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _durationBetween(int departure, int arrival) {
    if (departure < 0 || arrival < 0) return 0;
    final diff = (arrival - departure) % (24 * 60);
    return diff == 0 ? 0 : diff;
  }
}
