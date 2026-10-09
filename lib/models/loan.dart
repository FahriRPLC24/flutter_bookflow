import 'package:intl/intl.dart';

final DateFormat _dbFormat = DateFormat('yyyy-MM-dd');
final DateFormat _showFormat = DateFormat('dd/MM/yyyy');

/// Tarif denda keterlambatan per hari (Rp).
const int finePerDay = 500;

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String toDbDate(DateTime d) => _dbFormat.format(d);

String formatDate(DateTime d) => _showFormat.format(d);

/// Format rupiah sederhana tanpa intl locale.
String formatRupiah(int amount) {
  final s = amount.abs().toString();
  final buf = StringBuffer(amount < 0 ? '-Rp' : 'Rp');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}

class Loan {
  static const String statusBorrowed = 'borrowed';
  static const String statusReturned = 'returned';

  final int? id;
  final int bookId;
  final int memberId;
  final int quantity;
  final DateTime loanDate;
  final DateTime dueDate;
  final DateTime? returnDate;
  final String status;
  final int fine;
  final String memberName;
  final String bookTitle;

  const Loan({
    this.id,
    required this.bookId,
    required this.memberId,
    required this.quantity,
    required this.loanDate,
    required this.dueDate,
    this.returnDate,
    required this.status,
    this.fine = 0,
    this.memberName = '',
    this.bookTitle = '',
  });

  factory Loan.fromMap(Map<String, Object?> map) {
    final ret = map['return_date'] as String?;
    return Loan(
      id: map['id'] as int?,
      bookId: (map['book_id'] as num).toInt(),
      memberId: (map['member_id'] as num).toInt(),
      quantity: (map['quantity'] as num).toInt(),
      loanDate: DateTime.parse(map['loan_date'] as String),
      dueDate: DateTime.parse(map['due_date'] as String),
      returnDate: ret == null ? null : DateTime.parse(ret),
      status: map['status'] as String,
      fine: ((map['fine'] as num?) ?? 0).toInt(),
      memberName: (map['member_name'] as String?) ?? '',
      bookTitle: (map['book_title'] as String?) ?? '',
    );
  }

  bool get isOverdue =>
      status == statusBorrowed && dateOnly(DateTime.now()).isAfter(dueDate);

  int get daysLate {
    final end = returnDate ?? DateTime.now();
    final diff = dateOnly(end).difference(dueDate).inDays;
    return diff > 0 ? diff : 0;
  }

  int get estimatedFine => daysLate * finePerDay;

  int get daysRemaining =>
      dueDate.difference(dateOnly(DateTime.now())).inDays;

  String get statusLabel {
    if (status == statusReturned) return 'Dikembalikan';
    return isOverdue ? 'Terlambat' : 'Dipinjam';
  }

  Map<String, Object?> toExportMap() {
    return {
      'id': id,
      'anggota': memberName,
      'judul_buku': bookTitle,
      'jumlah': quantity,
      'tanggal_pinjam': toDbDate(loanDate),
      'jatuh_tempo': toDbDate(dueDate),
      'tanggal_kembali': returnDate == null ? null : toDbDate(returnDate!),
      'status': statusLabel,
      'hari_terlambat': daysLate,
      'denda': fine,
    };
  }
}