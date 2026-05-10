import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import 'package:file_picker/file_picker.dart';
import '../models/flight_model.dart';

class ExcelService {
  static Future<List<FlightModel>> importFlights() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      withData: true,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
    );

    if (result == null) return [];
    final bytes = result.files.first.bytes;
    if (bytes == null) return [];

    try {
      final decoder = SpreadsheetDecoder.decodeBytes(bytes);
      if (decoder.tables.isEmpty) return [];
      final sheet = decoder.tables.values.first;
      final List<FlightModel> flights = [];

      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        if (row.isEmpty || row.length < 5) continue;

        try {
          // الأعمدة الأساسية (A-E) — نفس ترتيب ملف Excel القديم
          final origin = row[0]?.toString().trim() ?? '';
          final destination = row[1]?.toString().trim() ?? '';
          final dateVal = row[2];
          final price = _parsePrice(row[3]);
          final seats = _parseSeats(row[4]);

          // الأعمدة الاختيارية الجديدة (F-J) — إذا لم تكن موجودة تُترك فارغة
          final flightNumber =
              row.length > 5 ? (row[5]?.toString().trim() ?? '') : '';
          final departureTime = row.length > 6 ? _parseTimeCell(row[6]) : '';
          final arrivalTime = row.length > 7 ? _parseTimeCell(row[7]) : '';
          final boardingTime = row.length > 8 ? _parseTimeCell(row[8]) : '';

          if (origin.isEmpty ||
              destination.isEmpty ||
              origin.toLowerCase() == destination.toLowerCase() ||
              price == null ||
              seats == null ||
              departureTime.isEmpty ||
              arrivalTime.isEmpty ||
              boardingTime.isEmpty ||
              !_hasLogicalTimes(departureTime, arrivalTime, boardingTime)) {
            continue;
          }

          // ── تحليل التاريخ ──
          DateTime? date;
          if (dateVal is DateTime) {
            date = dateVal;
          } else {
            final dateStr = dateVal?.toString().trim() ?? '';
            final dateParts = dateStr.split('/');

            if (dateParts.length == 3) {
              // dd/MM/yyyy
              try {
                date = DateTime(
                  int.parse(dateParts[2]),
                  int.parse(dateParts[1]),
                  int.parse(dateParts[0]),
                );
              } catch (_) {}
            } else {
              final serial = double.tryParse(dateStr);
              if (serial != null && serial > 1000) {
                // Excel serial date
                date =
                    DateTime(1899, 12, 30).add(Duration(days: serial.toInt()));
              } else if (dateStr.isNotEmpty) {
                date = DateTime.tryParse(dateStr);
              }
            }
          }

          if (date == null) {
            // ignore: avoid_print
            print('⚠️ تعذّر تحليل التاريخ في السطر $i: $dateVal');
            continue;
          }

          flights.add(FlightModel(
            id: '',
            flightNumber: flightNumber,
            origin: origin,
            destination: destination,
            date: date,
            departureTime: departureTime,
            arrivalTime: arrivalTime,
            boardingTime: boardingTime,
            duration: '',
            price: price,
            totalSeats: seats,
            availableSeats: seats,
          ));
        } catch (e) {
          // ignore: avoid_print
          print('خطأ في قراءة السطر $i: $e');
          continue;
        }
      }

      return flights;
    } catch (e) {
      // ignore: avoid_print
      print('خطأ في فك تشفير الملف: $e');
      return [];
    }
  }

  static double? _parsePrice(dynamic value) {
    final price = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString().trim() ?? '');
    if (price == null || price <= 0 || price > 100000) return null;
    return price;
  }

  static int? _parseSeats(dynamic value) {
    final seats = value is num
        ? value.toInt()
        : int.tryParse(value?.toString().trim() ?? '');
    if (seats == null || seats <= 0 || seats > 900) return null;
    return seats;
  }

  static String _parseTimeCell(dynamic value) {
    if (value == null) return '';
    if (value is DateTime) {
      return _formatMinutes(value.hour * 60 + value.minute);
    }
    if (value is num) {
      final fraction = value - value.floor();
      if (fraction > 0 && fraction < 1) {
        return _formatMinutes((fraction * 24 * 60).round());
      }
    }

    final text = value.toString().trim();
    final minutes = FlightModel.parseClockMinutes(text);
    if (minutes != null) return _formatMinutes(minutes);

    final parts = text.split(RegExp(r'[:.]'));
    if (parts.length == 2) {
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour != null &&
          minute != null &&
          hour >= 0 &&
          hour <= 23 &&
          minute >= 0 &&
          minute <= 59) {
        return _formatMinutes(hour * 60 + minute);
      }
    }

    return '';
  }

  static bool _hasLogicalTimes(
    String departureTime,
    String arrivalTime,
    String boardingTime,
  ) {
    final departure = FlightModel.parseClockMinutes(departureTime);
    final arrival = FlightModel.parseClockMinutes(arrivalTime);
    final boarding = FlightModel.parseClockMinutes(boardingTime);
    if (departure == null || arrival == null || boarding == null) return false;

    final dayMinutes = const Duration(days: 1).inMinutes;
    final duration = (arrival - departure) % dayMinutes;
    final beforeDeparture = (departure - boarding) % dayMinutes;
    return duration > 0 &&
        duration <= const Duration(hours: 18).inMinutes &&
        beforeDeparture > 0 &&
        beforeDeparture <= const Duration(hours: 6).inMinutes;
  }

  static String _formatMinutes(int minutes) {
    final normalized = minutes % const Duration(days: 1).inMinutes;
    final hour = (normalized ~/ 60).toString().padLeft(2, '0');
    final minute = (normalized % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// نموذج ملف Excel المطلوب:
  /// A: مكان الانطلاق   مثال: القاهرة
  /// B: الوجهة          مثال: دبي
  /// C: التاريخ         مثال: 15/08/2026
  /// D: السعر           مثال: 350
  /// E: عدد المقاعد     مثال: 50
  /// F: رقم الرحلة (اختياري)    مثال: SV123
  /// G: وقت الإقلاع (اختياري)   مثال: 14:30
  /// H: وقت الوصول (اختياري)    مثال: 18:00
  /// I: وقت الصعود (اختياري)    مثال: 13:45
  /// J: مدة الرحلة (اختياري)    مثال: 3س 30د
}
