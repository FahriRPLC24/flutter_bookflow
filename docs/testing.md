# Rencana dan Catatan Pengujian

**Penting:** kolom *Hasil* sengaja dikosongkan. Isi `LULUS` / `GAGAL` setelah Anda menjalankannya sendiri
di perangkat. Pembuat kode tidak punya Flutter SDK, sehingga **belum ada pengujian yang dijalankan**.

## Data uji bawaan (seed)

| Data | Isi |
|---|---|
| Buku | BK001 Laskar Pelangi (5), BK002 Bumi Manusia (3), BK003 Filosofi Teras (4), BK004 Atomic Habits (2), BK005 Algoritma dan Pemrograman (4), BK006 Cantik Itu Luka (**1**), BK007 Sapiens (3) |
| Anggota | A001 Andi, A002 Siti, A003 Budi, A004 Dewi (aktif); A005 Rizky (**nonaktif**) |
| Transaksi | Andi pinjam Laskar Pelangi (terlambat 3 hari), Siti pinjam Bumi Manusia (aktif), Budi pinjam Filosofi Teras (sudah kembali) |

Stok tersedia awal setelah seed: BK001 = 4, BK002 = 2, BK003 = 4 (sudah kembali), lainnya penuh.
Dashboard awal yang diharapkan: judul 7, total stok 22, anggota 5, peminjaman aktif 2, buku dipinjam 2, terlambat 1.

## Pengujian manual

| No | Skenario | Langkah | Hasil diharapkan | Hasil |
|---|---|---|---|---|
| 1 | Tambah buku | Buku > + Buku > isi BK100, "Buku Uji", stok 3 > Simpan | Muncul di daftar, stok 3/3, Dashboard judul +1 | |
| 2 | Kode buku duplikat | Tambah buku dengan kode BK001 | Pesan "Kode buku sudah dipakai", dialog tetap terbuka | |
| 3 | Judul kosong | Kosongkan judul > Simpan | Pesan validasi "Judul wajib diisi" | |
| 4 | Stok negatif | Isi stok -1 | Pesan "Stok tidak boleh negatif" | |
| 5 | Edit buku | Ketuk BK100, ubah stok jadi 5 | Stok jadi 5/5 | |
| 6 | Edit stok di bawah yang dipinjam | Edit BK001 (dipinjam 1), stok total 0 | Ditolak: tidak boleh kurang dari yang dipinjam | |
| 7 | Cari buku | Ketik "pelangi" | Hanya Laskar Pelangi tampil | |
| 8 | Hapus buku tanpa transaksi | Hapus BK100 > konfirmasi | Hilang dari daftar | |
| 9 | Hapus buku bertransaksi | Hapus BK001 | Ditolak dengan pesan riwayat peminjaman | |
| 10 | CRUD anggota | Tambah A100, edit nama, cari, hapus | Semua berhasil; nomor ganda ditolak | |
| 11 | Hapus anggota bertransaksi | Hapus Andi | Ditolak, disarankan nonaktifkan | |
| 12 | Pinjam dengan stok cukup | Pinjam > Dewi, Sapiens, 2, tanggal default | Sukses; Sapiens tersedia 3 -> 1; transaksi muncul di Pinjam & Riwayat | |
| 13 | Pinjam stok habis | Pinjam > Dewi, Cantik Itu Luka, jumlah 2 | Ditolak "Stok tidak cukup", stok tidak berubah | |
| 14 | Anggota nonaktif | Pinjam > Rizky, buku apa pun | Ditolak "nonaktif" | |
| 15 | Jatuh tempo sebelum tanggal pinjam | Ubah tanggal jatuh tempo mundur lewat picker | Otomatis dikoreksi / ditolak oleh validasi | |
| 16 | Pengembalian | Pinjam & Kembali > Kembalikan transaksi Siti > Ya | Status Dikembalikan, stok Bumi Manusia +1, notifikasi tampil | |
| 17 | Pengembalian terlambat | Kembalikan transaksi Andi | Notifikasi "Terlambat 3 hari" | |
| 18 | Pengembalian ganda | Transaksi yang sama tidak lagi ada di daftar aktif; logika `returnLoan` juga menolak status returned | Tidak mungkin diproses dua kali | |
| 19 | Riwayat & filter | Riwayat > chip Terlambat / Dikembalikan > cari nama | Daftar menyesuaikan | |
| 20 | Dashboard sinkron | Lakukan pinjam, lalu buka Beranda | Angka berubah tanpa restart | |
| 21 | Ekspor CSV | Buku > menu > Ekspor CSV | Share sheet terbuka; simpan ke Drive/File; file terbuka di spreadsheet dengan 7 kolom | |
| 22 | Ekspor JSON | Riwayat > ikon bagikan | File JSON valid berisi seluruh transaksi | |
| 23 | Impor CSV | Siapkan CSV (di bawah) > Buku > menu > Impor CSV | Ringkasan: 2 ditambah, 1 dilewati, 2 tidak valid | |
| 24 | Persistensi | Tambah data, tutup paksa (swipe) aplikasi, buka lagi | Data masih ada | |

### Contoh CSV untuk uji impor (no. 23)

```csv
kode,judul,penulis,kategori,tahun,stok_total
IM001,Pemrograman Dasar,Tim RPL,Teknologi,2023,3
IM002,Jaringan Komputer,Tim TKJ,Teknologi,2022,2
BK001,Duplikat Laskar,Siapa Saja,Novel,2005,1
IM003,,Tanpa Judul,Novel,2020,1
IM004,Stok Salah,Penulis,Novel,2020,abc
```

## Tes otomatis (`test/bookflow_test.dart`)

Mencakup status/keterlambatan `Loan` dan validasi parsing CSV (logika murni, tanpa database).
Jalankan: `flutter test`. Hasil: **belum dijalankan**.

Transaksi SQLite (pinjam/kembali) diuji secara manual (no. 12-20) karena unit test database
memerlukan konfigurasi tambahan (`sqflite_common_ffi`) yang sengaja tidak dipakai agar proyek tetap sederhana.

## Catatan debugging yang sudah dilakukan saat penulisan (tinjauan kode, bukan eksekusi)

- Variabel bernama `late` diganti karena kata kunci kontekstual Dart.
- Promosi tipe nullable pada parameter seed diganti dengan salinan lokal.
- `FOREIGN KEY ... ON DELETE RESTRICT` ditambah pemeriksaan eksplisit agar pesan error ramah.

Catat temuan error nyata Anda di sini saat pengujian:

| Tanggal | Gejala | Penyebab | Perbaikan |
|---|---|---|---|
| | | | |
