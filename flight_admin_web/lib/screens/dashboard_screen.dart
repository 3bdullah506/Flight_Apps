import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'flights_screen.dart';
import 'orders_screen.dart';
import 'invoice_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const DashboardScreen({super.key, required this.onLogout});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    FlightsScreen(),
    OrdersScreen(),
    InvoiceScreen(),
  ];

  final List<String> _titles = ['إدارة الرحلات', 'إدارة الطلبات', 'الفواتير'];

  final List<IconData> _icons = [
    Icons.flight,
    Icons.receipt_long,
    Icons.picture_as_pdf,
  ];

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('admin_logged_in', false);
    widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 700;

    if (isWide) {
      return _buildWebLayout();
    } else {
      return _buildMobileLayout();
    }
  }

  // ============ Web / Tablet Layout (Sidebar) ============
  Widget _buildWebLayout() {
    return Scaffold(
      body: Row(
        children: [
          // ===== Sidebar =====
          Container(
            width: 220,
            color: Colors.indigo[900],
            child: Column(
              children: [
                // Logo
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.flight, size: 48, color: Colors.white),
                      const SizedBox(height: 8),
                      const Text(
                        'لوحة التحكم',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'نظام حجز الطيران',
                        style: TextStyle(color: Colors.indigo[200], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24),

                // Menu Items
                _buildSidebarItem(0, Icons.flight, 'الرحلات'),
                _buildSidebarItem(1, Icons.receipt_long, 'الطلبات'),
                _buildSidebarItem(2, Icons.picture_as_pdf, 'الفواتير'),

                const Spacer(),
                const Divider(color: Colors.white24),

                // Logout
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.white70),
                  title: const Text('تسجيل الخروج',
                      style: TextStyle(color: Colors.white70)),
                  onTap: _logout,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // ===== Content =====
          Expanded(
            child: Column(
              children: [
                // Top Bar
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4)
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(
                        _titles[_selectedIndex],
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.admin_panel_settings, color: Colors.indigo),
                      const SizedBox(width: 8),
                      const Text('مسؤول النظام'),
                    ],
                  ),
                ),

                // Screen Content
                Expanded(child: _screens[_selectedIndex]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============ Mobile Layout (Drawer + BottomNavigationBar) ============
  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
        title: Text(
          _titles[_selectedIndex],
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            tooltip: 'تسجيل الخروج',
            onPressed: _logout,
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        selectedItemColor: Colors.indigo,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.flight),
            label: 'الرحلات',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'الطلبات',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.picture_as_pdf),
            label: 'الفواتير',
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String title) {
    final isSelected = _selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? Colors.indigo[700] : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading:
            Icon(icon, color: isSelected ? Colors.white : Colors.indigo[200]),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.indigo[200],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () => setState(() => _selectedIndex = index),
      ),
    );
  }
}
