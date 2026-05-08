import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../services/pdf_service.dart';

class InvoiceScreen extends StatefulWidget {
  const InvoiceScreen({super.key});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  final AdminFirebaseService _service = AdminFirebaseService();
  final List<Map<String, dynamic>> _selectedOrders = [];
  bool _isGenerating = false;

  double get _total =>
      _selectedOrders.fold(0.0, (sum, o) => sum + (o['price'] as num).toDouble());

  Future<void> _generatePdf() async {
    if (_selectedOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر طلباً واحداً على الأقل')),
      );
      return;
    }
    setState(() => _isGenerating = true);
    try {
      final firstOrder = _selectedOrders.first;
      final cName = firstOrder['userName']?.toString() ?? 'عميل غير معروف';
      final cEmail = firstOrder['userEmail']?.toString() ?? 'لا يوجد بريد';

      await PdfService.generateInvoice(
        invoiceNumber: 'INV-${DateTime.now().millisecondsSinceEpoch}',
        customerName: cName,
        customerEmail: cEmail,
        orders: _selectedOrders,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _isGenerating = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الفواتير'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.indigo,
        elevation: 0,
        actions: [
          if (_selectedOrders.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 16),
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generatePdf,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.print),
                label: Text('طباعة (${_selectedOrders.length})'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── شريط الإجمالي ──
          if (_selectedOrders.isNotEmpty)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.indigo[50],
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.indigo[700], size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تم تحديد ${_selectedOrders.length} طلب  |  الإجمالي: \$${_total.toStringAsFixed(2)}',
                      style: TextStyle(
                          color: Colors.indigo[700],
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        setState(() => _selectedOrders.clear()),
                    child: const Text('إلغاء التحديد'),
                  ),
                ],
              ),
            ),

          // ── جدول الطلبات ──
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _service.getAllOrders(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final orders = snapshot.data ?? [];

                if (orders.isEmpty) {
                  return const Center(
                      child: Text('لا توجد طلبات',
                          style: TextStyle(color: Colors.grey)));
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
                          DataColumn(label: Text('تحديد')),
                          DataColumn(label: Text('المسار')),
                          DataColumn(label: Text('تاريخ الرحلة')),
                          DataColumn(label: Text('السعر')),
                          DataColumn(label: Text('الحالة')),
                        ],
                        rows: orders.map((order) {
                          final isSelected = _selectedOrders
                              .any((o) => o['id'] == order['id']);

                          String dateStr = '';
                          try {
                            dateStr = DateFormat('dd/MM/yyyy')
                                .format(order['flightDate'].toDate());
                          } catch (_) {}

                          String statusText;
                          Color statusColor;
                          switch (order['status']) {
                            case 'approved':
                              statusText = 'مقبول';
                              statusColor = Colors.green;
                              break;
                            case 'rejected':
                              statusText = 'مرفوض';
                              statusColor = Colors.red;
                              break;
                            default:
                              statusText = 'قيد المراجعة';
                              statusColor = Colors.orange;
                          }

                          return DataRow(
                            selected: isSelected,
                            cells: [
                              DataCell(Checkbox(
                                value: isSelected,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedOrders.add(order);
                                    } else {
                                      _selectedOrders.removeWhere(
                                          (o) => o['id'] == order['id']);
                                    }
                                  });
                                },
                              )),
                              DataCell(Text(
                                  '${order['origin']} → ${order['destination']}')),
                              DataCell(Text(dateStr)),
                              DataCell(Text('\$${order['price']}')),
                              DataCell(Text(statusText,
                                  style: TextStyle(color: statusColor))),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
