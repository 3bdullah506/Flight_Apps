import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/flight_model.dart';

class FlightCard extends StatefulWidget {
  final FlightModel flight;
  final Function(FlightModel flight, int quantity) onAddToCart;

  const FlightCard({super.key, required this.flight, required this.onAddToCart});

  @override
  State<FlightCard> createState() => _FlightCardState();
}

class _FlightCardState extends State<FlightCard> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final bool isFull = widget.flight.availableSeats == 0;
    final int maxQty = widget.flight.availableSeats.clamp(1, 10);

    Color seatsColor = widget.flight.availableSeats <= 5
        ? (widget.flight.availableSeats == 0 ? Colors.red : Colors.orange)
        : Colors.green;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          // ── رأس الكارد: رقم الرحلة والمسار ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.indigo.shade700,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.confirmation_number, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    widget.flight.flightNumber.isEmpty
                        ? 'رحلة'
                        : widget.flight.flightNumber,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ]),
                Text(
                  DateFormat('dd/MM/yyyy').format(widget.flight.date),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ── مسار الرحلة + الأوقات ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // الانطلاق
                    Column(children: [
                      const Icon(Icons.flight_takeoff, color: Colors.indigo, size: 28),
                      const SizedBox(height: 4),
                      Text(widget.flight.origin,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      if (widget.flight.departureTime.isNotEmpty)
                        Text(widget.flight.departureTime,
                            style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 15)),
                    ]),
                    // المدة
                    Column(children: [
                      const Icon(Icons.arrow_forward, color: Colors.grey),
                      if (widget.flight.duration.isNotEmpty)
                        Text(widget.flight.duration,
                            style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ]),
                    // الوصول
                    Column(children: [
                      const Icon(Icons.flight_land, color: Colors.green, size: 28),
                      const SizedBox(height: 4),
                      Text(widget.flight.destination,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      if (widget.flight.arrivalTime.isNotEmpty)
                        Text(widget.flight.arrivalTime,
                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 15)),
                    ]),
                  ],
                ),

                const Divider(height: 20),

                // ── تفاصيل: الصعود + المقاعد + السعر ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // وقت الصعود
                    if (widget.flight.boardingTime.isNotEmpty)
                      Row(children: [
                        const Icon(Icons.airline_seat_recline_normal,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 3),
                        Text('صعود: ${widget.flight.boardingTime}',
                            style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ])
                    else
                      const SizedBox(),
                    // المقاعد
                    Row(children: [
                      Icon(Icons.event_seat, size: 14, color: seatsColor),
                      const SizedBox(width: 3),
                      Text(
                        isFull
                            ? 'مكتملة'
                            : '${widget.flight.availableSeats} متاح',
                        style: TextStyle(
                            color: seatsColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ]),
                    // السعر
                    Text('\$${widget.flight.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo)),
                  ],
                ),

                if (!isFull) ...[
                  const SizedBox(height: 12),
                  // ── اختيار عدد التذاكر ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('التذاكر:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.indigo.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 18),
                              onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                              color: Colors.indigo,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              padding: EdgeInsets.zero,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: Text('$_quantity',
                                  style: const TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 18),
                              onPressed: _quantity < maxQty ? () => setState(() => _quantity++) : null,
                              color: Colors.indigo,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '\$${(widget.flight.price * _quantity).toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: Colors.indigo, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isFull
                        ? null
                        : () => widget.onAddToCart(widget.flight, _quantity),
                    icon: Icon(isFull ? Icons.block : Icons.add_shopping_cart),
                    label: Text(isFull
                        ? 'الرحلة مكتملة'
                        : 'أضف للسلة ($_quantity تذكرة)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFull ? Colors.grey : Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
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