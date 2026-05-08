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
          final flight = FlightModel.fromFirestore(doc.data(), doc.id);
          flights.add(flight);
        } catch (e) {
          // ignore: avoid_print
          print('⚠️ خطأ في تحليل الرحلة ${doc.id}: $e');
        }
      }

      // ✅ عرض الرحلات المستقبلية التي لا تزال تملك مقاعد متاحة
      final now = DateTime.now();
      final upcoming = flights
          .where((f) => f.date.isAfter(now) && f.availableSeats > 0)
          .toList();

      // ignore: avoid_print
      print('✅ الرحلات المتاحة: ${upcoming.length}');

      return upcoming;
    });
  }

  /// ✅ حجز رحلة باستخدام Transaction لضمان عدم تجاوز عدد المقاعد
  /// يرمي [Exception] برسالة واضحة إذا امتلأت الرحلة
  Future<void> bookFlight(OrderModel order) async {
    final flightRef = _db.collection('flights').doc(order.flightId);
    final orderRef = _db.collection('orders').doc();

    await _db.runTransaction((transaction) async {
      final flightSnap = await transaction.get(flightRef);

      if (!flightSnap.exists) {
        throw Exception('الرحلة غير موجودة');
      }

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
      final orderData = order.toFirestore()..['seatNumber'] = seatNumber;

      // ✅ إنشاء الطلب وتقليل المقاعد في نفس الوقت (atomic)
      transaction.set(orderRef, orderData);
      transaction.update(flightRef, {
        'availableSeats': seats - 1,
        'reservedSeats': FieldValue.arrayUnion([seatNumber]),
      });
    });
  }

  // ✅ احتفظنا بـ createOrder للتوافق مع أي استخدام آخر
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
    DocumentSnapshot doc = await _db.collection('users').doc(userId).get();
    if (doc.exists) {
      return UserModel.fromFirestore(
          doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    await _db.collection('users').doc(userId).update(data);
  }

  Set<String> _readReservedSeats(Map<String, dynamic> data) {
    final rawSeats = data['reservedSeats'];
    if (rawSeats is! Iterable) return <String>{};

    return rawSeats
        .map((seat) => seat.toString().trim())
        .where((seat) => seat.isNotEmpty)
        .toSet();
  }

  String _nextSeatNumber({
    required int totalSeats,
    required int availableSeats,
    required Set<String> reservedSeats,
  }) {
    final bookedCount =
        (totalSeats - availableSeats).clamp(0, totalSeats).toInt();

    for (var index = 0; index < bookedCount; index++) {
      reservedSeats.add(_seatNumberForIndex(index));
    }

    for (var index = 0; index < totalSeats; index++) {
      final seatNumber = _seatNumberForIndex(index);
      if (!reservedSeats.contains(seatNumber)) return seatNumber;
    }

    throw Exception('تعذر تخصيص رقم مقعد لهذه الرحلة');
  }

  String _seatNumberForIndex(int index) {
    final row = (index ~/ _seatsPerRow) + 1;
    final column = String.fromCharCode(65 + (index % _seatsPerRow));
    return '$column$row';
  }
}
