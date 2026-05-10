import 'package:flutter/material.dart';
import '../models/flight_model.dart';

class SeatSelectionScreen extends StatefulWidget {
  final FlightModel flight;
  final int quantity; // عدد التذاكر المطلوبة
  final List<String> reservedSeats; // المقاعد المحجوزة مسبقاً

  const SeatSelectionScreen({
    super.key,
    required this.flight,
    required this.quantity,
    required this.reservedSeats,
  });

  @override
  State<SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  static const int seatsPerRow = 6;
  static const List<String> columns = ['A', 'B', 'C', '', 'D', 'E', 'F'];

  final Set<String> _selected = {};

  String _seatLabel(int row, String col) => '$col$row';

  @override
  Widget build(BuildContext context) {
    final totalRows = (widget.flight.totalSeats / seatsPerRow).ceil();

    return Scaffold(
      appBar: AppBar(
        title: Text(
            'اختر ${widget.quantity == 1 ? 'مقعدك' : '${widget.quantity} مقاعد'}'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ── معلومات الرحلة ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: Colors.indigo.shade50,
            child: Text(
              '${widget.flight.origin} → ${widget.flight.destination}'
              '  •  ${widget.flight.departureTime.isNotEmpty ? widget.flight.departureTime : ""}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.indigo),
            ),
          ),

          // ── مفتاح الألوان ──
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendItem(Colors.grey.shade300, 'محجوز'),
                const SizedBox(width: 20),
                _legendItem(Colors.white, 'متاح', hasBorder: true),
                const SizedBox(width: 20),
                _legendItem(Colors.indigo, 'مختار'),
              ],
            ),
          ),

          // ── رأس الأعمدة ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 32), // رقم الصف
                ...columns.map((col) => col.isEmpty
                    ? const SizedBox(width: 16)
                    : SizedBox(
                        width: 40,
                        child: Text(col,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey)),
                      )),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // ── خريطة المقاعد ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: List.generate(totalRows, (rowIndex) {
                  final rowNum = rowIndex + 1;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // رقم الصف
                        SizedBox(
                          width: 32,
                          child: Text('$rowNum',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                        ),
                        // المقاعد A B C | D E F
                        ...columns.map((col) {
                          if (col.isEmpty) return const SizedBox(width: 16);
                          final seat = _seatLabel(rowNum, col);
                          final isReserved =
                              widget.reservedSeats.contains(seat);
                          final isSelected = _selected.contains(seat);

                          return GestureDetector(
                            onTap: isReserved
                                ? null
                                : () {
                                    setState(() {
                                      if (isSelected) {
                                        _selected.remove(seat);
                                      } else if (_selected.length <
                                          widget.quantity) {
                                        _selected.add(seat);
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                          content: Text(
                                              'يمكنك اختيار ${widget.quantity} مقعد فقط'),
                                          duration: const Duration(seconds: 2),
                                        ));
                                      }
                                    });
                                  },
                            child: Container(
                              width: 40,
                              height: 36,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: isReserved
                                    ? Colors.grey.shade300
                                    : isSelected
                                        ? Colors.indigo
                                        : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isReserved
                                      ? Colors.grey.shade400
                                      : isSelected
                                          ? Colors.indigo.shade700
                                          : Colors.grey.shade400,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Center(
                                child: isReserved
                                    ? Icon(Icons.close,
                                        size: 14, color: Colors.grey.shade600)
                                    : isSelected
                                        ? const Icon(Icons.check,
                                            size: 14, color: Colors.white)
                                        : Text(seat,
                                            style: const TextStyle(
                                                fontSize: 9,
                                                color: Colors.black54)),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),

          // ── شريط التأكيد ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, -2))
              ],
            ),
            child: Column(
              children: [
                if (_selected.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Wrap(
                      spacing: 8,
                      children: _selected
                          .map((s) => Chip(
                                label: Text(s,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                                backgroundColor: Colors.indigo,
                                padding: EdgeInsets.zero,
                              ))
                          .toList(),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _selected.length == widget.quantity
                        ? () =>
                            Navigator.pop(context, _selected.toList()..sort())
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                    ),
                    child: Text(
                      _selected.length == widget.quantity
                          ? 'تأكيد المقاعد: ${_selected.join('، ')}'
                          : 'اختر ${widget.quantity - _selected.length} مقعد أخرى',
                      style: const TextStyle(fontSize: 15),
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

  Widget _legendItem(Color color, String label, {bool hasBorder = false}) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: hasBorder ? Border.all(color: Colors.grey.shade400) : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
