/// Model data anggota perpustakaan (tabel `members`).
class Member {
  final int? id;
  final String memberNo;
  final String name;
  final String className;
  final String? phone; // opsional
  final bool isActive;

  const Member({
    this.id,
    required this.memberNo,
    required this.name,
    this.className = '',
    this.phone,
    this.isActive = true,
  });

  factory Member.fromMap(Map<String, Object?> map) {
    return Member(
      id: map['id'] as int?,
      memberNo: map['member_no'] as String,
      name: map['name'] as String,
      className: (map['class_name'] as String?) ?? '',
      phone: map['phone'] as String?,
      isActive: ((map['is_active'] as num?) ?? 1) == 1,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'member_no': memberNo,
      'name': name,
      'class_name': className,
      'phone': phone,
      'is_active': isActive ? 1 : 0,
    };
  }
}
