import 'package:flutter/material.dart';

import '../../database/database_helper.dart';
import '../../models/book.dart';
import '../../services/auth_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/ui_helpers.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});
  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _db = DatabaseHelper.instance;
  List<Book> _books = [];
  String _query = '';
  String _category = 'Semua';
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

  List<String> get _categories {
    final set = <String>{'Semua'};
    for (final b in _books) {
      if (b.category.isNotEmpty) set.add(b.category);
    }
    return set.toList()..sort();
  }

  List<Book> get _filtered {
    final q = _query.trim().toLowerCase();
    return _books.where((b) {
      final catOk = _category == 'Semua' || b.category == _category;
      final textOk = q.isEmpty ||
          b.title.toLowerCase().contains(q) ||
          b.author.toLowerCase().contains(q) ||
          b.publisher.toLowerCase().contains(q);
      return catOk && textOk;
    }).toList();
  }

  Future<void> _requestLoan(Book b) async {
    final user = AuthService.instance.currentUser;
    if (user?.memberId == null) {
      showSnack(context, 'Akun ini bukan anggota.', isError: true);
      return;
    }
    final qty = TextEditingController(text: '1');
    final note = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? error;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text('Ajukan: ${b.title}'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Stok tersedia: ${b.availableStock}'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: qty,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Jumlah', border: OutlineInputBorder()),
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      if (n == null || n < 1) return 'Minimal 1';
                      if (n > b.availableStock) return 'Melebihi stok';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: note,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Catatan (opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!,
                        style: TextStyle(
                            color: Theme.of(ctx).colorScheme.error)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal')),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  await _db.createLoanRequest(
                    memberId: user!.memberId!,
                    bookId: b.id!,
                    quantity: int.parse(qty.text.trim()),
                    note: note.text.trim().isEmpty ? null : note.text.trim(),
                  );
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx, true);
                } on AppException catch (e) {
                  setDialog(() => error = e.message);
                }
              },
              child: const Text('Ajukan'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && mounted) {
      showSnack(context,
          'Pengajuan terkirim. Tunggu approval petugas (maks 2×24 jam).');
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      appBar: AppBar(
          title: const Text('Katalog Buku'),
          backgroundColor: Colors.transparent),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari judul, penulis, atau penerbit',
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
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final c in _categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? const EmptyState(
                        icon: Icons.menu_book,
                        title: 'Buku tidak ditemukan',
                        subtitle: 'Coba ubah filter atau kata kunci.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(b.title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text('${b.author} • ${b.publisher}',
                style: Theme.of(context).textTheme.bodySmall),
            Text(
              '${b.category}${b.year != null ? ' • ${b.year}' : ''}'
              '${b.shelf.isNotEmpty ? ' • Rak ${b.shelf}' : ''}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Tersedia: ${b.availableStock}/${b.totalStock}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color:
                        habis ? Colors.red.shade700 : Colors.green.shade700,
                  ),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: habis ? null : () => _requestLoan(b),
                  icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                  label: const Text('Ajukan'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}