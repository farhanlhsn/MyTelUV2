class UserModel {
  final String username;
  final String nama;
  final String role;

  const UserModel({
    required this.username,
    required this.nama,
    required this.role,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      username: map['username'] as String? ?? '',
      nama: map['nama'] as String? ?? '',
      role: map['role'] as String? ?? '',
    );
  }
}
