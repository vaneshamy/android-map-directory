class UserModel {
  final String id;
  final String email;
  final String name;
  final String role;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] ?? 'Tanpa Nama',
      role: json['role'] ?? 'authenticated', // Default role jika kosong
    );
  }
}