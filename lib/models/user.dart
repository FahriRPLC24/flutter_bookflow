enum UserRole { petugas, anggota }

UserRole roleFromString(String s) =>
    s == 'petugas' ? UserRole.petugas : UserRole.anggota;

String roleToString(UserRole r) =>
    r == UserRole.petugas ? 'petugas' : 'anggota';

class User {
  final int? id;
  final String username;
  final String password;
  final UserRole role;
  final int? memberId;

  const User({
    this.id,
    required this.username,
    required this.password,
    required this.role,
    this.memberId,
  });

  factory User.fromMap(Map<String, Object?> map) {
    return User(
      id: map['id'] as int?,
      username: map['username'] as String,
      password: map['password'] as String,
      role: roleFromString(map['role'] as String),
      memberId: (map['member_id'] as num?)?.toInt(),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'username': username,
      'password': password,
      'role': roleToString(role),
      'member_id': memberId,
    };
  }

  String get roleLabel => role == UserRole.petugas ? 'Petugas' : 'Anggota';
}