import 'package:bookflow/models/loan.dart';
import 'package:bookflow/services/file_service.dart';
import 'package:flutter_test/flutter_test.dart';

Loan _loan({required String status, required DateTime due, DateTime? ret}) =>
    Loan(
      bookId: 1,
      memberId: 1,
      quantity: 1,
      loanDate: due.subtract(const Duration(days: 7)),
      dueDate: due,
      returnDate: ret,
      status: status,
    );

void main() {
  group('Status peminjaman', () {
    final today = dateOnly(DateTime.now());

    test('Dipinjam jika belum jatuh tempo', () {
      final l = _loan(
          status: Loan.statusBorrowed,
          due: today.add(const Duration(days: 2)));
      expect(l.statusLabel, 'Dipinjam');
      expect(l.daysLate, 0);
      expect(l.estimatedFine, 0);
      expect(l.daysRemaining, 2);
    });

    test('Terlambat jika lewat jatuh tempo', () {
      final l = _loan(
          status: Loan.statusBorrowed,
          due: today.subtract(const Duration(days: 3)));
      expect(l.statusLabel, 'Terlambat');
      expect(l.daysLate, 3);
      expect(l.estimatedFine, 3 * finePerDay);
      expect(l.daysRemaining, -3);
    });

    test('Dikembalikan jika status returned', () {
      final l = _loan(
        status: Loan.statusReturned,
        due: today.subtract(const Duration(days: 3)),
        ret: today.subtract(const Duration(days: 1)),
      );
      expect(l.statusLabel, 'Dikembalikan');
      expect(l.daysLate, 2);
    });

    test('Denda nol jika dikembalikan tepat waktu', () {
      final l = _loan(
        status: Loan.statusReturned,
        due: today,
        ret: today,
      );
      expect(l.daysLate, 0);
      expect(l.fine, 0);
    });
  });

  group('Format rupiah', () {
    test('Nilai kecil', () {
      expect(formatRupiah(0), 'Rp0');
      expect(formatRupiah(500), 'Rp500');
    });

    test('Ribuan dengan titik', () {
      expect(formatRupiah(1000), 'Rp1.000');
      expect(formatRupiah(1500), 'Rp1.500');
      expect(formatRupiah(25000), 'Rp25.000');
      expect(formatRupiah(1000000), 'Rp1.000.000');
    });
  });

  group('Parsing CSV buku', () {
    final service = FileService();

    test('Baris valid dan tidak valid dipisahkan', () {
      const csv = 'kode,judul,penulis,penerbit,kategori,tahun,stok_total\n'
          'T01,Buku Satu,Penulis A,Penerbit A,Novel,2020,3\n'
          'T02,,Penulis B,Penerbit B,Novel,2020,3\n'
          'T03,Buku Tiga,Penulis C,Penerbit C,Novel,2020,-1\n'
          'T01,Buku Dobel,Penulis D,Penerbit D,Novel,2020,2\n';
      final result = service.parseBooksCsv(csv);
      expect(result.books.length, 1);
      expect(result.books.first.code, 'T01');
      expect(result.books.first.publisher, 'Penerbit A');
      expect(result.errors.length, 3);
    });

    test('Header salah ditolak', () {
      expect(() => service.parseBooksCsv('a,b,c\n1,2,3'), throwsA(anything));
    });

    test('Pemisah titik koma dikenali', () {
      final result = service
          .parseBooksCsv('kode;judul;stok_total\nX1;Judul X;4');
      expect(result.books.single.totalStock, 4);
    });

    test('Kolom penerbit dan rak terisi bila ada di header', () {
      const csv = 'kode,judul,penerbit,rak,stok_total\n'
          'X1,Judul X,Penerbit X,A-01,2\n';
      final result = service.parseBooksCsv(csv);
      final b = result.books.single;
      expect(b.publisher, 'Penerbit X');
      expect(b.shelf, 'A-01');
      expect(b.totalStock, 2);
      expect(b.availableStock, 2);
    });
  });
}