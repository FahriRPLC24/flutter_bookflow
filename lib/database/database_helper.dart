import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/book.dart';
import '../models/loan.dart';
import '../models/loan_request.dart';
import '../models/member.dart';
import '../models/user.dart';

/// Exception sederhana berisi pesan yang aman ditampilkan ke pengguna.
class AppException implements Exception {
  final String message;
  const AppException(this.message);
  @override
  String toString() => message;
}

/// Notifier global: nilainya dinaikkan setiap kali data berubah.
final ValueNotifier<int> dataChanged = ValueNotifier<int>(0);
void _notifyChanged() => dataChanged.value++;

/// Password default untuk anggota baru.
const String defaultMemberPassword = '123456';

/// Satu-satunya kelas yang berbicara langsung dengan SQLite.
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const String _dbName = 'bookflow.db';
  static const int _dbVersion = 3;

  Future<Database>? _dbFuture;

  Future<Database> get database => _dbFuture ??= _initDb();

  Future<Database> _initDb() async {
    final dir = await getDatabasesPath();
    final path = join(dir, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE books (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL,
        author TEXT NOT NULL DEFAULT '',
        publisher TEXT NOT NULL DEFAULT '',
        category TEXT NOT NULL DEFAULT '',
        year INTEGER,
        shelf TEXT NOT NULL DEFAULT '',
        total_stock INTEGER NOT NULL CHECK (total_stock >= 0),
        available_stock INTEGER NOT NULL CHECK (available_stock >= 0)
      )
    ''');
    await db.execute('''
      CREATE TABLE members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        member_no TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        class_name TEXT NOT NULL DEFAULT '',
        phone TEXT,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        role TEXT NOT NULL CHECK (role IN ('petugas','anggota')),
        member_id INTEGER,
        FOREIGN KEY (member_id) REFERENCES members (id) ON DELETE SET NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE loans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER NOT NULL,
        member_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL CHECK (quantity > 0),
        loan_date TEXT NOT NULL,
        due_date TEXT NOT NULL,
        return_date TEXT,
        status TEXT NOT NULL DEFAULT 'borrowed',
        fine INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE RESTRICT,
        FOREIGN KEY (member_id) REFERENCES members (id) ON DELETE RESTRICT
      )
    ''');
    await db.execute('''
      CREATE TABLE loan_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER NOT NULL,
        member_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL CHECK (quantity > 0),
        request_date TEXT NOT NULL,
        expiry_date TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        note TEXT,
        FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE,
        FOREIGN KEY (member_id) REFERENCES members (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_loans_status ON loans (status)');
    await db.execute('CREATE INDEX idx_loans_book ON loans (book_id)');
    await db.execute('CREATE INDEX idx_loans_member ON loans (member_id)');
    await db.execute('CREATE INDEX idx_req_status ON loan_requests (status)');

    await _seed(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          "ALTER TABLE books ADD COLUMN publisher TEXT NOT NULL DEFAULT ''");
      await db.execute(
          "ALTER TABLE books ADD COLUMN shelf TEXT NOT NULL DEFAULT ''");
      await db.execute(
          "ALTER TABLE loans ADD COLUMN fine INTEGER NOT NULL DEFAULT 0");
      await db.execute('''
        CREATE TABLE loan_requests (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          book_id INTEGER NOT NULL,
          member_id INTEGER NOT NULL,
          quantity INTEGER NOT NULL CHECK (quantity > 0),
          request_date TEXT NOT NULL,
          expiry_date TEXT,
          status TEXT NOT NULL DEFAULT 'pending',
          note TEXT,
          FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE,
          FOREIGN KEY (member_id) REFERENCES members (id) ON DELETE CASCADE
        )
      ''');
      await db.execute('CREATE INDEX idx_req_status ON loan_requests (status)');
    }
    if (oldVersion < 3) {
      await db.execute('DROP TABLE IF EXISTS users');
      await db.execute('''
        CREATE TABLE users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL UNIQUE,
          password TEXT NOT NULL,
          role TEXT NOT NULL CHECK (role IN ('petugas','anggota')),
          member_id INTEGER,
          FOREIGN KEY (member_id) REFERENCES members (id) ON DELETE SET NULL
        )
      ''');
      await db.insert('users', {
        'username': 'Petugas',
        'password': 'admin123',
        'role': 'petugas',
        'member_id': null,
      });
      final members = await db.query('members');
      for (final row in members) {
        final m = Member.fromMap(row);
        await db.insert(
          'users',
          {
            'username': m.name,
            'password': defaultMemberPassword,
            'role': 'anggota',
            'member_id': m.id,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
  }

  Future<void> _seed(Database db) async {
    final books = <Book>[
      const Book(code: 'BK001', title: 'Laskar Pelangi', author: 'Andrea Hirata', publisher: 'Bentang Pustaka', category: 'Novel', year: 2005, shelf: 'A-01', totalStock: 5, availableStock: 5),
      const Book(code: 'BK002', title: 'Bumi Manusia', author: 'Pramoedya Ananta Toer', publisher: 'Hasta Mitra', category: 'Novel', year: 1980, shelf: 'A-02', totalStock: 3, availableStock: 3),
      const Book(code: 'BK003', title: 'Filosofi Teras', author: 'Henry Manampiring', publisher: 'Kompas', category: 'Pengembangan Diri', year: 2018, shelf: 'B-01', totalStock: 4, availableStock: 4),
      const Book(code: 'BK004', title: 'Atomic Habits', author: 'James Clear', publisher: 'Gramedia', category: 'Pengembangan Diri', year: 2018, shelf: 'B-02', totalStock: 2, availableStock: 2),
      const Book(code: 'BK005', title: 'Algoritma dan Pemrograman', author: 'Rinaldi Munir', publisher: 'Informatika', category: 'Teknologi', year: 2011, shelf: 'C-01', totalStock: 4, availableStock: 4),
      const Book(code: 'BK006', title: 'Cantik Itu Luka', author: 'Eka Kurniawan', publisher: 'Gramedia', category: 'Novel', year: 2002, shelf: 'A-03', totalStock: 1, availableStock: 1),
      const Book(code: 'BK007', title: 'Sapiens', author: 'Yuval Noah Harari', publisher: 'Kepustakaan Populer Gramedia', category: 'Sejarah', year: 2011, shelf: 'D-01', totalStock: 3, availableStock: 3),
    ];
    final bookIds = <int>[];
    for (final b in books) {
      bookIds.add(await db.insert('books', b.toMap()));
    }

    final members = <Member>[
      const Member(memberNo: 'A001', name: 'Andi Pratama', className: 'XII RPL 1', phone: '081234567890'),
      const Member(memberNo: 'A002', name: 'Siti Nurhaliza', className: 'XII RPL 1'),
      const Member(memberNo: 'A003', name: 'Budi Santoso', className: 'XI RPL 2', phone: '085611112222'),
      const Member(memberNo: 'A004', name: 'Dewi Lestari', className: 'XI RPL 2'),
      const Member(memberNo: 'A005', name: 'Rizky Ramadhan', className: 'X RPL 1', isActive: false),
    ];
    final memberIds = <int>[];
    for (final m in members) {
      memberIds.add(await db.insert('members', m.toMap()));
    }

    await db.insert('users', {
      'username': 'Petugas',
      'password': 'admin123',
      'role': 'petugas',
      'member_id': null,
    });
    for (var i = 0; i < members.length; i++) {
      await db.insert('users', {
        'username': members[i].name,
        'password': defaultMemberPassword,
        'role': 'anggota',
        'member_id': memberIds[i],
      });
    }

    final today = dateOnly(DateTime.now());
    Future<void> sampleLoan(int bookIdx, int memberIdx, int daysAgo, int duration,
        {int? returnedAfter}) async {
      final loanDate = today.subtract(Duration(days: daysAgo));
      final dueDate = loanDate.add(Duration(days: duration));
      final ra = returnedAfter;
      final returned = ra != null;
      await db.insert('loans', {
        'book_id': bookIds[bookIdx],
        'member_id': memberIds[memberIdx],
        'quantity': 1,
        'loan_date': toDbDate(loanDate),
        'due_date': toDbDate(dueDate),
        'return_date': ra == null ? null : toDbDate(loanDate.add(Duration(days: ra))),
        'status': returned ? Loan.statusReturned : Loan.statusBorrowed,
        'fine': 0,
      });
      if (!returned) {
        await db.rawUpdate(
          'UPDATE books SET available_stock = available_stock - 1 WHERE id = ?',
          [bookIds[bookIdx]],
        );
      }
    }

    await sampleLoan(0, 0, 10, 7);
    await sampleLoan(1, 1, 1, 7);
    await sampleLoan(2, 2, 20, 7, returnedAfter: 5);
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AppException {
      rethrow;
    } on DatabaseException catch (e) {
      debugPrint('Database error: $e');
      if (e.isUniqueConstraintError()) {
        throw const AppException('Data duplikat: kode/nomor sudah dipakai.');
      }
      if (e.toString().contains('FOREIGN KEY')) {
        throw const AppException(
            'Data masih dipakai oleh transaksi peminjaman.');
      }
      throw const AppException('Terjadi kesalahan pada database.');
    }
  }

  // ================= BUKU =================

  Future<List<Book>> getAllBooks() => _guard(() async {
        final db = await database;
        final rows = await db.query('books', orderBy: 'title COLLATE NOCASE');
        return rows.map((r) => Book.fromMap(r)).toList();
      });

  Future<List<Book>> getTopBooks({int limit = 5}) => _guard(() async {
        final db = await database;
        final rows = await db.rawQuery('''
          SELECT b.*, COALESCE(SUM(l.quantity), 0) AS borrowed_total
          FROM books b
          LEFT JOIN loans l ON l.book_id = b.id
          GROUP BY b.id
          ORDER BY borrowed_total DESC, b.title COLLATE NOCASE ASC
          LIMIT ?
        ''', [limit]);
        return rows.map((r) => Book.fromMap(r)).toList();
      });

  void _validateBook(Book b) {
    if (b.code.trim().isEmpty) throw const AppException('Kode buku wajib diisi.');
    if (b.title.trim().isEmpty) {
      throw const AppException('Judul buku wajib diisi.');
    }
    if (b.publisher.trim().isEmpty) {
      throw const AppException('Penerbit wajib diisi.');
    }
    if (b.totalStock < 0) {
      throw const AppException('Stok tidak boleh negatif.');
    }
  }

  Future<int> insertBook(Book book) => _guard(() async {
        _validateBook(book);
        final db = await database;
        final dup = await db.query('books',
            where: 'code = ?', whereArgs: [book.code.trim()], limit: 1);
        if (dup.isNotEmpty) throw const AppException('Kode buku sudah dipakai.');
        final id = await db.insert('books', {
          ...book.toMap(),
          'code': book.code.trim(),
          'title': book.title.trim(),
          'publisher': book.publisher.trim(),
          'available_stock': book.totalStock,
        });
        _notifyChanged();
        return id;
      });

  Future<void> updateBook(Book book) => _guard(() async {
        _validateBook(book);
        if (book.id == null) throw const AppException('ID buku tidak valid.');
        final db = await database;
        await db.transaction((txn) async {
          final rows =
              await txn.query('books', where: 'id = ?', whereArgs: [book.id]);
          if (rows.isEmpty) throw const AppException('Buku tidak ditemukan.');
          final old = Book.fromMap(rows.first);
          final borrowed = old.borrowedCount;
          if (book.totalStock < borrowed) {
            throw AppException(
                'Stok total tidak boleh kurang dari jumlah yang sedang dipinjam ($borrowed).');
          }
          final dup = await txn.query('books',
              where: 'code = ? AND id != ?',
              whereArgs: [book.code.trim(), book.id],
              limit: 1);
          if (dup.isNotEmpty) {
            throw const AppException('Kode buku sudah dipakai.');
          }
          await txn.update(
            'books',
            {
              ...book.toMap(),
              'code': book.code.trim(),
              'title': book.title.trim(),
              'publisher': book.publisher.trim(),
              'available_stock': book.totalStock - borrowed,
            },
            where: 'id = ?',
            whereArgs: [book.id],
          );
        });
        _notifyChanged();
      });

  Future<void> deleteBook(int id) => _guard(() async {
        final db = await database;
        final used = Sqflite.firstIntValue(await db
                .rawQuery('SELECT COUNT(*) FROM loans WHERE book_id = ?', [id])) ??
            0;
        if (used > 0) {
          throw const AppException(
              'Buku tidak bisa dihapus karena sudah ada riwayat peminjamannya.');
        }
        await db.delete('books', where: 'id = ?', whereArgs: [id]);
        _notifyChanged();
      });

  Future<Map<String, int>> importBooks(List<Book> books) => _guard(() async {
        final db = await database;
        var inserted = 0;
        var skipped = 0;
        await db.transaction((txn) async {
          for (final b in books) {
            final dup = await txn.query('books',
                where: 'code = ?', whereArgs: [b.code], limit: 1);
            if (dup.isNotEmpty) {
              skipped++;
              continue;
            }
            await txn.insert(
                'books', {...b.toMap(), 'available_stock': b.totalStock});
            inserted++;
          }
        });
        _notifyChanged();
        return {'inserted': inserted, 'skipped': skipped};
      });

  // ================= ANGGOTA =================

  Future<List<Member>> getAllMembers() => _guard(() async {
        final db = await database;
        final rows = await db.query('members', orderBy: 'name COLLATE NOCASE');
        return rows.map((r) => Member.fromMap(r)).toList();
      });

  void _validateMember(Member m) {
    if (m.memberNo.trim().isEmpty) {
      throw const AppException('Nomor anggota wajib diisi.');
    }
    if (m.name.trim().isEmpty) {
      throw const AppException('Nama anggota wajib diisi.');
    }
  }

  Future<int> insertMember(Member member) => _guard(() async {
        _validateMember(member);
        final db = await database;
        late int id;
        await db.transaction((txn) async {
          final dup = await txn.query('members',
              where: 'member_no = ?',
              whereArgs: [member.memberNo.trim()],
              limit: 1);
          if (dup.isNotEmpty) {
            throw const AppException('Nomor anggota sudah dipakai.');
          }
          id = await txn.insert('members', {
            ...member.toMap(),
            'member_no': member.memberNo.trim(),
            'name': member.name.trim(),
          });
          await txn.insert('users', {
            'username': member.name.trim(),
            'password': defaultMemberPassword,
            'role': 'anggota',
            'member_id': id,
          });
        });
        _notifyChanged();
        return id;
      });

  Future<void> updateMember(Member member) => _guard(() async {
        _validateMember(member);
        if (member.id == null) {
          throw const AppException('ID anggota tidak valid.');
        }
        final db = await database;
        await db.transaction((txn) async {
          final dup = await txn.query('members',
              where: 'member_no = ? AND id != ?',
              whereArgs: [member.memberNo.trim(), member.id],
              limit: 1);
          if (dup.isNotEmpty) {
            throw const AppException('Nomor anggota sudah dipakai.');
          }
          await txn.update(
            'members',
            {
              ...member.toMap(),
              'member_no': member.memberNo.trim(),
              'name': member.name.trim(),
            },
            where: 'id = ?',
            whereArgs: [member.id],
          );
          await txn.update(
            'users',
            {'username': member.name.trim()},
            where: 'member_id = ?',
            whereArgs: [member.id],
          );
        });
        _notifyChanged();
      });

  Future<void> deleteMember(int id) => _guard(() async {
        final db = await database;
        final used = Sqflite.firstIntValue(await db.rawQuery(
                'SELECT COUNT(*) FROM loans WHERE member_id = ?', [id])) ??
            0;
        if (used > 0) {
          throw const AppException(
              'Anggota punya riwayat peminjaman, tidak bisa dihapus. Nonaktifkan saja.');
        }
        await db.transaction((txn) async {
          await txn.delete('users', where: 'member_id = ?', whereArgs: [id]);
          await txn.delete('members', where: 'id = ?', whereArgs: [id]);
        });
        _notifyChanged();
      });

  // ================= USER =================

  Future<User?> getUserById(int id) => _guard(() async {
        final db = await database;
        final rows = await db.query('users', where: 'id = ?', whereArgs: [id]);
        if (rows.isEmpty) return null;
        return User.fromMap(rows.first);
      });

  /// Ganti password user. [oldPassword] wajib benar.
  Future<void> changePassword({
    required int userId,
    required String oldPassword,
    required String newPassword,
  }) =>
      _guard(() async {
        if (newPassword.trim().length < 4) {
          throw const AppException('Password minimal 4 karakter.');
        }
        final db = await database;
        final rows =
            await db.query('users', where: 'id = ?', whereArgs: [userId]);
        if (rows.isEmpty) throw const AppException('User tidak ditemukan.');
        final user = User.fromMap(rows.first);
        if (user.password != oldPassword) {
          throw const AppException('Password lama salah.');
        }
        await db.update(
          'users',
          {'password': newPassword.trim()},
          where: 'id = ?',
          whereArgs: [userId],
        );
        _notifyChanged();
      });

  // ================= PEMINJAMAN =================

  static const String _loanSelect = '''
    SELECT l.*, m.name AS member_name, b.title AS book_title
    FROM loans l
    JOIN members m ON m.id = l.member_id
    JOIN books b ON b.id = l.book_id
  ''';

  Future<List<Loan>> getAllLoans() => _guard(() async {
        final db = await database;
        final rows = await db.rawQuery('$_loanSelect ORDER BY l.id DESC');
        return rows.map((r) => Loan.fromMap(r)).toList();
      });

  Future<List<Loan>> getActiveLoans() => _guard(() async {
        final db = await database;
        final rows = await db.rawQuery(
          "$_loanSelect WHERE l.status = ? ORDER BY l.due_date ASC",
          [Loan.statusBorrowed],
        );
        return rows.map((r) => Loan.fromMap(r)).toList();
      });

  Future<List<Loan>> getLoansByMember(int memberId) => _guard(() async {
        final db = await database;
        final rows = await db.rawQuery(
          '$_loanSelect WHERE l.member_id = ? ORDER BY l.id DESC',
          [memberId],
        );
        return rows.map((r) => Loan.fromMap(r)).toList();
      });

  Future<List<Loan>> getRecentLoans({int limit = 5}) => _guard(() async {
        final db = await database;
        final rows = await db
            .rawQuery('$_loanSelect ORDER BY l.id DESC LIMIT ?', [limit]);
        return rows.map((r) => Loan.fromMap(r)).toList();
      });

  Future<int> addLoan({
    required int memberId,
    required int bookId,
    required int quantity,
    required DateTime loanDate,
    required DateTime dueDate,
  }) =>
      _guard(() async {
        if (quantity <= 0) throw const AppException('Jumlah buku minimal 1.');
        if (dateOnly(dueDate).isBefore(dateOnly(loanDate))) {
          throw const AppException(
              'Tanggal jatuh tempo tidak boleh sebelum tanggal pinjam.');
        }
        final db = await database;
        late int newId;
        await db.transaction((txn) async {
          final mRows = await txn
              .query('members', where: 'id = ?', whereArgs: [memberId]);
          if (mRows.isEmpty) {
            throw const AppException('Anggota tidak ditemukan.');
          }
          final member = Member.fromMap(mRows.first);
          if (!member.isActive) {
            throw AppException(
                '${member.name} nonaktif dan tidak boleh meminjam.');
          }
          final bRows =
              await txn.query('books', where: 'id = ?', whereArgs: [bookId]);
          if (bRows.isEmpty) throw const AppException('Buku tidak ditemukan.');
          final book = Book.fromMap(bRows.first);
          if (book.availableStock < quantity) {
            throw AppException(
                'Stok "${book.title}" tidak cukup (tersedia ${book.availableStock}).');
          }
          newId = await txn.insert('loans', {
            'book_id': bookId,
            'member_id': memberId,
            'quantity': quantity,
            'loan_date': toDbDate(loanDate),
            'due_date': toDbDate(dueDate),
            'return_date': null,
            'status': Loan.statusBorrowed,
            'fine': 0,
          });
          await txn.update(
            'books',
            {'available_stock': book.availableStock - quantity},
            where: 'id = ?',
            whereArgs: [bookId],
          );
        });
        _notifyChanged();
        return newId;
      });

  Future<Map<String, int>> returnLoan(int loanId, DateTime returnDate) =>
      _guard(() async {
        final db = await database;
        var daysLate = 0;
        var fine = 0;
        await db.transaction((txn) async {
          final rows =
              await txn.query('loans', where: 'id = ?', whereArgs: [loanId]);
          if (rows.isEmpty) {
            throw const AppException('Transaksi tidak ditemukan.');
          }
          final loan = Loan.fromMap(rows.first);
          if (loan.status == Loan.statusReturned) {
            throw const AppException(
                'Transaksi ini sudah dikembalikan sebelumnya.');
          }
          final diff = dateOnly(returnDate).difference(loan.dueDate).inDays;
          daysLate = diff > 0 ? diff : 0;
          fine = daysLate * finePerDay;

          await txn.update(
            'loans',
            {
              'return_date': toDbDate(returnDate),
              'status': Loan.statusReturned,
              'fine': fine,
            },
            where: 'id = ? AND status = ?',
            whereArgs: [loanId, Loan.statusBorrowed],
          );
          await txn.rawUpdate(
            'UPDATE books SET available_stock = available_stock + ? WHERE id = ?',
            [loan.quantity, loan.bookId],
          );
        });
        _notifyChanged();
        return {'daysLate': daysLate, 'fine': fine};
      });

  // ================= LOAN REQUESTS =================

  static const String _reqSelect = '''
    SELECT r.*, m.name AS member_name, b.title AS book_title
    FROM loan_requests r
    JOIN members m ON m.id = r.member_id
    JOIN books b ON b.id = r.book_id
  ''';

  Future<int> createLoanRequest({
    required int memberId,
    required int bookId,
    required int quantity,
    String? note,
  }) =>
      _guard(() async {
        if (quantity <= 0) throw const AppException('Jumlah minimal 1.');
        final db = await database;
        late int id;
        await db.transaction((txn) async {
          final mRows = await txn
              .query('members', where: 'id = ?', whereArgs: [memberId]);
          if (mRows.isEmpty) {
            throw const AppException('Anggota tidak ditemukan.');
          }
          final member = Member.fromMap(mRows.first);
          if (!member.isActive) {
            throw AppException(
                '${member.name} nonaktif dan tidak boleh mengajukan.');
          }
          final bRows =
              await txn.query('books', where: 'id = ?', whereArgs: [bookId]);
          if (bRows.isEmpty) throw const AppException('Buku tidak ditemukan.');
          final book = Book.fromMap(bRows.first);
          if (book.availableStock < quantity) {
            throw AppException('Stok "${book.title}" tidak cukup.');
          }
          final dup = await txn.query(
            'loan_requests',
            where: 'member_id = ? AND book_id = ? AND status = ?',
            whereArgs: [memberId, bookId, LoanRequest.statusPending],
            limit: 1,
          );
          if (dup.isNotEmpty) {
            throw const AppException(
                'Kamu sudah mengajukan buku ini. Tunggu approval petugas.');
          }
          final now = dateOnly(DateTime.now());
          id = await txn.insert('loan_requests', {
            'book_id': bookId,
            'member_id': memberId,
            'quantity': quantity,
            'request_date': toDbDate(now),
            'expiry_date': toDbDate(now.add(const Duration(days: 2))),
            'status': LoanRequest.statusPending,
            'note': note,
          });
        });
        _notifyChanged();
        return id;
      });

  Future<List<LoanRequest>> getRequestsByMember(int memberId) =>
      _guard(() async {
        final db = await database;
        final rows = await db.rawQuery(
          '$_reqSelect WHERE r.member_id = ? ORDER BY r.id DESC',
          [memberId],
        );
        return rows.map((r) => LoanRequest.fromMap(r)).toList();
      });

  Future<List<LoanRequest>> getAllRequests({String? status}) =>
      _guard(() async {
        final db = await database;
        final rows = status == null
            ? await db.rawQuery('$_reqSelect ORDER BY r.id DESC')
            : await db.rawQuery(
                '$_reqSelect WHERE r.status = ? ORDER BY r.id DESC', [status]);
        return rows.map((r) => LoanRequest.fromMap(r)).toList();
      });

  Future<int> approveRequest(int requestId, {int loanDays = 7}) =>
      _guard(() async {
        final db = await database;
        late int loanId;
        await db.transaction((txn) async {
          final rows = await txn.query('loan_requests',
              where: 'id = ?', whereArgs: [requestId]);
          if (rows.isEmpty) {
            throw const AppException('Pengajuan tidak ditemukan.');
          }
          final req = LoanRequest.fromMap(rows.first);
          if (req.status != LoanRequest.statusPending) {
            throw const AppException('Pengajuan sudah diproses.');
          }
          final bRows =
              await txn.query('books', where: 'id = ?', whereArgs: [req.bookId]);
          if (bRows.isEmpty) throw const AppException('Buku tidak ditemukan.');
          final book = Book.fromMap(bRows.first);
          if (book.availableStock < req.quantity) {
            throw AppException(
                'Stok "${book.title}" tidak cukup saat approve.');
          }
          final mRows = await txn
              .query('members', where: 'id = ?', whereArgs: [req.memberId]);
          if (mRows.isEmpty) {
            throw const AppException('Anggota tidak ditemukan.');
          }
          final member = Member.fromMap(mRows.first);
          if (!member.isActive) {
            throw const AppException('Anggota nonaktif.');
          }

          final today = dateOnly(DateTime.now());
          loanId = await txn.insert('loans', {
            'book_id': req.bookId,
            'member_id': req.memberId,
            'quantity': req.quantity,
            'loan_date': toDbDate(today),
            'due_date': toDbDate(today.add(Duration(days: loanDays))),
            'return_date': null,
            'status': Loan.statusBorrowed,
            'fine': 0,
          });
          await txn.update(
            'books',
            {'available_stock': book.availableStock - req.quantity},
            where: 'id = ?',
            whereArgs: [req.bookId],
          );
          await txn.update(
            'loan_requests',
            {'status': LoanRequest.statusApproved},
            where: 'id = ?',
            whereArgs: [requestId],
          );
        });
        _notifyChanged();
        return loanId;
      });

  Future<void> rejectRequest(int requestId, {String? note}) =>
      _guard(() async {
        final db = await database;
        await db.update(
          'loan_requests',
          {'status': LoanRequest.statusRejected, 'note': note},
          where: 'id = ? AND status = ?',
          whereArgs: [requestId, LoanRequest.statusPending],
        );
        _notifyChanged();
      });

  Future<void> expireOldRequests() => _guard(() async {
        final db = await database;
        final today = toDbDate(DateTime.now());
        await db.update(
          'loan_requests',
          {'status': LoanRequest.statusExpired},
          where: 'status = ? AND expiry_date < ?',
          whereArgs: [LoanRequest.statusPending, today],
        );
      });

  // ================= STATISTIK =================

  Future<Map<String, int>> getStats() => _guard(() async {
        final db = await database;
        Future<int> scalar(String sql, [List<Object?>? args]) async =>
            Sqflite.firstIntValue(await db.rawQuery(sql, args)) ?? 0;

        final today = toDbDate(DateTime.now());
        return {
          'titles': await scalar('SELECT COUNT(*) FROM books'),
          'totalStock':
              await scalar('SELECT COALESCE(SUM(total_stock), 0) FROM books'),
          'members': await scalar('SELECT COUNT(*) FROM members'),
          'activeLoans':
              await scalar("SELECT COUNT(*) FROM loans WHERE status = 'borrowed'"),
          'borrowedBooks': await scalar(
              "SELECT COALESCE(SUM(quantity), 0) FROM loans WHERE status = 'borrowed'"),
          'overdue': await scalar(
              "SELECT COUNT(*) FROM loans WHERE status = 'borrowed' AND due_date < ?",
              [today]),
          'pendingRequests': await scalar(
              "SELECT COUNT(*) FROM loan_requests WHERE status = 'pending'"),
          'totalFine':
              await scalar("SELECT COALESCE(SUM(fine), 0) FROM loans"),
        };
      });
}