import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/flight_model.dart';

class AdminFirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const int _seatsPerRow = 6;

  static Future<void> ensureAuthenticated() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      try {
        await auth.signInAnonymously();
      } catch (e) {
        // ignore
      }
    }
  }

  // ============ الرحلات ============

  Stream<List<FlightModel>> getAllFlights() {
    return _db.collection('flights').orderBy('date').snapshots().map((snap) =>
        snap.docs
            .map((doc) => FlightModel.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  Future<void> addFlight(FlightModel flight) async {
    await _db.collection('flights').add(flight.toFirestore());
  }

  Future<void> updateFlight(String id, Map<String, dynamic> data) async {
    await _db.collection('flights').doc(id).update(data);
  }

  Future<void> deleteFlight(String id) async {
    await _db.collection('flights').doc(id).delete();
  }

  Future<void> uploadFlightsBatch(List<FlightModel> flights) async {
    WriteBatch batch = _db.batch();
    for (final flight in flights) {
      DocumentReference ref = _db.collection('flights').doc();
      batch.set(ref, flight.toFirestore());
    }
    await batch.commit();
  }

  // ============ الطلبات ============

  Stream<List<Map<String, dynamic>>> getAllOrders() {
    return _db.collection('orders').snapshots().map((snap) {
      final orders =
          snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      orders.sort((a, b) {
        final aTime = a['createdAt'];
        final bTime = b['createdAt'];
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });
      return orders;
    });
  }

  /// ✅ تحديث حالة الطلب مع إرجاع المقعد إذا تم الرفض
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    final orderRef = _db.collection('orders').doc(orderId);

    if (newStatus == 'rejected') {
      // نقرأ بيانات الطلب أولاً خارج الـ transaction
      final orderSnap = await orderRef.get();
      if (!orderSnap.exists) return;

      final data = orderSnap.data()!;
      final currentStatus = data['status'] ?? 'pending';
      if (currentStatus == 'rejected') return;

      final flightId = data['flightId'] as String?;
      final hasValidFlight = flightId != null && flightId.isNotEmpty;

      if (hasValidFlight) {
        // Transaction لضمان إرجاع المقعد + تحديث الحالة معاً
        final flightRef = _db.collection('flights').doc(flightId);
        await _db.runTransaction((tx) async {
          final flightSnap = await tx.get(flightRef);
          tx.update(orderRef, {'status': 'rejected'});
          if (flightSnap.exists) {
            final seats =
                (flightSnap.data()!['availableSeats'] as num?)?.toInt() ?? 0;
            final seatNumber = data['seatNumber']?.toString() ?? '';
            tx.update(flightRef, {
              'availableSeats': seats + 1,
              if (seatNumber.isNotEmpty)
                'reservedSeats': FieldValue.arrayRemove([seatNumber]),
            });
          }
        });
      } else {
        // لا توجد رحلة مرتبطة
        await orderRef.update({'status': 'rejected'});
      }
    } else {
      await _approveOrderWithSeatIfNeeded(orderRef, newStatus);
    }
  }

  Future<void> _approveOrderWithSeatIfNeeded(
    DocumentReference<Map<String, dynamic>> orderRef,
    String newStatus,
  ) async {
    if (newStatus != 'approved') {
      await orderRef.update({'status': newStatus});
      return;
    }

    final orderSnap = await orderRef.get();
    if (!orderSnap.exists) return;

    final data = orderSnap.data()!;
    final currentSeat = data['seatNumber']?.toString().trim() ?? '';
    final flightId = data['flightId']?.toString() ?? '';

    if (currentSeat.isNotEmpty || flightId.isEmpty) {
      await orderRef.update({'status': newStatus});
      return;
    }

    final flightRef = _db.collection('flights').doc(flightId);
    await _db.runTransaction((tx) async {
      final flightSnap = await tx.get(flightRef);
      if (!flightSnap.exists) {
        tx.update(orderRef, {'status': newStatus});
        return;
      }

      final flightData = flightSnap.data()!;
      final availableSeats =
          (flightData['availableSeats'] as num?)?.toInt() ?? 0;
      final totalSeats =
          (flightData['totalSeats'] as num?)?.toInt() ?? availableSeats;
      final reservedSeats = _readReservedSeats(flightData);
      final seatNumber = _firstUnreservedSeat(
        totalSeats: totalSeats > 0 ? totalSeats : availableSeats + 1,
        reservedSeats: reservedSeats,
      );

      tx.update(orderRef, {
        'status': newStatus,
        'seatNumber': seatNumber,
      });
      tx.update(flightRef, {
        'reservedSeats': FieldValue.arrayUnion([seatNumber]),
      });
    });
  }

  Set<String> _readReservedSeats(Map<String, dynamic> data) {
    final rawSeats = data['reservedSeats'];
    if (rawSeats is! Iterable) return <String>{};

    return rawSeats
        .map((seat) => seat.toString().trim())
        .where((seat) => seat.isNotEmpty)
        .toSet();
  }

  String _seatNumberForIndex(int index) {
    final row = (index ~/ _seatsPerRow) + 1;
    final column = String.fromCharCode(65 + (index % _seatsPerRow));
    return '$column$row';
  }

  String _firstUnreservedSeat({
    required int totalSeats,
    required Set<String> reservedSeats,
  }) {
    for (var index = 0; index < totalSeats; index++) {
      final seatNumber = _seatNumberForIndex(index);
      if (!reservedSeats.contains(seatNumber)) return seatNumber;
    }

    throw Exception('تعذر تخصيص رقم مقعد لهذه الرحلة');
  }
}
