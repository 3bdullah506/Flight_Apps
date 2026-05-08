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
          final origin      = row[0]?.toString().trim() ?? '';
          final destination = row[1]?.toString().trim() ?? '';
          final dateVal     = row[2];
          final price       = double.tryParse(row[3]?.toString() ?? '0') ?? 0.0;
          final seats       = int.tryParse(row[4]?.toString() ?? '0') ?? 0;

          // الأعمدة الاختيارية الجديدة (F-J) — إذا لم تكن موجودة تُترك فارغة
          final flightNumber  = row.length > 5  ? (row[5]?.toString().trim()  ?? '') : '';
          final departureTime = row.length > 6  ? (row[6]?.toString().trim()  ?? '') : '';
          final arrivalTime   = row.length > 7  ? (row[7]?.toString().trim()  ?? '') : '';
          final boardingTime  = row.length > 8  ? (row[8]?.toString().trim()  ?? '') : '';
          final duration      = row.length > 9  ? (row[9]?.toString().trim()  ?? '') : '';

          if (origin.isEmpty || destination.isEmpty) continue;

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
                date = DateTime(1899, 12, 30).add(Duration(days: serial.toInt()));
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
            id:            '',
            flightNumber:  flightNumber,
            origin:        origin,
            destination:   destination,
            date:          date,
            departureTime: departureTime,
            arrivalTime:   arrivalTime,
            boardingTime:  boardingTime,
            duration:      duration,
            price:         price,
            totalSeats:    seats,
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