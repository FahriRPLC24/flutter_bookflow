# BookFlow - Aplikasi Peminjaman Buku Perpustakaan

Aplikasi Android offline berbasis **Flutter + SQLite (sqflite)**. Cocok untuk UKK RPL:
CRUD, transaksi database, akses file (CSV & JSON), dokumentasi, dan pengujian.

> **Status verifikasi jujur:** kode ditulis tanpa Flutter SDK di lingkungan pembuatnya, sehingga
> `flutter pub get`, `flutter analyze`, `flutter test`, dan uji di perangkat **belum dijalankan**.
> Jalankan langkah di bawah dan perbaiki bila ada pesan error sebelum demonstrasi.

## Instalasi dan menjalankan

Prasyarat: Flutter SDK 3.27 atau lebih baru (Dart 3.6+), Android Studio/SDK, HP Android (USB debugging) atau emulator.

```bash
# 1. Masuk ke folder proyek
cd bookflow

# 2. Buat folder platform Android (hanya sekali; file lib/ & pubspec.yaml tidak ditimpa)
flutter create . --platforms=android --project-name bookflow

# 3. Ambil dependensi
flutter pub get

# 4. Periksa kode dan jalankan tes
flutter analyze
flutter test

# 5. Jalankan di perangkat/emulator
flutter devices
flutter run

# 6. (Opsional) Bangun APK
flutter build apk --release
# hasil: build/app/outputs/flutter-apk/app-release.apk
```

Jika `flutter create` menimpa `test/widget_test.dart` atau membuat file bawaan yang error,
hapus `test/widget_test.dart` (tes bawaan itu merujuk ke aplikasi counter).

## Fitur

| Modul | Berkas | Ringkasan |
|---|---|---|
| Dashboard | `screens/dashboard_screen.dart` | 6 statistik dari SQLite + 5 transaksi terbaru |
| Buku | `screens/books_screen.dart` | CRUD, cari, validasi kode unik, ekspor/impor CSV |
| Anggota | `screens/members_screen.dart` | CRUD, cari, status aktif/nonaktif, hapus aman |
| Pinjam & Kembali | `screens/loans_screen.dart` | Form pinjam (transaction), daftar aktif, kembalikan |
| Riwayat | `screens/history_screen.dart` | Cari, filter status, ekspor JSON |
| Database | `database/database_helper.dart` | Skema, seed, CRUD, transaksi, statistik |
| File | `services/file_service.dart` | Tulis/baca CSV & JSON, share, validasi impor |

## Dokumentasi modul

### models/
`Book`, `Member`, `Loan`: kelas data dengan `fromMap()` (SQLite -> objek) dan `toMap()` (objek -> SQLite).
`Loan` juga menghitung `statusLabel` (Dipinjam/Terlambat/Dikembalikan) dan `daysLate`.
Tanggal disimpan sebagai teks `yyyy-MM-dd`.

### database/database_helper.dart
Singleton `DatabaseHelper.instance`. Database `bookflow.db` versi 1 dengan tabel `books`, `members`, `loans`.
- `PRAGMA foreign_keys = ON` di `onConfigure`.
- `onCreate` membuat tabel, indeks, dan data contoh (7 buku, 5 anggota, 3 transaksi).
- `onUpgrade` disiapkan untuk migrasi versi berikutnya.
- Semua method melempar `AppException` berpesan ramah; `_guard()` menerjemahkan error SQLite.
- `dataChanged` (ValueNotifier) memberi tahu semua layar agar memuat ulang data.

### services/file_service.dart
- `exportBooksToCsv(List<Book>)` -> path file CSV
- `exportLoansToJson(List<Loan>)` -> path file JSON
- `shareFile(path)` -> membuka share sheet Android (simpan ke Drive/File Manager/kirim WhatsApp)
- `pickCsvContent()` + `parseBooksCsv(String)` -> impor CSV dengan validasi per baris

File ekspor dibuat di folder cache aplikasi lalu dibagikan lewat share sheet; pengguna menyimpannya
ke lokasi pilihan dari sana (cara ini tidak butuh izin penyimpanan khusus).

### Alur data (membaca, menyimpan, mencari, mengolah)
- **Baca:** `db.query()` -> `List<Map>` -> `rows.map(Book.fromMap).toList()` -> `List<Book>`.
- **Simpan:** objek -> `toMap()` -> `db.insert/update`.
- **Cari:** `_books.where((b) => b.title.toLowerCase().contains(q)).toList()`.
- **Olah:** `for` untuk membuat baris CSV dan peta JSON; `SUM/COUNT` SQL untuk statistik.

## Batasan yang diketahui
- Satu transaksi hanya untuk satu jenis buku.
- Denda tidak diimplementasikan; keterlambatan hanya dihitung dalam hari.
- Buku/anggota yang punya riwayat transaksi tidak bisa dihapus (sengaja, demi integritas data). Anggota bisa dinonaktifkan.
- Impor CSV hanya menambah buku baru; kode yang sudah ada dilewati (tidak memperbarui).
- Tanpa login dan tanpa sinkronisasi online.
- Aplikasi diuji sebatas yang tercantum di `testing.md` (kolom status).
