import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/flight_model.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const int _seatsPerRow = 6;

  Stream<List<FlightModel>> getFlights() {
    return _db
        .collection('flights')
        .orderBy('date')
        .snapshots()
        .map((snapshot) {
      // ignore: avoid_print
      print('✈️ عدد الرحلات المستلمة من Firebase: ${snapshot.docs.length}');

      final List<FlightModel> flights = [];
      for (final doc in snapshot.docs) {
        try {
          flights.add(FlightModel.fromFirestore(doc.data(), doc.id));
        } catch (e) {
          // ignore: avoid_print
          print('⚠️ خطأ في تحليل الرحلة ${doc.id}: $e');
        }
      }

      final now = DateTime.now();
      return flights
          .where((f) => f.date.isAfter(now) && f.availableSeats > 0)
          .toList();
    });
  }

  /// حجز بمقعد يختاره العميل بصرياً
  Future<void> bookFlightWithSeat(OrderModel order, String seatNumber) async {
    final flightRef = _db.collection('flights').doc(order.flightId);
    final orderRef = _db.collection('orders').doc();

    await _db.runTransaction((transaction) async {
      final flightSnap = await transaction.get(flightRef);

      if (!flightSnap.exists) throw Exception('الرحلة غير موجودة');

      final flightData = flightSnap.data()!;
      final seats = (flightData['availableSeats'] as num?)?.toInt() ?? 0;

      if (seats <= 0) {
        throw Exception('عذراً، اكتملت مقاعد هذه الرحلة ولا يمكن إتمام الحجز');
      }

      // التحقق أن المقعد لم يُحجز في نفس الوقت من شخص آخر
      final reservedSeats = _readReservedSeats(flightData);
      if (seatNumber.isNotEmpty && reservedSeats.contains(seatNumber)) {
        throw Exception(
            'المقعد $seatNumber محجوز بالفعل، يرجى اختيار مقعد آخر');
      }

      final orderData = {
        ...order.toFirestore(),
        'seatNumber': seatNumber,
      };

      transaction.set(orderRef, orderData);
      transaction.update(flightRef, {
        'availableSeats': seats - 1,
        if (seatNumber.isNotEmpty)
          'reservedSeats': FieldValue.arrayUnion([seatNumber]),
      });
    });
  }

  /// حجز تلقائي (للتوافق مع الكود القديم)
  Future<void> bookFlight(OrderModel order) async {
    final flightRef = _db.collection('flights').doc(order.flightId);
    final orderRef = _db.collection('orders').doc();

    await _db.runTransaction((transaction) async {
      final flightSnap = await transaction.get(flightRef);
      if (!flightSnap.exists) throw Exception('الرحلة غير موجودة');

      final flightData = flightSnap.data()!;
      final seats = (flightData['availableSeats'] as num?)?.toInt() ?? 0;
      final totalSeats = (flightData['totalSeats'] as num?)?.toInt() ?? seats;

      if (seats <= 0) {
        throw Exception('عذراً، اكتملت مقاعد هذه الرحلة ولا يمكن إتمام الحجز');
      }

      final reservedSeats = _readReservedSeats(flightData);
      final seatNumber = _nextSeatNumber(
        totalSeats: totalSeats > 0 ? totalSeats : seats,
        availableSeats: seats,
        reservedSeats: reservedSeats,
      );

      final orderData = {
        ...order.toFirestore(),
        'seatNumber': seatNumber,
      };

      transaction.set(orderRef, orderData);
      transaction.update(flightRef, {
        'availableSeats': seats - 1,
        'reservedSeats': FieldValue.arrayUnion([seatNumber]),
      });
    });
  }

  Future<void> createOrder(OrderModel order) async {
    await _db.collection('orders').add(order.toFirestore());
  }

  Stream<List<OrderModel>> getUserOrders(String userId) {
    return _db
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final orders = snapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc.data(), doc.id))
          .toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    });
  }

  Future<UserModel?> getUser(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    if (doc.exists) {
      return UserModel.fromFirestore(
          doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    await _db.collection('users').doc(userId).update(data);
  }

  // ── helpers ──

  Set<String> _readReservedSeats(Map<String, dynamic> data) {
    final raw = data['reservedSeats'];
    if (raw is! Iterable) return {};
    return raw
        .map((s) => s.toString().trim())
        .where((s) => s.isNotEmpty)
        .toSet();
  }

  String _nextSeatNumber({
    required int totalSeats,
    required int availableSeats,
    required Set<String> reservedSeats,
  }) {
    final bookedCount = (totalSeats - availableSeats).clamp(0, totalSeats);
    for (var i = 0; i < bookedCount; i++) {
      reservedSeats.add(_seatNumberForIndex(i));
    }
    for (var i = 0; i < totalSeats; i++) {
      final seat = _seatNumberForIndex(i);
      if (!reservedSeats.contains(seat)) return seat;
    }
    throw Exception('تعذر تخصيص رقم مقعد لهذه الرحلة');
  }

  String _seatNumberForIndex(int index) {
    final row = (index ~/ _seatsPerRow) + 1;
    final column = String.fromCharCode(65 + (index % _seatsPerRow));
    return '$column$row';
  }
}
