import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import '../services/firebase_service.dart';
import 'home_screen.dart';
import 'seat_selection_screen.dart';

class CartScreen extends StatefulWidget {
  final List<CartItem> cart;
  final Function(CartItem) onRemove;

  const CartScreen({super.key, required this.cart, required this.onRemove});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = false;

  double get _total =>
      widget.cart.fold(0, (sum, item) => sum + item.flight.price * item.quantity);

  String _generateBookingId() {
    final now = DateTime.now();
    final rand = (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
    return 'BK-${DateFormat('yyyyMMdd').format(now)}-$rand';
  }

  /// جلب المقاعد المحجوزة لرحلة معينة من Firestore
  Future<List<String>> _getReservedSeats(String flightId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('flights')
          .doc(flightId)
          .get();
      final raw = doc.data()?['reservedSeats'];
      if (raw is List) return raw.map((e) => e.toString()).toList();
    } catch (_) {}
    return [];
  }

  Future<void> _confirmBooking() async {
    if (widget.cart.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // ── لكل عنصر في السلة: نفتح شاشة اختيار المقاعد أولاً ──
    final Map<CartItem, List<String>> selectedSeatsMap = {};

    for (final item in widget.cart) {
      final reserved = await _getReservedSeats(item.flight.id);

      if (!mounted) return;
      final List<String>? seats = await Navigator.push<List<String>>(
        context,
        MaterialPageRoute(
          builder: (_) => SeatSelectionScreen(
            flight: item.flight,
            quantity: item.quantity,
            reservedSeats: reserved,
          ),
        ),
      );

      if (seats == null || seats.length != item.quantity) {
        // المستخدم ضغط رجوع بدون اختيار
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'لم يتم اختيار مقاعد لرحلة ${item.flight.origin} → ${item.flight.destination}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      selectedSeatsMap[item] = seats;
    }

    // ── بعد اختيار كل المقاعد: نبدأ الحجز ──
    final userProfile = await _firebaseService.getUser(user.uid);
    setState(() => _isLoading = true);

    final List<String> failedRoutes = [];

    for (final item in List.from(widget.cart)) {
      final seats = selectedSeatsMap[item] ?? [];

      for (int t = 0; t < item.quantity; t++) {
        final seatNumber = t < seats.length ? seats[t] : '';

        final order = OrderModel(
          id: '',
          bookingId: _generateBookingId(),
          userId: user.uid,
          flightId: item.flight.id,
          flightNumber: item.flight.flightNumber,
          origin: item.flight.origin,
          destination: item.flight.destination,
          flightDate: item.flight.date,
          departureTime: item.flight.departureTime,
          arrivalTime: item.flight.arrivalTime,
          boardingTime: item.flight.boardingTime,
          duration: item.flight.duration,
          price: item.flight.price,
          createdAt: DateTime.now(),
          userName: userProfile?.name.isNotEmpty == true
              ? userProfile!.name
              : (user.displayName?.isNotEmpty == true
                  ? user.displayName!
                  : user.email?.split('@').first ?? 'عميل'),
          userEmail: user.email ?? '',
          userPhone: userProfile?.phone ?? '',
          passportNumber: userProfile?.passportNumber ?? '',
          seatNumber: seatNumber,
        );

        try {
          await _firebaseService.bookFlightWithSeat(order, seatNumber);
        } on Exception catch (e) {
          final route = '${item.flight.origin} → ${item.flight.destination}';
          if (!failedRoutes.contains(route)) failedRoutes.add(route);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    '$route: ${e.toString().replaceFirst('Exception: ', '')}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          break;
        }
      }

      final route = '${item.flight.origin} → ${item.flight.destination}';
      if (!failedRoutes.contains(route)) widget.onRemove(item);
    }

    if (mounted && failedRoutes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال طلبات الحجز بنجاح ✓'),
          backgroundColor: Colors.green,
        ),
      );
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: widget.cart.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('سلتك فارغة',
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.cart.length,
                    itemBuilder: (context, index) {
                      final item = widget.cart[index];
                      return Card(
                        child: ListTile(
                          leading:
                              const Icon(Icons.flight, color: Colors.indigo),
                          title: Text(
                              '${item.flight.origin} → ${item.flight.destination}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(DateFormat('dd/MM/yyyy')
                                  .format(item.flight.date)),
                              if (item.flight.departureTime.isNotEmpty)
                                Text('إقلاع: ${item.flight.departureTime}',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey)),
                              Text(
                                  '${item.quantity} × \$${item.flight.price.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      color: Colors.indigo, fontSize: 12)),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '\$${(item.flight.price * item.quantity).toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => widget.onRemove(item),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('الإجمالي:',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('\$${_total.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Icon(Icons.event_seat,
                              size: 14, color: Colors.indigo),
                          SizedBox(width: 6),
                          Text(
                            'ستختار مقعدك عند الضغط على تأكيد الحجز',
                            style:
                                TextStyle(fontSize: 12, color: Colors.indigo),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _confirmBooking,
                          icon: _isLoading
                              ? const SizedBox()
                              : const Icon(Icons.event_seat),
                          label: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text('اختر مقعدك وأكد الحجز',
                                  style: TextStyle(fontSize: 15)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}