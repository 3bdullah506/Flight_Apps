import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/flight_model.dart';
import '../services/firebase_service.dart';
import '../services/excel_service.dart';

class FlightsScreen extends StatelessWidget {
  const FlightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = AdminFirebaseService();
    final isWide = MediaQuery.of(context).size.width >= 700;

    return Scaffold(
      appBar: isWide
          ? AppBar(
        title: const Text('إدارة الرحلات'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.indigo,
        elevation: 0,
        actions: [
          ElevatedButton.icon(
            onPressed: () => _importFromExcel(context, service),
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Text('استيراد Excel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _showFlightDialog(context, service),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('إضافة رحلة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
        ],
      )
          : AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.indigo,
        elevation: 0,
        title: const Text('الرحلات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file, color: Colors.teal),
            tooltip: 'استيراد Excel',
            onPressed: () => _importFromExcel(context, service),
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.indigo),
            tooltip: 'إضافة رحلة',
            onPressed: () => _showFlightDialog(context, service),
          ),
        ],
      ),
      body: StreamBuilder<List<FlightModel>>(
        stream: service.getAllFlights(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final flights = snapshot.data ?? [];

          if (flights.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.flight_land, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text(
                    'لا توجد رحلات.\nأضف رحلة أو استورد من Excel.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showFlightDialog(context, service),
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة رحلة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 2,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor:
                  WidgetStateProperty.all(Colors.indigo[50]),
                  columns: const [
                    DataColumn(label: Text('رقم الرحلة', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('الانطلاق',   style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('الوجهة',     style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('التاريخ',    style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('الإقلاع',   style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('الوصول',     style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('الصعود',     style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('المدة',      style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('السعر',      style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('المقاعد',   style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('الإجراءات', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: flights.map((flight) {
                    return DataRow(cells: [
                      DataCell(Text(flight.flightNumber.isEmpty ? '-' : flight.flightNumber,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo))),
                      DataCell(Text(flight.origin)),
                      DataCell(Text(flight.destination)),
                      DataCell(Text(DateFormat('dd/MM/yyyy').format(flight.date))),
                      DataCell(Text(flight.departureTime.isEmpty ? '-' : flight.departureTime)),
                      DataCell(Text(flight.arrivalTime.isEmpty   ? '-' : flight.arrivalTime)),
                      DataCell(Text(flight.boardingTime.isEmpty  ? '-' : flight.boardingTime)),
                      DataCell(Text(flight.duration.isEmpty      ? '-' : flight.duration)),
                      DataCell(Text('\$${flight.price.toStringAsFixed(0)}')),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: flight.availableSeats == 0
                                ? Colors.red.shade50
                                : flight.availableSeats <= 5
                                ? Colors.orange.shade50
                                : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: flight.availableSeats == 0
                                  ? Colors.red
                                  : flight.availableSeats <= 5
                                  ? Colors.orange
                                  : Colors.green,
                            ),
                          ),
                          child: Text(
                            flight.availableSeats == 0
                                ? 'مكتملة'
                                : '${flight.availableSeats}/${flight.totalSeats}',
                            style: TextStyle(
                              color: flight.availableSeats == 0
                                  ? Colors.red
                                  : flight.availableSeats <= 5
                                  ? Colors.orange
                                  : Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                            tooltip: 'تعديل',
                            onPressed: () => _showFlightDialog(context, service, flight),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                            tooltip: 'حذف',
                            onPressed: () => _confirmDelete(context, service, flight.id),
                          ),
                        ],
                      )),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showFlightDialog(BuildContext context, AdminFirebaseService service,
      [FlightModel? existing]) {
    final flightNumCtrl = TextEditingController(text: existing?.flightNumber ?? '');
    final originCtrl    = TextEditingController(text: existing?.origin ?? '');
    final destCtrl      = TextEditingController(text: existing?.destination ?? '');
    final priceCtrl     = TextEditingController(text: existing?.price.toString() ?? '');
    final seatsCtrl     = TextEditingController(text: existing?.totalSeats.toString() ?? '');
    final depTimeCtrl   = TextEditingController(text: existing?.departureTime ?? '');
    final arrTimeCtrl   = TextEditingController(text: existing?.arrivalTime ?? '');
    final boardTimeCtrl = TextEditingController(text: existing?.boardingTime ?? '');
    final durationCtrl  = TextEditingController(text: existing?.duration ?? '');
    DateTime selectedDate = existing?.date ?? DateTime.now().add(const Duration(days: 7));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'إضافة رحلة جديدة' : 'تعديل الرحلة'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── الصف الأول: رقم الرحلة ──
                  TextField(
                    controller: flightNumCtrl,
                    decoration: const InputDecoration(
                      labelText: 'رقم الرحلة',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.confirmation_number),
                      hintText: 'مثال: SV123',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(
                      controller: originCtrl,
                      decoration: const InputDecoration(
                        labelText: 'مكان الانطلاق',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.flight_takeoff),
                      ),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(
                      controller: destCtrl,
                      decoration: const InputDecoration(
                        labelText: 'الوجهة',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.flight_land),
                      ),
                    )),
                  ]),
                  const SizedBox(height: 12),

                  // ── أوقات الرحلة ──
                  Row(children: [
                    Expanded(child: TextField(
                      controller: depTimeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'وقت الإقلاع',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.access_time),
                        hintText: '14:30',
                      ),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(
                      controller: arrTimeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'وقت الوصول',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.access_time_filled),
                        hintText: '18:00',
                      ),
                    )),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(
                      controller: boardTimeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'وقت الصعود',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.airline_seat_recline_normal),
                        hintText: '13:45',
                      ),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(
                      controller: durationCtrl,
                      decoration: const InputDecoration(
                        labelText: 'مدة الرحلة',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.timer),
                        hintText: '3س 30د',
                      ),
                    )),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'السعر (\$)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(
                      controller: seatsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'عدد المقاعد الكلي',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.event_seat),
                      ),
                    )),
                  ]),
                  const SizedBox(height: 12),

                  // ── اختيار التاريخ ──
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setDialogState(() => selectedDate = picked);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(children: [
                        const Icon(Icons.calendar_today, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text('التاريخ: ${DateFormat('dd/MM/yyyy').format(selectedDate)}'),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (originCtrl.text.isEmpty || destCtrl.text.isEmpty) return;
                final seats = int.tryParse(seatsCtrl.text) ?? 0;
                // عند الإضافة الجديدة: availableSeats = totalSeats
                // عند التعديل: نحافظ على الفرق (المحجوزة)
                final bookedSeats = existing == null
                    ? 0
                    : (existing.totalSeats - existing.availableSeats);
                final availableSeats = seats - bookedSeats;

                final flight = FlightModel(
                  id: existing?.id ?? '',
                  flightNumber: flightNumCtrl.text.trim(),
                  origin: originCtrl.text.trim(),
                  destination: destCtrl.text.trim(),
                  date: selectedDate,
                  departureTime: depTimeCtrl.text.trim(),
                  arrivalTime: arrTimeCtrl.text.trim(),
                  boardingTime: boardTimeCtrl.text.trim(),
                  duration: durationCtrl.text.trim(),
                  price: double.tryParse(priceCtrl.text) ?? 0,
                  totalSeats: seats,
                  availableSeats: availableSeats.clamp(0, seats),
                );
                if (existing == null) {
                  await service.addFlight(flight);
                } else {
                  await service.updateFlight(existing.id, flight.toFirestore());
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              child: Text(existing == null ? 'إضافة' : 'حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AdminFirebaseService service, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذه الرحلة؟\nلا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              await service.deleteFlight(id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _importFromExcel(BuildContext context, AdminFirebaseService service) async {
    try {
      final flights = await ExcelService.importFlights();
      if (flights.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لم يتم تحديد ملف أو الملف فارغ')),
          );
        }
        return;
      }
      await service.uploadFlightsBatch(flights);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم رفع ${flights.length} رحلة بنجاح ✓'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الاستيراد: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}