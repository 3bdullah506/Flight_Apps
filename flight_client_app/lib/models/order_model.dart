import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String id;
  final String bookingId;       // رقم الحجز مثل BK-20260508-4821
  final String userId;
  final String flightId;
  final String flightNumber;
  final String origin;
  final String destination;
  final DateTime flightDate;
  final String departureTime;
  final String arrivalTime;
  final String boardingTime;
  final String duration;
  final double price;
  final String status;
  final DateTime createdAt;
  final String userName;
  final String userEmail;
  final String userPhone;
  final String passportNumber;  // رقم الهوية / الجواز
  final String seatNumber;      // المقعد المختار مثل A1

  OrderModel({
    required this.id,
    required this.bookingId,
    required this.userId,
    required this.flightId,
    required this.flightNumber,
    required this.origin,
    required this.destination,
    required this.flightDate,
    this.departureTime = '',
    this.arrivalTime = '',
    this.boardingTime = '',
    this.duration = '',
    required this.price,
    this.status = 'pending',
    required this.createdAt,
    required this.userName,
    required this.userEmail,
    this.userPhone = '',
    this.passportNumber = '',
    this.seatNumber = '',
  });

  factory OrderModel.fromFirestore(Map<String, dynamic> data, String docId) {
    DateTime parseDate(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
      return DateTime.now();
    }

    return OrderModel(
      id: docId,
      bookingId: data['bookingId']?.toString() ?? 'BK-$docId',
      userId: data['userId']?.toString() ?? '',
      flightId: data['flightId']?.toString() ?? '',
      flightNumber: data['flightNumber']?.toString() ?? '',
      origin: data['origin']?.toString() ?? '',
      destination: data['destination']?.toString() ?? '',
      flightDate: parseDate(data['flightDate']),
      departureTime: data['departureTime']?.toString() ?? '',
      arrivalTime: data['arrivalTime']?.toString() ?? '',
      boardingTime: data['boardingTime']?.toString() ?? '',
      duration: data['duration']?.toString() ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      status: data['status']?.toString() ?? 'pending',
      createdAt: parseDate(data['createdAt']),
      userName: data['userName']?.toString() ?? 'غير معروف',
      userEmail: data['userEmail']?.toString() ?? '',
      userPhone: data['userPhone']?.toString() ?? '',
      passportNumber: data['passportNumber']?.toString() ?? '',
      seatNumber: data['seatNumber']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'bookingId': bookingId,
      'userId': userId,
      'flightId': flightId,
      'flightNumber': flightNumber,
      'origin': origin,
      'destination': destination,
      'flightDate': Timestamp.fromDate(flightDate),
      'departureTime': departureTime,
      'arrivalTime': arrivalTime,
      'boardingTime': boardingTime,
      'duration': duration,
      'price': price,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'userName': userName,
      'userEmail': userEmail,
      'userPhone': userPhone,
      'passportNumber': passportNumber,
      'seatNumber': seatNumber,
    };
  }
}