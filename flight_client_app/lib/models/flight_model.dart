import 'package:cloud_firestore/cloud_firestore.dart';

class FlightModel {
  final String id;
  final String flightNumber;
  final String origin;
  final String destination;
  final DateTime date;
  final int departureMinutes;
  final int arrivalMinutes;
  final int boardingMinutes;
  final int durationMinutes;
  final double price;
  final int totalSeats;
  final int availableSeats;

  FlightModel({
    required this.id,
    required this.flightNumber,
    required this.origin,
    required this.destination,
    required this.date,
    required String departureTime,
    required String arrivalTime,
    required String boardingTime,
    String duration = '',
    required this.price,
    required this.totalSeats,
    required this.availableSeats,
  })  : departureMinutes = parseClockMinutes(departureTime) ?? -1,
        arrivalMinutes = parseClockMinutes(arrivalTime) ?? -1,
        boardingMinutes = parseClockMinutes(boardingTime) ?? -1,
        durationMinutes = _resolveDurationMinutes(
          departureTime: departureTime,
          arrivalTime: arrivalTime,
          duration: duration,
        );

  FlightModel.typed({
    required this.id,
    required this.flightNumber,
    required this.origin,
    required this.destination,
    required this.date,
    required this.departureMinutes,
    required this.arrivalMinutes,
    required this.boardingMinutes,
    required this.durationMinutes,
    required this.price,
    required this.totalSeats,
    required this.availableSeats,
  });

  String get departureTime => formatClockMinutes(departureMinutes);
  String get arrivalTime => formatClockMinutes(arrivalMinutes);
  String get boardingTime => formatClockMinutes(boardingMinutes);
  String get duration => formatDurationMinutes(durationMinutes);

  factory FlightModel.fromFirestore(Map<String, dynamic> data, String docId) {
    DateTime date;
    final rawDate = data['date'];
    if (rawDate is Timestamp) {
      date = rawDate.toDate();
    } else if (rawDate is String) {
      date = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      date = DateTime.now();
    }

    final totalSeats =
        _readInt(data['totalSeats']) ?? _readInt(data['availableSeats']) ?? 0;
    final availableSeats =
        (_readInt(data['availableSeats']) ?? 0).clamp(0, totalSeats).toInt();
    final departureMinutes = _readMinutes(data, 'departure');
    final arrivalMinutes = _readMinutes(data, 'arrival');
    final boardingMinutes = _readMinutes(data, 'boarding');
    final durationMinutes = _readInt(data['durationMinutes']) ??
        _durationBetween(departureMinutes, arrivalMinutes);

    return FlightModel.typed(
      id: docId,
      flightNumber: data['flightNumber']?.toString() ?? '',
      origin: data['origin']?.toString() ?? '',
      destination: data['destination']?.toString() ?? '',
      date: date,
      departureMinutes: departureMinutes,
      arrivalMinutes: arrivalMinutes,
      boardingMinutes: boardingMinutes,
      durationMinutes: durationMinutes,
      price: _readDouble(data['price']) ?? 0.0,
      totalSeats: totalSeats,
      availableSeats: availableSeats,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'flightNumber': flightNumber.trim(),
      'origin': origin.trim(),
      'destination': destination.trim(),
      'date': Timestamp.fromDate(date),
      'departureMinutes': departureMinutes,
      'arrivalMinutes': arrivalMinutes,
      'boardingMinutes': boardingMinutes,
      'durationMinutes': durationMinutes,
      'departureTime': departureTime,
      'arrivalTime': arrivalTime,
      'boardingTime': boardingTime,
      'duration': duration,
      'price': price,
      'totalSeats': totalSeats,
      'availableSeats': availableSeats.clamp(0, totalSeats),
    };
  }

  static int? parseClockMinutes(String value) {
    final text = value.trim();
    final match = RegExp(r'^([01]?\d|2[0-3]):([0-5]\d)$').firstMatch(text);
    if (match == null) return null;
    return int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
  }

  static String formatClockMinutes(int minutes) {
    if (minutes < 0) return '';
    final normalized = minutes % (24 * 60);
    final h = (normalized ~/ 60).toString().padLeft(2, '0');
    final m = (normalized % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String formatDurationMinutes(int minutes) {
    if (minutes <= 0) return '';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$mد';
    if (m == 0) return '$hس';
    return '$hس $mد';
  }

  static int _readMinutes(Map<String, dynamic> data, String key) {
    return _readInt(data['${key}Minutes']) ??
        parseClockMinutes(data['${key}Time']?.toString() ?? '') ??
        -1;
  }

  static int _resolveDurationMinutes({
    required String departureTime,
    required String arrivalTime,
    required String duration,
  }) {
    final departure = parseClockMinutes(departureTime) ?? -1;
    final arrival = parseClockMinutes(arrivalTime) ?? -1;
    final calculated = _durationBetween(departure, arrival);
    if (calculated > 0) return calculated;

    final hours = RegExp(r'(\d+)\s*س').firstMatch(duration);
    final minutes = RegExp(r'(\d+)\s*د').firstMatch(duration);
    return (hours == null ? 0 : int.parse(hours.group(1)!) * 60) +
        (minutes == null ? 0 : int.parse(minutes.group(1)!));
  }

  static int _durationBetween(int departure, int arrival) {
    if (departure < 0 || arrival < 0) return 0;
    final diff = (arrival - departure) % (24 * 60);
    return diff == 0 ? 0 : diff;
  }

  static int? _readInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static double? _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}
