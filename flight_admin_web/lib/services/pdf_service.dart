import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PdfService {
  /// إنشاء تذكرة احترافية لحجز واحد
  static Future<void> generateTicket({
    required Map<String, dynamic> order,
  }) async {
    final fontBase = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: fontBase, bold: fontBold),
    );

    final String bookingId =
        order['bookingId']?.toString() ?? 'BK-${order['id']}';
    final String passenger = order['userName']?.toString() ?? 'غير معروف';
    final String email = order['userEmail']?.toString() ?? '';
    final String phone = order['userPhone']?.toString() ?? '';
    final String passport = order['passportNumber']?.toString() ?? '';
    final String flightNum = order['flightNumber']?.toString() ?? '-';
    final String origin = order['origin']?.toString() ?? '';
    final String destination = order['destination']?.toString() ?? '';
    final String depTime = order['departureTime']?.toString() ?? '-';
    final String arrTime = order['arrivalTime']?.toString() ?? '-';
    final String boardTime = order['boardingTime']?.toString() ?? '-';
    final String duration = order['duration']?.toString() ?? '-';
    final String seatNum = order['seatNumber']?.toString() ?? '-';
    final double price = (order['price'] as num?)?.toDouble() ?? 0;

    String flightDateStr = '';
    try {
      flightDateStr =
          DateFormat('dd/MM/yyyy').format(order['flightDate'].toDate());
    } catch (_) {}

    String createdStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    String statusText;
    PdfColor statusColor;
    switch (order['status']) {
      case 'approved':
        statusText = 'مؤكد ✓';
        statusColor = PdfColors.green700;
        break;
      case 'rejected':
        statusText = 'مرفوض';
        statusColor = PdfColors.red700;
        break;
      default:
        statusText = 'قيد المراجعة';
        statusColor = PdfColors.orange700;
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(0),
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // ══════════ HEADER ══════════
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                color: PdfColors.indigo900,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('تذكرة طيران إلكترونية',
                            style: pw.TextStyle(
                                fontSize: 22,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white)),
                        pw.SizedBox(height: 4),
                        pw.Text('رقم الحجز: $bookingId',
                            style: const pw.TextStyle(
                                color: PdfColors.white, fontSize: 11)),
                        pw.Text('تاريخ الإصدار: $createdStr',
                            style: const pw.TextStyle(
                                color: PdfColors.white, fontSize: 11)),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: statusColor,
                        borderRadius: pw.BorderRadius.circular(20),
                      ),
                      child: pw.Text(statusText,
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 13)),
                    ),
                  ],
                ),
              ),

              // ══════════ ROUTE BANNER ══════════
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                color: PdfColors.indigo50,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    // المدينة الأولى
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(origin,
                            style: pw.TextStyle(
                                fontSize: 28,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.indigo900)),
                        pw.Text(depTime,
                            style: const pw.TextStyle(
                                fontSize: 16, color: PdfColors.indigo700)),
                        pw.Text(flightDateStr,
                            style: const pw.TextStyle(
                                fontSize: 11, color: PdfColors.grey600)),
                      ],
                    ),
                    // السهم والمدة
                    pw.Column(
                      children: [
                        pw.Text('✈',
                            style: const pw.TextStyle(
                                fontSize: 24, color: PdfColors.indigo400)),
                        pw.SizedBox(height: 4),
                        pw.Text(duration,
                            style: const pw.TextStyle(
                                fontSize: 10, color: PdfColors.grey600)),
                        pw.Text('رقم الرحلة: $flightNum',
                            style: const pw.TextStyle(
                                fontSize: 10, color: PdfColors.grey600)),
                      ],
                    ),
                    // المدينة الثانية
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(destination,
                            style: pw.TextStyle(
                                fontSize: 28,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.indigo900)),
                        pw.Text(arrTime,
                            style: const pw.TextStyle(
                                fontSize: 16, color: PdfColors.indigo700)),
                        pw.SizedBox(height: 14),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 32),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // ══ بيانات الراكب ══
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _sectionTitle('بيانات الراكب'),
                          _infoRow('الاسم الكامل', passenger),
                          _infoRow('البريد الإلكتروني', email),
                          _infoRow('رقم الهاتف', phone.isEmpty ? '-' : phone),
                          _infoRow('رقم الهوية / الجواز',
                              passport.isEmpty ? '-' : passport),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 24),
                    // ══ بيانات الحجز ══
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _sectionTitle('بيانات الحجز'),
                          _infoRow('رقم المقعد', seatNum),
                          _infoRow('وقت الصعود للطائرة', boardTime),
                          _infoRow(
                              'سعر التذكرة', '\$${price.toStringAsFixed(2)}'),
                          _infoRow('رقم الحجز', bookingId),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // ══ تذكير المطار ══
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 32),
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.amber50,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.amber700),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('⚠  تعليمات المطار',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.amber900,
                              fontSize: 12)),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        '• يُرجى الحضور للمطار قبل موعد الإقلاع بساعتين على الأقل.\n'
                        '• وقت الصعود للطائرة: $boardTime — التأخر يعني فقدان المقعد.\n'
                        '• احضر هويتك الوطنية أو جواز سفرك الساري.',
                        style: const pw.TextStyle(
                            fontSize: 10, color: PdfColors.brown),
                      ),
                    ],
                  ),
                ),
              ),

              pw.Spacer(),

              // ══════════ FOOTER ══════════
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                color: PdfColors.grey100,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('شكراً لاختياركم رحلاتنا',
                        style: const pw.TextStyle(
                            color: PdfColors.grey600, fontSize: 10)),
                    pw.Text('هذه التذكرة صادرة إلكترونياً ولا تحتاج إلى ختم',
                        style: const pw.TextStyle(
                            color: PdfColors.grey600, fontSize: 10)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'تذكرة_$bookingId.pdf',
    );
  }

  // ── فاتورة متعددة (للاستخدام من invoice_screen) ──
  static Future<void> generateInvoice({
    required String invoiceNumber,
    required String customerName,
    required String customerEmail,
    required List<Map<String, dynamic>> orders,
  }) async {
    final fontBase = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: fontBase, bold: fontBold),
    );

    double total =
        orders.fold(0.0, (sum, o) => sum + (o['price'] as num).toDouble());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: const pw.BoxDecoration(color: PdfColors.indigo),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('فاتورة حجز تذاكر الطيران',
                        style: pw.TextStyle(
                            fontSize: 22,
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 6),
                    pw.Text('رقم الفاتورة: $invoiceNumber',
                        style: const pw.TextStyle(color: PdfColors.white)),
                    pw.Text(
                        'التاريخ: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                        style: const pw.TextStyle(color: PdfColors.white)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('بيانات العميل',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              pw.Text('الاسم: $customerName'),
              pw.Text('البريد الإلكتروني: $customerEmail'),
              pw.SizedBox(height: 20),
              pw.Text('تفاصيل الحجوزات',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _cell('المسار', isHeader: true),
                      _cell('التاريخ', isHeader: true),
                      _cell('السعر', isHeader: true),
                      _cell('الحالة', isHeader: true)
                    ],
                  ),
                  ...orders.map((order) {
                    String dateStr = '';
                    try {
                      dateStr = DateFormat('dd/MM/yyyy')
                          .format(order['flightDate'].toDate());
                    } catch (_) {}
                    String st = order['status'] == 'approved'
                        ? 'مقبول'
                        : order['status'] == 'rejected'
                            ? 'مرفوض'
                            : 'قيد المراجعة';
                    return pw.TableRow(children: [
                      _cell('${order['origin']} → ${order['destination']}'),
                      _cell(dateStr),
                      _cell('\$${order['price']}'),
                      _cell(st),
                    ]);
                  }),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.indigo50,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Text('الإجمالي: \$${total.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.indigo)),
                ),
              ),
              pw.Spacer(),
              pw.Divider(),
              pw.Center(
                  child: pw.Text('شكراً لاستخدامكم خدمة حجز تذاكر الطيران',
                      style: const pw.TextStyle(color: PdfColors.grey))),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'فاتورة_$customerName.pdf',
    );
  }

  static pw.Widget _sectionTitle(String title) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.indigo900)),
          pw.Divider(color: PdfColors.indigo200),
          pw.SizedBox(height: 4),
        ],
      );

  static pw.Widget _infoRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
                style:
                    const pw.TextStyle(color: PdfColors.grey700, fontSize: 10)),
            pw.Text(value,
                style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          ],
        ),
      );

  static pw.Widget _cell(String text, {bool isHeader = false}) => pw.Padding(
        padding: const pw.EdgeInsets.all(8),
        child: pw.Text(text,
            style: pw.TextStyle(
              fontWeight: isHeader ? pw.FontWeight.bold : null,
              fontSize: isHeader ? 11 : 10,
            )),
      );
}
