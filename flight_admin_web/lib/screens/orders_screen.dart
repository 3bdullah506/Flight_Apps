import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../services/pdf_service.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = AdminFirebaseService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الطلبات'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.indigo,
        elevation: 0,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: service.getAllOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('خطأ في قراءة الطلبات',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontSize: 13)),
                ],
              ),
            );
          }

          final orders = snapshot.data ?? [];
          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text('لا توجد طلبات حتى الآن',
                      style: TextStyle(color: Colors.grey)),
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
                  showCheckboxColumn: false,
                  headingRowColor: WidgetStateProperty.all(Colors.indigo[50]),
                  columns: const [
                    DataColumn(
                        label: Text('رقم الحجز',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('الراكب',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('المسار',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('تاريخ الرحلة',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('الإقلاع',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('المقعد',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('السعر',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('الحالة',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('الإجراءات',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: orders.map((order) {
                    final status = order['status'] ?? 'pending';
                    Color statusColor;
                    String statusText;

                    switch (status) {
                      case 'approved':
                        statusColor = Colors.green;
                        statusText = 'مقبول';
                        break;
                      case 'rejected':
                        statusColor = Colors.red;
                        statusText = 'مرفوض';
                        break;
                      default:
                        statusColor = Colors.orange;
                        statusText = 'قيد المراجعة';
                    }

                    String flightDateStr = '';
                    try {
                      flightDateStr = DateFormat('dd/MM/yyyy')
                          .format(order['flightDate'].toDate());
                    } catch (_) {}

                    final bookingId = order['bookingId']?.toString() ??
                        order['id']?.toString() ??
                        '-';
                    final passenger = order['userName']?.toString() ?? '-';
                    final depTime = order['departureTime']?.toString() ?? '-';
                    final seatNum = order['seatNumber']?.toString() ?? '-';

                    return DataRow(
                        onSelectChanged: (_) =>
                            _showOrderDetails(context, order),
                        cells: [
                          // رقم الحجز
                          DataCell(Text(bookingId,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.indigo))),
                          // الراكب
                          DataCell(Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(passenger,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                              Text(order['userEmail']?.toString() ?? '',
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.grey)),
                            ],
                          )),
                          // المسار
                          DataCell(Text(
                              '${order['origin']} → ${order['destination']}')),
                          // التاريخ
                          DataCell(Text(flightDateStr)),
                          // الإقلاع
                          DataCell(Text(depTime)),
                          // المقعد
                          DataCell(Text(seatNum,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold))),
                          // السعر
                          DataCell(Text('\$${order['price']}')),
                          // الحالة
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: statusColor),
                              ),
                              child: Text(statusText,
                                  style: TextStyle(
                                      color: statusColor, fontSize: 12)),
                            ),
                          ),
                          // الإجراءات
                          DataCell(
                            status == 'pending'
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.check_circle,
                                            color: Colors.green, size: 22),
                                        tooltip: 'قبول',
                                        onPressed: () =>
                                            service.updateOrderStatus(
                                                order['id'], 'approved'),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.cancel,
                                            color: Colors.red, size: 22),
                                        tooltip: 'رفض',
                                        onPressed: () =>
                                            service.updateOrderStatus(
                                                order['id'], 'rejected'),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(statusText,
                                          style: TextStyle(
                                              color: statusColor,
                                              fontSize: 12)),
                                      // ✅ زر طباعة التذكرة للطلبات المقبولة
                                      if (status == 'approved')
                                        IconButton(
                                          icon: const Icon(Icons.picture_as_pdf,
                                              color: Colors.indigo, size: 22),
                                          tooltip: 'طباعة التذكرة',
                                          onPressed: () =>
                                              _printTicket(context, order),
                                        ),
                                    ],
                                  ),
                          ),
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

  Future<void> _printTicket(
      BuildContext context, Map<String, dynamic> order) async {
    try {
      await PdfService.generateTicket(order: order);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('خطأ في الطباعة: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showOrderDetails(BuildContext context, Map<String, dynamic> order) {
    final status = order['status']?.toString() ?? 'pending';
    final statusColor = _statusColor(status);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: ui.TextDirection.rtl,
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'تفاصيل الطلب',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: statusColor),
                          ),
                          child: Text(
                            _statusText(status),
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'إغلاق',
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _detailRow(
                      Icons.confirmation_number,
                      'رقم الحجز',
                      _displayText(order['bookingId'] ?? order['id']),
                    ),
                    _detailRow(
                      Icons.person,
                      'الراكب',
                      _displayText(order['userName']),
                    ),
                    _detailRow(
                      Icons.email,
                      'البريد',
                      _displayText(order['userEmail']),
                    ),
                    _detailRow(
                      Icons.phone,
                      'الهاتف',
                      _displayText(order['userPhone']),
                    ),
                    _detailRow(
                      Icons.badge,
                      'رقم الجواز',
                      _displayText(order['passportNumber']),
                    ),
                    _detailRow(
                      Icons.route,
                      'المسار',
                      '${_displayText(order['origin'])} → ${_displayText(order['destination'])}',
                    ),
                    _detailRow(
                      Icons.flight,
                      'رقم الرحلة',
                      _displayText(order['flightNumber']),
                    ),
                    _detailRow(
                      Icons.calendar_today,
                      'تاريخ الرحلة',
                      _formatDate(order['flightDate']),
                    ),
                    _detailRow(
                      Icons.flight_takeoff,
                      'وقت الإقلاع',
                      _displayText(order['departureTime']),
                    ),
                    _detailRow(
                      Icons.flight_land,
                      'وقت الوصول',
                      _displayText(order['arrivalTime']),
                    ),
                    _detailRow(
                      Icons.airline_seat_recline_normal,
                      'وقت الصعود',
                      _displayText(order['boardingTime']),
                    ),
                    _detailRow(
                      Icons.timer,
                      'مدة الرحلة',
                      _displayText(order['duration']),
                    ),
                    _detailRow(
                      Icons.event_seat,
                      'رقم المقعد',
                      _displayText(order['seatNumber']),
                    ),
                    _detailRow(
                      Icons.attach_money,
                      'السعر',
                      _formatPrice(order['price']),
                    ),
                    _detailRow(
                      Icons.access_time,
                      'تاريخ الطلب',
                      _formatDate(order['createdAt']),
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

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: Colors.grey),
          const SizedBox(width: 8),
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

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'approved':
        return 'مقبول';
      case 'rejected':
        return 'مرفوض';
      default:
        return 'قيد المراجعة';
    }
  }

  String _displayText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '-' : text;
  }

  String _formatDate(dynamic value) {
    try {
      return DateFormat('dd/MM/yyyy').format(value.toDate());
    } catch (_) {
      if (value is DateTime) return DateFormat('dd/MM/yyyy').format(value);
      return '-';
    }
  }

  String _formatPrice(dynamic value) {
    final price = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    return '\$${price.toStringAsFixed(0)}';
  }
}
