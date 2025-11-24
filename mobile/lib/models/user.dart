class UserModel {
  final int idUser;
  final String username;
  final String nama;
  final String role;

  const UserModel({
    required this.idUser,
    required this.username,
    required this.nama,
    required this.role,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      idUser: map['id_user'] as int? ?? map['id'] as int? ?? 0,
      username: map['username'] as String? ?? '',
      nama: map['nama'] as String? ?? '',
      role: map['role'] as String? ?? '',
    );
  }
}
