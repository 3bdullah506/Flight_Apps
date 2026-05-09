import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../services/firebase_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';


class PdfService {
  static Future<void> generateTicket({required OrderModel order}) async {
    final pdf = pw.Document();

    // تحميل الخطوط العربية فقط
    final arabicFont = await PdfGoogleFonts.amiriRegular();
    final arabicFontBold = await PdfGoogleFonts.amiriBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: arabicFont,
          bold: arabicFontBold,
        ),
        build: (pw.Context context) {
          return [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                children: [
                  // --- الجزء العلوي (Header) ---
                  pw.Container(
                    padding: const pw.EdgeInsets.all(20),
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.blueAccent700,
                      borderRadius: pw.BorderRadius.only(
                        topLeft: pw.Radius.circular(15),
                        topRight: pw.Radius.circular(15),
                      ),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('تذكرة صعود الطائرة', 
                                style: pw.TextStyle(color: PdfColors.white, fontSize: 22, fontWeight: pw.FontWeight.bold)),
                            pw.Text('BOARDING PASS', 
                                style: const pw.TextStyle(color: PdfColor.fromInt(0xFFE0E0E0), fontSize: 12)),
                          ],
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            borderRadius: pw.BorderRadius.circular(5),
                          ),
                         ),
                      ],
                    ),
                  ),

                  // --- تفاصيل الرحلة الأساسية (الوجهة) ---
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                    decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFF8F9FA),
                      border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 1, style: pw.BorderStyle.dashed)),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        _buildCityInfo('مـن / FROM', order.origin, arabicFontBold),
                        pw.Column(children: [
                          pw.Text('<', style: pw.TextStyle(fontSize: 20, color: PdfColors.blueAccent700, fontWeight: pw.FontWeight.bold)),
                          pw.Container(width: 80, height: 1.5, color: PdfColors.blueAccent700),
                        ]),
                        _buildCityInfo('إلـى / TO', order.destination, arabicFontBold),
                      ],
                    ),
                  ),

                  // --- شبكة البيانات الكاملة (13 حقل) ---
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(20),
                    child: pw.Wrap(
                      spacing: 15,
                      runSpacing: 20,
                      children: [
                        _infoItem('اسم العميل', order.userName, width: 180),
                        _infoItem('رقم الرحلة', order.flightNumber),
                        _infoItem('تاريخ الرحلة', DateFormat('dd/MM/yyyy').format(order.flightDate)),
                        _infoItem('وقت الإقلاع', order.departureTime),
                        _infoItem('وقت الوصول', order.arrivalTime),
                        _infoItem('وقت الصعود', order.boardingTime),
                        _infoItem('مدة الرحلة', order.duration),
                        _infoItem('رقم المقعد', order.seatNumber, isSpecial: true),
                        _infoItem('السعر', '\$${order.price.toStringAsFixed(0)}'),
                        _infoItem('تاريخ الحجز', DateFormat('dd/MM/yyyy').format(order.createdAt)),
                        _infoItem('البريد', order.userEmail, width: 150),
                        _infoItem('الهاتف', order.userPhone),
                        _infoItem('رقم الجواز', order.passportNumber),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 20),

                  // --- الجزء السفلي (Barcode & Footer) ---
                  pw.Container(
                    padding: const pw.EdgeInsets.all(15),
                    decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFEEEEEE),
                      borderRadius: pw.BorderRadius.only(
                        bottomLeft: pw.Radius.circular(15),
                        bottomRight: pw.Radius.circular(15),
                      ),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('رقم الحجز (Booking ID)', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                            pw.Text(order.bookingId, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                        pw.BarcodeWidget(
                          barcode: pw.Barcode.code128(),
                          data: order.bookingId,
                          width: 120,
                          height: 40,
                          drawText: false,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static pw.Widget _buildCityInfo(String label, String city, pw.Font boldFont) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
        pw.SizedBox(height: 5),
        pw.Text(city, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, font: boldFont)),
      ],
    );
  }

  static pw.Widget _infoItem(String label, String value, {double width = 85, bool isSpecial = false}) {
    return pw.SizedBox(
      width: width,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: isSpecial ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isSpecial ? PdfColors.red800 : PdfColors.black,
            ),
          ),
          pw.Container(height: 1, width: 40, color: PdfColors.grey200), // خط زخرفي تحت الحقل
        ],
      ),
    );
  }
}
class OrderTrackingScreen extends StatelessWidget {
  const OrderTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return StreamBuilder<List<OrderModel>>(
      stream: FirebaseService().getUserOrders(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final orders = snapshot.data ?? [];
        if (orders.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text('لا توجد حجوزات بعد',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) =>
              _buildOrderSummaryCard(context, orders[index]),
        );
      },
    );
  }
  Widget _buildOrderSummaryCard(BuildContext context, OrderModel order) {
    final status = _statusStyle(order.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showOrderDetails(context, order),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '# ${order.bookingId}',
                      style: TextStyle(color: Colors.grey[700], fontSize: 12),
                    ),
                  ),
                  _statusBadge(status),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.origin,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward, color: Colors.grey),
                  ),
                  Expanded(
                    child: Text(
                      order.destination,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _summaryChip(
                    Icons.calendar_today,
                    DateFormat('dd/MM/yyyy').format(order.flightDate),
                  ),
                  if (order.departureTime.isNotEmpty)
                    _summaryChip(Icons.flight_takeoff, order.departureTime),
                  _summaryChip(
                    Icons.event_seat,
                    'مقعد ${_displayText(order.seatNumber)}',
                  ),
                  _summaryChip(
                    Icons.attach_money,
                    '\$${order.price.toStringAsFixed(0)}',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'عرض التفاصيل',
                    style: TextStyle(
                      color: Colors.indigo.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right,
                      color: Colors.indigo.shade700, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOrderDetails(BuildContext context, OrderModel order) {
    final status = _statusStyle(order.status);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.85;

        return Directionality(
          textDirection: ui.TextDirection.rtl,
          child: SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'تفاصيل الطلب',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '# ${order.bookingId}',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        _statusBadge(status),
                      ],
                    ),
                    const Divider(height: 24),
                    _detailRow(
                      Icons.route,
                      'المسار',
                      '${order.origin} → ${order.destination}',
                    ),
                    _detailRow(
                      Icons.confirmation_number,
                      'رقم الرحلة',
                      _displayText(order.flightNumber),
                    ),
                    _detailRow(
                      Icons.calendar_today,
                      'تاريخ الرحلة',
                      DateFormat('dd/MM/yyyy').format(order.flightDate),
                    ),
                    _detailRow(
                      Icons.flight_takeoff,
                      'وقت الإقلاع',
                      _displayText(order.departureTime),
                    ),
                    _detailRow(
                      Icons.flight_land,
                      'وقت الوصول',
                      _displayText(order.arrivalTime),
                    ),
                    _detailRow(
                      Icons.airline_seat_recline_normal,
                      'وقت الصعود',
                      _displayText(order.boardingTime),
                    ),
                    _detailRow(
                      Icons.timer,
                      'مدة الرحلة',
                      _displayText(order.duration),
                    ),
                    _detailRow(
                      Icons.event_seat,
                      'رقم المقعد',
                      _displayText(order.seatNumber),
                    ),
                    _detailRow(
                      Icons.attach_money,
                      'السعر',
                      '\$${order.price.toStringAsFixed(0)}',
                    ),
                    _detailRow(
                      Icons.access_time,
                      'تاريخ الحجز',
                      DateFormat('dd/MM/yyyy').format(order.createdAt),
                    ),
                    _detailRow(
                      Icons.person,
                      'اسم العميل',
                      _displayText(order.userName),
                    ),
                    _detailRow(
                      Icons.email,
                      'البريد',
                      _displayText(order.userEmail),
                    ),
                    _detailRow(
                      Icons.phone,
                      'الهاتف',
                      _displayText(order.userPhone),
                    ),
                    _detailRow(
                      Icons.badge,
                      'رقم الجواز',
                      _displayText(order.passportNumber),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: status.color.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: status.color.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        status.note,
                        style: TextStyle(color: status.color, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      // onPressed: () => generateOrderPdf(order),
                      onPressed: () => PdfService.generateTicket(order: order), // استدعاء دالة الـ PDF
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                      label: const Text(
                        'تصدير تفاصيل الطلب PDF',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _statusBadge(_OrderStatusStyle status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: status.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, color: status.color, size: 16),
          const SizedBox(width: 5),
          Text(
            status.text,
            style: TextStyle(
              color: status.color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(value, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 7),
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  _OrderStatusStyle _statusStyle(String status) {
    switch (status) {
      case 'approved':
        return const _OrderStatusStyle(
          color: Colors.green,
          icon: Icons.check_circle,
          text: 'مقبول',
          note: 'تم تأكيد حجزك. يرجى الحضور قبل موعد الصعود.',
        );
      case 'rejected':
        return const _OrderStatusStyle(
          color: Colors.red,
          icon: Icons.cancel,
          text: 'مرفوض',
          note: 'تعذّر قبول طلبك. يرجى التواصل مع الدعم.',
        );
      default:
        return const _OrderStatusStyle(
          color: Colors.orange,
          icon: Icons.hourglass_empty,
          text: 'قيد المراجعة',
          note: 'طلبك قيد المراجعة من قبل الإدارة.',
        );
    }
  }

  String _displayText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? 'غير محدد' : trimmed;
  }
}

class _OrderStatusStyle {
  final Color color;
  final IconData icon;
  final String text;
  final String note;

  const _OrderStatusStyle({
    required this.color,
    required this.icon,
    required this.text,
    required this.note,
  });
}
