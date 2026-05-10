import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/flight_model.dart';
import '../services/firebase_service.dart';
import '../services/local_db_service.dart';
import '../services/sync_service.dart';
import '../services/excel_service.dart';

/// ── النسخة 1: تخزين محلي + مزامنة ──
class FlightsScreen extends StatefulWidget {
  const FlightsScreen({super.key});
  @override
  State<FlightsScreen> createState() => _FlightsScreenState();
}

class _FlightsScreenState extends State<FlightsScreen> {
  final SyncService _sync = SyncService();
  List<FlightModel> _flights = [];
  StreamSubscription<bool>? _onlineSub;
  bool _isOnline = false;
  bool _loading = true;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _isOnline = _sync.isOnline;
    _onlineSub = _sync.onlineStream.listen((online) {
      if (!mounted) return;
      setState(() => _isOnline = online);
      _refreshFlights();
    });
    _sync.startMonitoring();
    _loadFlights();
    if (_isOnline) {
      _refreshFlights();
    }
  }

  @override
  void dispose() {
    _onlineSub?.cancel();
    super.dispose();
  }

  Future<void> _loadFlights() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final flights = await LocalDbService.getAllFlights();
      final pending = await LocalDbService.getPendingOperations();
      if (!mounted) return;
      if (mounted) {
        setState(() {
          _flights = flights;
          _pendingCount = pending.length;
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      if (mounted) {
        setState(() => _loading = false);
        _showSnack('تعذر قراءة البيانات المحلية', Colors.red);
      }
    }
  }

  Future<void> _refreshFlights({bool silent = true}) async {
    if (!mounted) return;
    try {
      if (_isOnline) {
        // إذا متصل: نجلب من Firebase ونحدّث التخزين المحلي
        final firebase = AdminFirebaseService();
        final live = await firebase.getFlightsOnce();
        await LocalDbService.syncFromFirebase(live);
        if (!mounted) return;
      }
    } catch (_) {
      if (!mounted) return;
      if (mounted) {
        setState(() => _isOnline = false);
        if (!silent) {
          _showSnack(
              'تعذر الاتصال بالخادم، تم عرض البيانات المحلية', Colors.orange);
        }
      }
    }
    if (!mounted) return;
    await _loadFlights();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الرحلات'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.indigo,
        elevation: 0,
        actions: [
          // ── مؤشر الاتصال ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              Icon(
                _isOnline ? Icons.cloud_done : Icons.cloud_off,
                color: _isOnline ? Colors.green : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 4),
              Text(
                _isOnline ? 'متصل' : 'غير متصل',
                style: TextStyle(
                  color: _isOnline ? Colors.green : Colors.red,
                  fontSize: 12,
                ),
              ),
              if (_pendingCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$_pendingCount معلّقة',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ],
            ]),
          ),
          // ── زر مزامنة يدوية ──
          if (_isOnline && _pendingCount > 0)
            IconButton(
              icon: const Icon(Icons.sync, color: Colors.indigo),
              tooltip: 'مزامنة الآن',
              onPressed: () async {
                try {
                  final count = await _sync.syncPendingOperations();
                  if (mounted) {
                    _showSnack('تمت مزامنة $count عملية ✓', Colors.green);
                    _loadFlights();
                  }
                } catch (_) {
                  if (mounted) {
                    _showSnack('تعذرت المزامنة، سيتم إعادة المحاولة لاحقاً',
                        Colors.red);
                  }
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.upload_file, color: Colors.teal),
            tooltip: 'استيراد Excel',
            onPressed: () => _importFromExcel(context),
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.indigo),
            tooltip: 'إضافة رحلة',
            onPressed: () => _showFlightDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _flights.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.flight_land,
                          size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text('لا توجد رحلات',
                          style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _showFlightDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة رحلة'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _refreshFlights(silent: false),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Card(
                      elevation: 2,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor:
                              WidgetStateProperty.all(Colors.indigo[50]),
                          columns: const [
                            DataColumn(
                                label: Text('رقم الرحلة',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            DataColumn(
                                label: Text('الانطلاق',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            DataColumn(
                                label: Text('الوجهة',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            DataColumn(
                                label: Text('التاريخ',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            DataColumn(
                                label: Text('الإقلاع',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            DataColumn(
                                label: Text('الوصول',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            DataColumn(
                                label: Text('السعر',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            DataColumn(
                                label: Text('المقاعد',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            DataColumn(
                                label: Text('المصدر',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            DataColumn(
                                label: Text('الإجراءات',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                          ],
                          rows: _flights.map((flight) {
                            return DataRow(cells: [
                              DataCell(Text(
                                  flight.flightNumber.isEmpty
                                      ? '-'
                                      : flight.flightNumber,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo))),
                              DataCell(Text(flight.origin)),
                              DataCell(Text(flight.destination)),
                              DataCell(Text(DateFormat('dd/MM/yyyy')
                                  .format(flight.date))),
                              DataCell(Text(flight.departureTime.isEmpty
                                  ? '-'
                                  : flight.departureTime)),
                              DataCell(Text(flight.arrivalTime.isEmpty
                                  ? '-'
                                  : flight.arrivalTime)),
                              DataCell(
                                  Text('\$${flight.price.toStringAsFixed(0)}')),
                              DataCell(_seatsWidget(flight)),
                              // مؤشر: هل الرحلة محلية فقط أم مرفوعة
                              DataCell(Icon(
                                _isOnline
                                    ? Icons.cloud_done
                                    : Icons.phone_android,
                                color: _isOnline ? Colors.green : Colors.orange,
                                size: 18,
                              )),
                              DataCell(Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blue, size: 20),
                                    onPressed: () =>
                                        _showFlightDialog(context, flight),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red, size: 20),
                                    onPressed: () =>
                                        _confirmDelete(context, flight.id),
                                  ),
                                ],
                              )),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _seatsWidget(FlightModel flight) {
    Color c = flight.availableSeats == 0
        ? Colors.red
        : flight.availableSeats <= 5
            ? Colors.orange
            : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c),
      ),
      child: Text(
        flight.availableSeats == 0
            ? 'مكتملة'
            : '${flight.availableSeats}/${flight.totalSeats}',
        style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  void _showFlightDialog(BuildContext context, [FlightModel? existing]) {
    final flightNumCtrl =
        TextEditingController(text: existing?.flightNumber ?? '');
    final originCtrl = TextEditingController(text: existing?.origin ?? '');
    final destCtrl = TextEditingController(text: existing?.destination ?? '');
    final priceCtrl =
        TextEditingController(text: existing?.price.toString() ?? '');
    final seatsCtrl =
        TextEditingController(text: existing?.totalSeats.toString() ?? '');
    final depTimeCtrl =
        TextEditingController(text: existing?.departureTime ?? '');
    final arrTimeCtrl =
        TextEditingController(text: existing?.arrivalTime ?? '');
    final boardTimeCtrl =
        TextEditingController(text: existing?.boardingTime ?? '');
    final durationCtrl = TextEditingController(text: existing?.duration ?? '');
    DateTime selectedDate =
        existing?.date ?? DateTime.now().add(const Duration(days: 7));

    void updateDuration() {
      final departure = _parseTimeOfDay(depTimeCtrl.text);
      final arrival = _parseTimeOfDay(arrTimeCtrl.text);
      durationCtrl.text = departure == null || arrival == null
          ? ''
          : _flightDurationLabel(departure, arrival);
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'إضافة رحلة جديدة' : 'تعديل الرحلة'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: flightNumCtrl,
                    decoration: const InputDecoration(
                        labelText: 'رقم الرحلة',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.confirmation_number),
                        hintText: 'SV123')),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: originCtrl,
                          decoration: const InputDecoration(
                              labelText: 'مكان الانطلاق',
                              border: OutlineInputBorder()))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextField(
                          controller: destCtrl,
                          decoration: const InputDecoration(
                              labelText: 'الوجهة',
                              border: OutlineInputBorder()))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: depTimeCtrl,
                          readOnly: true,
                          onTap: () async {
                            await _pickTime(ctx, depTimeCtrl);
                            updateDuration();
                            setDialogState(() {});
                          },
                          decoration: const InputDecoration(
                              labelText: 'وقت الإقلاع',
                              border: OutlineInputBorder(),
                              hintText: '14:30'))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextField(
                          controller: arrTimeCtrl,
                          readOnly: true,
                          onTap: () async {
                            await _pickTime(ctx, arrTimeCtrl);
                            updateDuration();
                            setDialogState(() {});
                          },
                          decoration: const InputDecoration(
                              labelText: 'وقت الوصول',
                              border: OutlineInputBorder(),
                              hintText: '18:00'))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: boardTimeCtrl,
                          readOnly: true,
                          onTap: () async {
                            await _pickTime(ctx, boardTimeCtrl);
                            setDialogState(() {});
                          },
                          decoration: const InputDecoration(
                              labelText: 'وقت الصعود',
                              border: OutlineInputBorder(),
                              hintText: '13:45'))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextField(
                          controller: durationCtrl,
                          readOnly: true,
                          decoration: const InputDecoration(
                              labelText: 'مدة الرحلة',
                              border: OutlineInputBorder(),
                              hintText: '3س 30د'))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}$'),
                            ),
                          ],
                          decoration: const InputDecoration(
                              labelText: 'السعر (\$)',
                              border: OutlineInputBorder()))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextField(
                          controller: seatsCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                              labelText: 'عدد المقاعد',
                              border: OutlineInputBorder()))),
                ]),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)));
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4)),
                    child: Row(children: [
                      const Icon(Icons.calendar_today, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                          'التاريخ: ${DateFormat('dd/MM/yyyy').format(selectedDate)}'),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white),
              onPressed: () async {
                final validationError = _validateFlightInput(
                  flightNumber: flightNumCtrl.text,
                  origin: originCtrl.text,
                  destination: destCtrl.text,
                  date: selectedDate,
                  departureTime: depTimeCtrl.text,
                  arrivalTime: arrTimeCtrl.text,
                  boardingTime: boardTimeCtrl.text,
                  priceText: priceCtrl.text,
                  seatsText: seatsCtrl.text,
                  existing: existing,
                );
                if (validationError != null) {
                  _showSnack(validationError, Colors.red);
                  return;
                }
                final seats = int.tryParse(seatsCtrl.text) ?? 0;
                final price = double.tryParse(priceCtrl.text) ?? 0;
                final bookedSeats = existing == null
                    ? 0
                    : (existing.totalSeats - existing.availableSeats);
                updateDuration();
                final id = existing?.id ??
                    DateTime.now().millisecondsSinceEpoch.toString();
                final flight = FlightModel(
                  id: id,
                  flightNumber: flightNumCtrl.text.trim(),
                  origin: originCtrl.text.trim(),
                  destination: destCtrl.text.trim(),
                  date: selectedDate,
                  departureTime: depTimeCtrl.text.trim(),
                  arrivalTime: arrTimeCtrl.text.trim(),
                  boardingTime: boardTimeCtrl.text.trim(),
                  duration: durationCtrl.text.trim(),
                  price: price,
                  totalSeats: seats,
                  availableSeats: (seats - bookedSeats).clamp(0, seats),
                );
                if (existing == null) {
                  await LocalDbService.addFlight(flight);
                } else {
                  await LocalDbService.updateFlight(existing.id, flight);
                }
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                _loadFlights();
              },
              child: Text(existing == null ? 'إضافة' : 'حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذه الرحلة؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await LocalDbService.deleteFlight(id);
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              _loadFlights();
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _importFromExcel(BuildContext context) async {
    try {
      final flights = await ExcelService.importFlights();
      if (flights.isEmpty) return;
      for (final f in flights) {
        final withId = FlightModel(
          id: DateTime.now().millisecondsSinceEpoch.toString() +
              flights.indexOf(f).toString(),
          flightNumber: f.flightNumber,
          origin: f.origin,
          destination: f.destination,
          date: f.date,
          departureTime: f.departureTime,
          arrivalTime: f.arrivalTime,
          boardingTime: f.boardingTime,
          duration: f.duration,
          price: f.price,
          totalSeats: f.totalSeats,
          availableSeats: f.availableSeats,
        );
        await LocalDbService.addFlight(withId);
      }
      _loadFlights();
      if (context.mounted) {
        _showSnack('تم حفظ ${flights.length} رحلة محلياً ✓', Colors.green);
      }
    } catch (e) {
      if (context.mounted) {
        _showSnack('خطأ: $e', Colors.red);
      }
    }
  }

  Future<void> _pickTime(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final initial = _parseTimeOfDay(controller.text) ?? TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null) return;
    controller.text = _formatTimeOfDay(picked);
  }

  TimeOfDay? _parseTimeOfDay(String value) {
    final minutes = FlightModel.parseClockMinutes(value);
    if (minutes == null) return null;
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  String _formatTimeOfDay(TimeOfDay value) {
    final h = value.hour.toString().padLeft(2, '0');
    final m = value.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _flightDurationLabel(TimeOfDay departure, TimeOfDay arrival) {
    final departureMinutes = departure.hour * 60 + departure.minute;
    final arrivalMinutes = arrival.hour * 60 + arrival.minute;
    final durationMinutes =
        (arrivalMinutes - departureMinutes) % const Duration(days: 1).inMinutes;
    return FlightModel.formatDurationMinutes(durationMinutes);
  }

  String? _validateFlightInput({
    required String flightNumber,
    required String origin,
    required String destination,
    required DateTime date,
    required String departureTime,
    required String arrivalTime,
    required String boardingTime,
    required String priceText,
    required String seatsText,
    required FlightModel? existing,
  }) {
    final cleanFlightNumber = flightNumber.trim();
    final cleanOrigin = origin.trim();
    final cleanDestination = destination.trim();
    final today = DateUtils.dateOnly(DateTime.now());
    final flightDate = DateUtils.dateOnly(date);

    if (cleanFlightNumber.isEmpty) return 'رقم الرحلة مطلوب';
    if (!RegExp(r'^[A-Za-z]{2,3}\d{1,4}$').hasMatch(cleanFlightNumber)) {
      return 'رقم الرحلة يجب أن يكون مثل SV123';
    }
    if (cleanOrigin.length < 2) return 'مكان الانطلاق غير صحيح';
    if (cleanDestination.length < 2) return 'الوجهة غير صحيحة';
    if (cleanOrigin.toLowerCase() == cleanDestination.toLowerCase()) {
      return 'مكان الانطلاق والوجهة لا يمكن أن يكونا نفس المكان';
    }
    if (flightDate.isBefore(today)) {
      return 'تاريخ الرحلة لا يمكن أن يكون في الماضي';
    }

    final departure = FlightModel.parseClockMinutes(departureTime);
    final arrival = FlightModel.parseClockMinutes(arrivalTime);
    final boarding = FlightModel.parseClockMinutes(boardingTime);
    if (departure == null) return 'وقت الإقلاع مطلوب وبصيغة صحيحة HH:mm';
    if (arrival == null) return 'وقت الوصول مطلوب وبصيغة صحيحة HH:mm';
    if (boarding == null) return 'وقت الصعود مطلوب وبصيغة صحيحة HH:mm';

    final duration = (arrival - departure) % const Duration(days: 1).inMinutes;
    if (duration == 0) return 'وقت الوصول يجب أن يختلف عن وقت الإقلاع';
    if (duration > const Duration(hours: 18).inMinutes) {
      return 'مدة الرحلة غير منطقية، راجع وقت الإقلاع والوصول';
    }

    final minutesBeforeDeparture =
        (departure - boarding) % const Duration(days: 1).inMinutes;
    if (minutesBeforeDeparture == 0) {
      return 'وقت الصعود يجب أن يكون قبل وقت الإقلاع';
    }
    if (minutesBeforeDeparture > const Duration(hours: 6).inMinutes) {
      return 'وقت الصعود بعيد جدًا عن وقت الإقلاع';
    }

    final price = double.tryParse(priceText.trim());
    if (price == null || price <= 0) {
      return 'السعر يجب أن يكون رقمًا أكبر من صفر';
    }
    if (price > 100000) return 'السعر غير منطقي';

    final seats = int.tryParse(seatsText.trim());
    if (seats == null || seats <= 0) {
      return 'عدد المقاعد يجب أن يكون رقمًا صحيحًا أكبر من صفر';
    }
    if (seats > 900) return 'عدد المقاعد غير منطقي';

    if (existing != null) {
      final bookedSeats = existing.totalSeats - existing.availableSeats;
      if (seats < bookedSeats) {
        return 'عدد المقاعد لا يمكن أن يكون أقل من المقاعد المحجوزة ($bookedSeats)';
      }
    }

    return null;
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }
}
