import 'package:cloud_firestore/cloud_firestore.dart';

class FlightModel {
  final String id;
  final String flightNumber;
  final String origin;
  final String destination;
  final DateTime date;
  final String departureTime; // "14:30"
  final String arrivalTime;   // "18:00"
  final String boardingTime;  // "13:45"
  final String duration;      // "3س 30د"
  final double price;
  final int totalSeats;
  final int availableSeats;

  FlightModel({
    required this.id,
    required this.flightNumber,
    required this.origin,
    required this.destination,
    required this.date,
    required this.departureTime,
    required this.arrivalTime,
    required this.boardingTime,
    required this.duration,
    required this.price,
    required this.totalSeats,
    required this.availableSeats,
  });

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

    final totalSeats = (data['totalSeats'] as num?)?.toInt() ??
        (data['availableSeats'] as num?)?.toInt() ?? 0;

    return FlightModel(
      id: docId,
      flightNumber: data['flightNumber']?.toString() ?? '',
      origin: data['origin']?.toString() ?? '',
      destination: data['destination']?.toString() ?? '',
      date: date,
      departureTime: data['departureTime']?.toString() ?? '',
      arrivalTime: data['arrivalTime']?.toString() ?? '',
      boardingTime: data['boardingTime']?.toString() ?? '',
      duration: data['duration']?.toString() ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      totalSeats: totalSeats,
      availableSeats: (data['availableSeats'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'flightNumber': flightNumber,
      'origin': origin,
      'destination': destination,
      'date': Timestamp.fromDate(date),
      'departureTime': departureTime,
      'arrivalTime': arrivalTime,
      'boardingTime': boardingTime,
      'duration': duration,
      'price': price,
      'totalSeats': totalSeats,
      'availableSeats': availableSeats,
    };
  }
}