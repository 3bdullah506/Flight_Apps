import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../services/firebase_service.dart';

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
