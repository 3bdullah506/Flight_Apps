import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/flight_model.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import '../widgets/flight_card.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';
import 'order_tracking_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// كل رحلة في السلة: الرحلة + الكمية
class CartItem {
  final FlightModel flight;
  int quantity;
  CartItem({required this.flight, required this.quantity});
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final AuthService _authService = AuthService();
  final List<CartItem> _cart = [];
  final TextEditingController _originFilterController = TextEditingController();
  final TextEditingController _destinationFilterController =
      TextEditingController();
  int _currentIndex = 0;

  // ── فلاتر البحث ──
  String _appliedOrigin = '';
  String _appliedDestination = '';
  DateTime? _appliedFilterDate;
  DateTime? _draftFilterDate;
  bool _showFilters = false;

  @override
  void dispose() {
    _originFilterController.dispose();
    _destinationFilterController.dispose();
    super.dispose();
  }

  void _addToCart(FlightModel flight, int quantity) {
    final existing = _cart.indexWhere((c) => c.flight.id == flight.id);
    if (existing != -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذه الرحلة موجودة في سلتك بالفعل')),
      );
      return;
    }
    setState(() => _cart.add(CartItem(flight: flight, quantity: quantity)));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تمت إضافة $quantity تذكرة إلى السلة ✓'),
        backgroundColor: Colors.green,
      ),
    );
  }

  int get _cartTotalTickets =>
      _cart.fold(0, (sum, item) => sum + item.quantity);

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      _buildFlightsScreen(),
      CartScreen(
        cart: _cart,
        onRemove: (item) => setState(() => _cart.remove(item)),
      ),
      const OrderTrackingScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('حجز تذاكر الطيران'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (_currentIndex == 0)
            IconButton(
              icon: Icon(
                  _showFilters ? Icons.filter_list_off : Icons.filter_list),
              tooltip: 'فلترة',
              onPressed: () => setState(() => _showFilters = !_showFilters),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async => await _authService.signOut(),
          ),
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        items: [
          const BottomNavigationBarItem(
              icon: Icon(Icons.flight), label: 'الرحلات'),
          BottomNavigationBarItem(
            icon: Badge(
              label: Text(_cartTotalTickets.toString()),
              isLabelVisible: _cart.isNotEmpty,
              child: const Icon(Icons.shopping_cart),
            ),
            label: 'السلة',
          ),
          const BottomNavigationBarItem(
              icon: Icon(Icons.track_changes), label: 'طلباتي'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.person), label: 'ملفي'),
        ],
      ),
    );
  }

  Widget _buildFlightsScreen() {
    return StreamBuilder<List<FlightModel>>(
      stream: _firebaseService.getFlights(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('خطأ: ${snapshot.error}'));
        }
        final allFlights = snapshot.data ?? [];

        // ✅ تطبيق الفلاتر بعد ضغط زر "تطبيق"
        final filtered = allFlights.where((f) {
          if (_appliedOrigin.isNotEmpty &&
              !f.origin.toLowerCase().contains(_appliedOrigin.toLowerCase())) {
            return false;
          }
          if (_appliedDestination.isNotEmpty &&
              !f.destination
                  .toLowerCase()
                  .contains(_appliedDestination.toLowerCase())) {
            return false;
          }
          if (_appliedFilterDate != null) {
            final fd = _appliedFilterDate!;
            if (f.date.year != fd.year ||
                f.date.month != fd.month ||
                f.date.day != fd.day) {
              return false;
            }
          }
          return true;
        }).toList();

        return Column(
          children: [
            // ✅ لوحة الفلاتر
            if (_showFilters) _buildFilterPanel(),

            // قائمة الرحلات
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.flight_land,
                              size: 80, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            allFlights.isEmpty
                                ? 'لا توجد رحلات متاحة حالياً'
                                : 'لا توجد رحلات تطابق الفلتر',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          if (allFlights.isNotEmpty && _hasAppliedFilters)
                            TextButton(
                              onPressed: _clearFilters,
                              child: const Text('مسح الفلاتر'),
                            ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) => FlightCard(
                        flight: filtered[index],
                        onAddToCart: _addToCart,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      color: Colors.blue.shade50,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_alt, size: 18, color: Colors.blue),
              const SizedBox(width: 6),
              const Text('فلترة الرحلات',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.blue)),
              const Spacer(),
              TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('مسح الكل'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // من
              Expanded(
                child: TextField(
                  controller: _originFilterController,
                  decoration: InputDecoration(
                    labelText: 'من (مكان الانطلاق)',
                    prefixIcon: const Icon(Icons.flight_takeoff, size: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _applyFilters(),
                ),
              ),
              const SizedBox(width: 8),
              // إلى
              Expanded(
                child: TextField(
                  controller: _destinationFilterController,
                  decoration: InputDecoration(
                    labelText: 'إلى (الوجهة)',
                    prefixIcon: const Icon(Icons.flight_land, size: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _applyFilters(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // تاريخ الرحلة
          GestureDetector(
            onTap: _pickFilterDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    _draftFilterDate == null
                        ? 'تاريخ الرحلة (اختياري)'
                        : DateFormat('dd/MM/yyyy').format(_draftFilterDate!),
                    style: TextStyle(
                      color: _draftFilterDate == null
                          ? Colors.grey
                          : Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  if (_draftFilterDate != null)
                    GestureDetector(
                      onTap: () => setState(() => _draftFilterDate = null),
                      child:
                          const Icon(Icons.close, size: 16, color: Colors.red),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _applyFilters,
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('تطبيق الفلترة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('مسح'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Future<void> _pickFilterDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _draftFilterDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _draftFilterDate = picked);
  }

  bool get _hasAppliedFilters =>
      _appliedOrigin.isNotEmpty ||
      _appliedDestination.isNotEmpty ||
      _appliedFilterDate != null;

  void _applyFilters() {
    setState(() {
      _appliedOrigin = _originFilterController.text.trim();
      _appliedDestination = _destinationFilterController.text.trim();
      _appliedFilterDate = _draftFilterDate;
    });
  }

  void _clearFilters() {
    setState(() {
      _originFilterController.clear();
      _destinationFilterController.clear();
      _appliedOrigin = '';
      _appliedDestination = '';
      _appliedFilterDate = null;
      _draftFilterDate = null;
    });
  }
}
