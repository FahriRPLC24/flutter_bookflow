import 'loan.dart';

class LoanRequest {
  static const String statusPending = 'pending';
  static const String statusApproved = 'approved';
  static const String statusRejected = 'rejected';
  static const String statusExpired = 'expired';

  final int? id;
  final int bookId;
  final int memberId;
  final int quantity;
  final DateTime requestDate;
  final DateTime? expiryDate;
  final String status;
  final String? note;
  final String bookTitle;
  final String memberName;

  const LoanRequest({
    this.id,
    required this.bookId,
    required this.memberId,
    required this.quantity,
    required this.requestDate,
    this.expiryDate,
    this.status = statusPending,
    this.note,
    this.bookTitle = '',
    this.memberName = '',
  });

  factory LoanRequest.fromMap(Map<String, Object?> map) {
    final exp = map['expiry_date'] as String?;
    return LoanRequest(
      id: map['id'] as int?,
      bookId: (map['book_id'] as num).toInt(),
      memberId: (map['member_id'] as num).toInt(),
      quantity: (map['quantity'] as num).toInt(),
      requestDate: DateTime.parse(map['request_date'] as String),
      expiryDate: exp == null ? null : DateTime.parse(exp),
      status: map['status'] as String,
      note: map['note'] as String?,
      bookTitle: (map['book_title'] as String?) ?? '',
      memberName: (map['member_name'] as String?) ?? '',
    );
  }

  Map<String, Object?> toMap() => {
        'book_id': bookId,
        'member_id': memberId,
        'quantity': quantity,
        'request_date': toDbDate(requestDate),
        'expiry_date': expiryDate == null ? null : toDbDate(expiryDate!),
        'status': status,
        'note': note,
      };

  String get statusLabel {
    switch (status) {
      case statusPending:
        return 'Menunggu';
      case statusApproved:
        return 'Disetujui';
      case statusRejected:
        return 'Ditolak';
      case statusExpired:
        return 'Kedaluwarsa';
      default:
        return status;
    }
  }

  bool get isPending => status == statusPending;
}