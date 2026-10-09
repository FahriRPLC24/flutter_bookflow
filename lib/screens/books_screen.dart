import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/book.dart';
import '../services/file_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/ui_helpers.dart';

class BooksScreen extends StatefulWidget {
  const BooksScreen({super.key});

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  final _db = DatabaseHelper.instance;
  final _files = FileService();
  List<Book> _books = [];
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    dataChanged.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    dataChanged.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _db.getAllBooks();
      if (!mounted) return;
      setState(() {
        _books = data;
        _loading = false;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, e.message, isError: true);
    }
  }

  List<Book> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _books;
    return _books
        .where((b) =>
            b.title.toLowerCase().contains(q) ||
            b.author.toLowerCase().contains(q) ||
            b.publisher.toLowerCase().contains(q) ||
            b.code.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _showForm([Book? book]) async {
    final isEdit = book != null;
    final formKey = GlobalKey<FormState>();
    final code = TextEditingController(text: book?.code ?? '');
    final title = TextEditingController(text: book?.title ?? '');
    final author = TextEditingController(text: book?.author ?? '');
    final publisher = TextEditingController(text: book?.publisher ?? '');
    final category = TextEditingController(text: book?.category ?? '');
    final year = TextEditingController(text: book?.year?.toString() ?? '');
    final shelf = TextEditingController(text: book?.shelf ?? '');
    final stock =
        TextEditingController(text: book?.totalStock.toString() ?? '1');
    String? error;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          final err = error;
          return AlertDialog(
            title: Text(isEdit ? 'Edit Buku' : 'Tambah Buku'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: code,
                      decoration:
                          const InputDecoration(labelText: 'Kode buku *'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Kode wajib diisi'
                          : null,
                    ),
                    TextFormField(
                      controller: title,
                      decoration: const InputDecoration(labelText: 'Judul *'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Judul wajib diisi'
                          : null,
                    ),
                    TextFormField(
                        controller: author,
                        decoration:
                            const InputDecoration(labelText: 'Penulis')),
                    TextFormField(
                      controller: publisher,
                      decoration:
                          const InputDecoration(labelText: 'Penerbit *'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Penerbit wajib diisi'
                          : null,
                    ),
                    TextFormField(
                        controller: category,
                        decoration:
                            const InputDecoration(labelText: 'Kategori')),
                    TextFormField(
                      controller: year,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Tahun terbit'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final n = int.tryParse(v.trim());
                        if (n == null ||
                            n < 1000 ||
                            n > DateTime.now().year + 1) {
                          return 'Tahun tidak valid';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                        controller: shelf,
                        decoration: const InputDecoration(
                            labelText: 'Rak (mis. A-01)')),
                    TextFormField(
                      controller: stock,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Stok total *'),
                      validator: (v) {
                        final n = int.tryParse((v ?? '').trim());
                        if (n == null) return 'Isi dengan angka';
                        if (n < 0) return 'Stok tidak boleh negatif';
                        return null;
                      },
                    ),
                    if (err != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(err,
                            style: TextStyle(
                                color: Theme.of(ctx).colorScheme.error)),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal')),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final item = Book(
                    id: book?.id,
                    code: code.text.trim(),
                    title: title.text.trim(),
                    author: author.text.trim(),
                    publisher: publisher.text.trim(),
                    category: category.text.trim(),
                    year: int.tryParse(year.text.trim()),
                    shelf: shelf.text.trim(),
                    totalStock: int.parse(stock.text.trim()),
                    availableStock:
                        book?.availableStock ?? int.parse(stock.text.trim()),
                  );
                  try {
                    if (isEdit) {
                      await _db.updateBook(item);
                    } else {
                      await _db.insertBook(item);
                    }
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (mounted) {
                      showSnack(
                          context,
                          isEdit
                              ? 'Buku berhasil diperbarui'
                              : 'Buku berhasil ditambahkan');
                    }
                  } on AppException catch (e) {
                    setDialog(() => error = e.message);
                  }
                },
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _delete(Book b) async {
    final ok = await confirmDialog(
      context,
      title: 'Hapus buku?',
      message: 'Buku "${b.title}" akan dihapus permanen.',
      confirmText: 'Hapus',
    );
    if (!ok) return;
    try {
      await _db.deleteBook(b.id!);
      if (mounted) showSnack(context, 'Buku dihapus');
    } on AppException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _exportCsv() async {
    try {
      final books = await _db.getAllBooks();
      if (books.isEmpty) {
        if (mounted) {
          showSnack(context, 'Tidak ada data buku untuk diekspor',
              isError: true);
        }
        return;
      }
      final path = await _files.exportBooksToCsv(books);
      await _files.shareFile(path, text: 'Data buku BookFlow');
      if (mounted) showSnack(context, 'File CSV dibuat (${books.length} buku)');
    } on AppException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } catch (e) {
      if (mounted) showSnack(context, 'Ekspor gagal: $e', isError: true);
    }
  }

  Future<void> _importCsv() async {
    try {
      final content = await _files.pickCsvContent();
      if (content == null) return;
      final parsed = _files.parseBooksCsv(content);
      final saved = parsed.books.isEmpty
          ? <String, int>{'inserted': 0, 'skipped': 0}
          : await _db.importBooks(parsed.books);
      if (!mounted) return;
      final shown = parsed.errors.take(5).join('\n');
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Hasil Impor CSV'),
          content: Text(
            'Berhasil ditambahkan: ${saved['inserted']}\n'
            'Dilewati (kode sudah ada): ${saved['skipped']}\n'
            'Baris tidak valid: ${parsed.errors.length}'
            '${shown.isEmpty ? '' : '\n\n$shown'}',
          ),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
          ],
        ),
      );
    } on AppException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } catch (e) {
      if (mounted) showSnack(context, 'Impor gagal: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Buku'),
        backgroundColor: Colors.transparent,
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => v == 'export' ? _exportCsv() : _importCsv(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'export', child: Text('Ekspor CSV')),
              PopupMenuItem(value: 'import', child: Text('Impor CSV')),
            ],
          ),
          IconButton(
            tooltip: 'Ganti Password',
            icon: const Icon(Icons.password),
            onPressed: () => showChangePasswordDialog(context),
          ),
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout),
            onPressed: () => confirmLogoutDialog(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _showForm(),
        icon: const Icon(Icons.add),
        label: const Text('Buku'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari judul, penulis, penerbit, atau kode',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? EmptyState(
                        icon: Icons.menu_book,
                        title: _query.isEmpty
                            ? 'Belum ada buku'
                            : 'Buku tidak ditemukan',
                        subtitle: _query.isEmpty
                            ? 'Tekan tombol + Buku untuk menambah.'
                            : 'Coba kata kunci lain.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                        itemCount: list.length,
                        itemBuilder: (_, i) => _bookCard(list[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _bookCard(Book b) {
    final habis = b.availableStock == 0;
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: () => _showForm(b),
        leading: CircleAvatar(
          backgroundColor: Colors.indigo.withValues(alpha: 0.1),
          child: const Icon(Icons.menu_book, color: Colors.indigo),
        ),
        title: Text(b.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${b.author.isEmpty ? '-' : b.author} • ${b.publisher.isEmpty ? '-' : b.publisher}\n'
          'Kode ${b.code}${b.year != null ? ' • ${b.year}' : ''}'
          '${b.shelf.isNotEmpty ? ' • Rak ${b.shelf}' : ''}',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${b.availableStock}/${b.totalStock}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: habis
                            ? Colors.red.shade700
                            : Colors.green.shade700)),
                Text(habis ? 'habis' : 'tersedia',
                    style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            PopupMenuButton<String>(
              onSelected: (v) => v == 'edit' ? _showForm(b) : _delete(b),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Hapus')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}