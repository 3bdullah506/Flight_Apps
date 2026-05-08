class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String passportNumber; // رقم الهوية أو الجواز

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    this.address = '',
    this.passportNumber = '',
  });

  factory UserModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return UserModel(
      id: docId,
      name: data['name']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      address: data['address']?.toString() ?? '',
      passportNumber: data['passportNumber']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'passportNumber': passportNumber,
    };
  }
}