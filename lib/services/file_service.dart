import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database_helper.dart';
import '../models/book.dart';
import '../models/loan.dart';

class CsvParseResult {
  final List<Book> books;
  final List<String> errors;
  const CsvParseResult(this.books, this.errors);
}

class FileService {
  static const List<String> csvHeader = [
    'kode', 'judul', 'penulis', 'penerbit', 'kategori', 'tahun', 'rak', 'stok_total', 'stok_tersedia',
  ];

  String _stamp() => DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

  Future<String> _writeTempFile(String prefix, String ext, String content) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path, '${prefix}_${_stamp()}.$ext'));
      await file.writeAsString(content, flush: true);
      return file.path;
    } on FileSystemException catch (e) {
      throw AppException('Gagal menulis file: ${e.message}');
    }
  }

  Future<String> exportBooksToCsv(List<Book> books) async {
    final rows = <List<Object?>>[csvHeader];
    for (final b in books) {
      rows.add([
        b.code, b.title, b.author, b.publisher, b.category,
        b.year ?? '', b.shelf, b.totalStock, b.availableStock,
      ]);
    }
    final text = const ListToCsvConverter().convert(rows);
    return _writeTempFile('bookflow_buku', 'csv', text);
  }

  Future<String> exportLoansToJson(
    List<Loan> loans, {
    Map<String, int>? stats,
    List<Book>? topBooks,
  }) async {
    final items = <Map<String, Object?>>[];
    for (final l in loans) items.add(l.toExportMap());
    final report = {
      'aplikasi': 'BookFlow',
      'dibuat_pada': DateTime.now().toIso8601String(),
      'statistik': stats ?? {},
      'top_5_buku': (topBooks ?? [])
          .map((b) => {
                'judul': b.title,
                'penulis': b.author,
                'penerbit': b.publisher,
                'jumlah_dipinjam': b.borrowedTotal ?? 0,
              })
          .toList(),
      'jumlah_transaksi': items.length,
      'peminjaman': items,
    };
    final text = const JsonEncoder.withIndent('  ').convert(report);
    return _writeTempFile('bookflow_laporan', 'json', text);
  }

  Future<void> shareFile(String path, {String? text}) async {
    await SharePlus.instance.share(ShareParams(files: [XFile(path)], text: text));
  }

  Future<String?> pickCsvContent() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final bytes = result.files.first.bytes;
    if (bytes == null) throw const AppException('File tidak dapat dibaca.');
    return utf8.decode(bytes, allowMalformed: true);
  }

  CsvParseResult parseBooksCsv(String content) {
    final text = content
        .replaceAll('\uFEFF', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final firstLine = text.split('\n').first;
    final delimiter =
        (firstLine.contains(';') && !firstLine.contains(',')) ? ';' : ',';

    final rows = CsvToListConverter(
      fieldDelimiter: delimiter,
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(text);
    if (rows.isEmpty) throw const AppException('File CSV kosong.');

    final header =
        rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
    final iCode = header.indexOf('kode');
    final iTitle = header.indexOf('judul');
    final iAuthor = header.indexOf('penulis');
    final iPublisher = header.indexOf('penerbit');
    final iCategory = header.indexOf('kategori');
    final iYear = header.indexOf('tahun');
    final iShelf = header.indexOf('rak');
    final iStock = header.indexOf('stok_total');
    if (iCode < 0 || iTitle < 0 || iStock < 0) {
      throw const AppException(
          'Header CSV harus memuat kolom: kode, judul, stok_total.');
    }

    String cell(List<dynamic> row, int i) =>
        (i < 0 || i >= row.length) ? '' : row[i].toString().trim();

    final books = <Book>[];
    final errors = <String>[];
    final seen = <String>{};

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      final line = i + 1;
      if (row.every((c) => c.toString().trim().isEmpty)) continue;

      final code = cell(row, iCode);
      final title = cell(row, iTitle);
      final stock = int.tryParse(cell(row, iStock));
      final yearText = cell(row, iYear);
      final year = yearText.isEmpty ? null : int.tryParse(yearText);

      if (code.isEmpty) {
        errors.add('Baris $line: kode kosong');
      } else if (title.isEmpty) {
        errors.add('Baris $line: judul kosong');
      } else if (stock == null || stock < 0) {
        errors.add('Baris $line: stok_total harus angka >= 0');
      } else if (yearText.isNotEmpty && year == null) {
        errors.add('Baris $line: tahun bukan angka');
      } else if (!seen.add(code)) {
        errors.add('Baris $line: kode "$code" dobel di dalam file');
      } else {
        books.add(Book(
          code: code,
          title: title,
          author: cell(row, iAuthor),
          publisher: cell(row, iPublisher),
          category: cell(row, iCategory),
          year: year,
          shelf: cell(row, iShelf),
          totalStock: stock,
          availableStock: stock,
        ));
      }
    }
    return CsvParseResult(books, errors);
  }
}