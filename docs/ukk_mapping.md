# Matriks Kriteria UKK RPL

Kolom *Status* menunjukkan **kesiapan kode**, bukan hasil uji. Semua pengujian masih harus Anda jalankan
(lihat `testing.md`).

| Kriteria | Wujud di aplikasi | Berkas | Fungsi/bagian | Langkah demonstrasi |
|---|---|---|---|---|
| **Struktur data / array** | `List<Book>`, `List<Member>`, `List<Loan>` menampung hasil query | `database_helper.dart` | `getAllBooks()`, `getAllMembers()`, `getAllLoans()` | Buka tab Buku; jelaskan `rows.map(Book.fromMap).toList()` |
| Pencarian pada List | `where` + `contains` | `books_screen.dart`, `history_screen.dart` | getter `_filtered` | Ketik kata kunci di kolom cari |
| Perulangan | `for`/`for-in` membuat baris CSV, JSON, seed data | `file_service.dart`, `database_helper.dart` | `exportBooksToCsv()`, `parseBooksCsv()`, `_seed()` | Tunjukkan kode lalu ekspor |
| **Tipe data** | `int`, `String`, `DateTime`, `bool`, nullable (`int? year`, `DateTime? returnDate`, `String? phone`) | `models/*.dart` | Atribut kelas | Jelaskan tiap atribut dan alasan nullable |
| **Percabangan / kontrol** | Validasi stok, status anggota, status transaksi | `database_helper.dart` | `addLoan()`, `returnLoan()`, `updateBook()` | Pinjam stok habis, anggota nonaktif, kembalikan dua kali |
| **Fungsi dan prosedur** | CRUD terpisah dengan parameter dan nilai kembalian jelas | `database_helper.dart` | `insertBook()`, `updateBook()`, `deleteBook()`, `insertMember()`, `updateMember()`, `deleteMember()`, `addLoan()`, `returnLoan()`, `getActiveLoans()`, `getStats()` | Telusuri satu fitur dari tombol ke fungsi |
| Penanganan error | `AppException`, `_guard()`, try/catch di UI | `database_helper.dart`, semua `screens/` | `_guard()` | Picu error validasi, lihat SnackBar/pesan dialog |
| **Database (SQLite)** | 3 tabel, PK, FK, UNIQUE, CHECK, indeks, versi + `onUpgrade` | `database_helper.dart` | `_onCreate()`, `_onUpgrade()` | Jelaskan skema; tutup lalu buka aplikasi (data tetap) |
| Transaksi database | Pinjam/kembali atomik | `database_helper.dart` | `db.transaction` di `addLoan()`, `returnLoan()` | Stok berubah konsisten setelah pinjam/kembali |
| **Akses file (tulis)** | Ekspor CSV buku & JSON laporan | `file_service.dart` | `exportBooksToCsv()`, `exportLoansToJson()`, `shareFile()` | Ekspor, simpan lewat share sheet, buka file |
| Akses file (baca) | Impor CSV dengan validasi | `file_service.dart` | `pickCsvContent()`, `parseBooksCsv()` | Impor CSV contoh di `testing.md` |
| **Dokumentasi** | Komentar `///`, README, flowchart, pengujian | `lib/**`, `docs/*.md` | Seluruh proyek | Tunjukkan komentar fungsi dan dokumen |
| Flowchart | Peminjaman, pengembalian, ekspor | `docs/flowchart.md` | - | Cocokkan diagram dengan kode `addLoan()` |
| Petunjuk instalasi | Perintah lengkap | `docs/README.md` | - | Peragakan `flutter pub get` dan `flutter run` |
| **Debugging / pengujian** | Data uji, 24 skenario manual, tes unit | `docs/testing.md`, `test/bookflow_test.dart` | - | Jalankan sebagian skenario; isi kolom Hasil |
| UI/UX | Material 3, NavigationBar, dialog konfirmasi, SnackBar, empty state | `main.dart`, `widgets/` | - | Navigasi 5 tab |

## Checklist demonstrasi UKK (urutan saran, ±10 menit)

1. [ ] Jalankan aplikasi; tunjukkan Dashboard dengan data contoh.
2. [ ] Tambah buku baru; coba kode ganda dan judul kosong (validasi).
3. [ ] Edit lalu hapus buku; coba hapus buku yang punya transaksi (ditolak).
4. [ ] Tambah/edit anggota; nonaktifkan satu anggota.
5. [ ] Pinjam buku (stok berkurang); coba stok habis dan anggota nonaktif.
6. [ ] Kembalikan buku (stok bertambah); tunjukkan pengembalian terlambat.
7. [ ] Riwayat: cari dan filter status.
8. [ ] Ekspor CSV dan JSON; buka hasilnya.
9. [ ] (Opsional) Impor CSV.
10. [ ] Tutup paksa aplikasi, buka lagi: data tetap ada.
11. [ ] Tunjukkan kode: `addLoan()` (transaction), `Book.fromMap`, komentar `///`, dan dokumen flowchart.
