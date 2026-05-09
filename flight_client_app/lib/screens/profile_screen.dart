import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import '../models/user_model.dart';
import '../services/firebase_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final _formKey = GlobalKey<FormState>();
  final _nameController       = TextEditingController();
  final _phoneController      = TextEditingController();
  final _addressController    = TextEditingController();
  final _passportController   = TextEditingController();
  bool _isLoading = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final user = await _firebaseService.getUser(uid);
    if (user != null && mounted) {
      setState(() {
        _nameController.text     = user.name;
        _phoneController.text    = user.phone;
        _addressController.text  = user.address;
        _passportController.text = user.passportNumber;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _isLoading = true);
    try {
      await _firebaseService.updateUser(uid, {
        'name':           _nameController.text.trim(),
        'phone':          _phoneController.text.trim(),
        'address':        _addressController.text.trim(),
        'passportNumber': _passportController.text.trim(),
      });
      setState(() => _isEditing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ البيانات ✓'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.indigo,
            child: Text(
              _nameController.text.isNotEmpty
                  ? _nameController.text[0].toUpperCase()
                  : '?',
              style: const TextStyle(fontSize: 40, color: Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          if (_nameController.text.isNotEmpty)
            Text(_nameController.text,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(FirebaseAuth.instance.currentUser?.email ?? '',
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  enabled: _isEditing,
                  decoration: const InputDecoration(
                    labelText: 'الاسم الكامل',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v?.isEmpty == true ? 'أدخل اسمك' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: FirebaseAuth.instance.currentUser?.email ?? '',
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneController,
                  enabled: _isEditing,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                // ✅ رقم الهوية / الجواز — مهم لتذكرة الطيران
                TextFormField(
                  controller: _passportController,
                  enabled: _isEditing,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهوية / جواز السفر',
                    prefixIcon: Icon(Icons.badge),
                    border: OutlineInputBorder(),
                    helperText: 'يُستخدم في تذكرة الطيران',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _addressController,
                  enabled: _isEditing,
                  decoration: const InputDecoration(
                    labelText: 'العنوان',
                    prefixIcon: Icon(Icons.location_on),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () {
                if (_isEditing) {
                  _saveProfile();
                } else {
                  setState(() => _isEditing = true);
                }
              },
              icon: Icon(_isEditing ? Icons.save : Icons.edit),
              label: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(_isEditing ? 'حفظ التغييرات' : 'تعديل الملف الشخصي'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isEditing ? Colors.green : Colors.indigo,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          if (_isEditing)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => setState(() => _isEditing = false),
                  child: const Text('إلغاء'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}