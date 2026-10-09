# Flowchart

Diagram memakai Mermaid (tampil otomatis di GitHub/VS Code dengan ekstensi Mermaid).
Untuk laporan UKK, gambar ulang dengan simbol flowchart standar di draw.io jika diminta.

## Peminjaman (`addLoan`)

```mermaid
flowchart TD
    A([Mulai]) --> B[Isi form: anggota, buku, jumlah, tanggal pinjam, jatuh tempo]
    B --> C{Form valid?}
    C -- Tidak --> B
    C -- Ya --> D[BEGIN TRANSACTION]
    D --> E{Anggota ada?}
    E -- Tidak --> X[Rollback + pesan error]
    E -- Ya --> F{Anggota aktif?}
    F -- Tidak --> X
    F -- Ya --> G{Buku ada?}
    G -- Tidak --> X
    G -- Ya --> H{Stok tersedia >= jumlah?}
    H -- Tidak --> X
    H -- Ya --> I[INSERT ke tabel loans, status borrowed]
    I --> J[UPDATE books: stok tersedia dikurangi jumlah]
    J --> K[COMMIT]
    K --> L[SnackBar: peminjaman berhasil]
    X --> M[Tampilkan pesan error di form]
    L --> N([Selesai])
    M --> N
```

## Pengembalian (`returnLoan`)

```mermaid
flowchart TD
    A([Mulai]) --> B[Pilih transaksi aktif, tekan Kembalikan]
    B --> C{Konfirmasi Ya?}
    C -- Tidak --> Z([Selesai])
    C -- Ya --> D[BEGIN TRANSACTION]
    D --> E{Transaksi ditemukan?}
    E -- Tidak --> X[Rollback + pesan error]
    E -- Ya --> F{Status sudah returned?}
    F -- Ya --> X
    F -- Tidak --> G[Hitung hari terlambat = tanggal kembali - jatuh tempo]
    G --> H[UPDATE loans: return_date, status = returned]
    H --> I[UPDATE books: stok tersedia ditambah jumlah]
    I --> J[COMMIT]
    J --> K[SnackBar: berhasil, tampilkan keterlambatan jika ada]
    X --> L[SnackBar error]
    K --> Z
    L --> Z
```

## Ekspor data

```mermaid
flowchart TD
    A([Mulai]) --> B[Ambil List dari SQLite]
    B --> C{Data kosong?}
    C -- Ya --> D[SnackBar: tidak ada data] --> Z([Selesai])
    C -- Tidak --> E[Ubah List menjadi baris CSV / Map JSON dengan for]
    E --> F[Tulis teks ke file di folder sementara]
    F --> G[Buka share sheet Android]
    G --> H[SnackBar: file dibuat]
    H --> Z
```
