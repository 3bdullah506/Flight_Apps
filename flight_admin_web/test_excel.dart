import 'dart:io';
import 'package:excel/excel.dart';

void main() {
  try {
    var file = 'd:/Desktop/1 - 4th level apps/4th Level/2nd semester/Mobile Application Development/flight_booking_system/flight_projects/flights_sample.xlsx';
    var bytes = File(file).readAsBytesSync();
    var excel = Excel.decodeBytes(bytes);
    print('Tables: ${excel.tables.keys}');
    
    var sheet = excel.tables.values.first;
    print('Rows: ${sheet.rows.length}');
    
    for (int i = 1; i < sheet.rows.length; i++) {
      var row = sheet.rows[i];
      print('Row $i: ${row.map((e) => e?.value).toList()}');
    }
  } catch (e, stack) {
    print('Error: $e');
    print(stack);
  }
}
