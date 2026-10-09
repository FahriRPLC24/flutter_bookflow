import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/book.dart';
import '../models/loan.dart';
import '../models/member.dart';
import '../widgets/empty_state.dart';
import '../widgets/loan_tile.dart';
import '../widgets/ui_helpers.dart';

class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  final _db = DatabaseHelper.instance;
  List<Loan> _active = [];
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
      final data = await _db.getActiveLoans();
      if (!mounted) return;
      setState(() {
        _active = data;
        _loading = false;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _return(Loan loan) async {
    final ok = await confirmDialog(
      context,
      title: 'Kembalikan buku?',
      message:
          '${loan.memberName} mengembalikan ${loan.quantity} buku "${loan.bookTitle}".\n\n'
          'Denda saat ini: ${formatRupiah(loan.estimatedFine)} '
          '(${loan.daysLate} hari × ${formatRupiah(finePerDay)})',
      confirmText: 'Kembalikan',
    );
    if (!ok) return;
    try {
      final result = await _db.returnLoan(loan.id!, DateTime.now());
      final daysLate = result['daysLate'] ?? 0;
      final fine = result['fine'] ?? 0;
      if (!mounted) return;
      if (daysLate > 0) {
        showSnack(
            context,
            'Dikembalikan. Terlambat $daysLate hari. Denda ${formatRupiah(fine)}.');
      } else {
        showSnack(context, 'Buku dikembalikan tepat waktu. Tidak ada denda.');
      }
    } on AppException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _showLoanForm() async {
    List<Member> members;
    List<Book> books;
    try {
      members = await _db.getAllMembers();
      books = await _db.getAllBooks();
    } on AppException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
      return;
    }
    if (!mounted) return;
    if (members.isEmpty || books.isEmpty) {
      showSnack(context, 'Tambahkan data anggota dan buku terlebih dahulu',
          isError: true);
      return;
    }

    final formKey = GlobalKey<FormState>();
    final qty = TextEditingController(text: '1');
    Member? member;
    Book? book;
    var loanDate = dateOnly(DateTime.now());
    var dueDate = loanDate.add(const Duration(days: 7));
    String? error;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          final err = error;

          Future<void> pickDate(bool isLoanDate) async {
            final picked = await showDatePicker(
              context: ctx,
              initialDate: isLoanDate ? loanDate : dueDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (picked == null) return;
            setDialog(() {
              if (isLoanDate) {
                loanDate = dateOnly(picked);
                if (dueDate.isBefore(loanDate)) {
                  dueDate = loanDate.add(const Duration(days: 7));
                }
              } else {
                dueDate = dateOnly(picked);
              }
            });
          }

          Widget dateField(String label, DateTime value, bool isLoanDate) {
            return InkWell(
              onTap: () => pickDate(isLoanDate),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: label,
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.calendar_today, size: 18),
                ),
                child: Text(formatDate(value)),
              ),
            );
          }

          return AlertDialog(
            title: const Text('Peminjaman Baru'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<Member>(
                      isExpanded: true,
                      initialValue: member,
                      decoration: const InputDecoration(
                          labelText: 'Anggota',
                          border: OutlineInputBorder()),
                      items: [
                        for (final m in members)
                          DropdownMenuItem(
                            value: m,
                            child: Text(
                              '${m.name} (${m.className})${m.isActive ? '' : ' - nonaktif'}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => setDialog(() => member = v),
                      validator: (v) => v == null ? 'Pilih anggota' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Book>(
                      isExpanded: true,
                      initialValue: book,
                      decoration: const InputDecoration(
                          labelText: 'Buku',
                          border: OutlineInputBorder()),
                      items: [
                        for (final b in books)
                          DropdownMenuItem(
                            value: b,
                            child: Text(
                                '${b.title} (tersedia ${b.availableStock})',
                                overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (v) => setDialog(() => book = v),
                      validator: (v) => v == null ? 'Pilih buku' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: qty,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Jumlah buku',
                          border: OutlineInputBorder()),
                      validator: (v) {
                        final n = int.tryParse((v ?? '').trim());
                        if (n == null || n < 1) return 'Minimal 1';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    dateField('Tanggal pinjam', loanDate, true),
                    const SizedBox(height: 12),
                    dateField('Tanggal jatuh tempo', dueDate, false),
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
                  final m = member;
                  final b = book;
                  if (m == null || b == null) return;
                  try {
                    await _db.addLoan(
                      memberId: m.id!,
                      bookId: b.id!,
                      quantity: int.parse(qty.text.trim()),
                      loanDate: loanDate,
                      dueDate: dueDate,
                    );
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (mounted) {
                      showSnack(
                          context,
                          'Peminjaman "${b.title}" oleh ${m.name} berhasil disimpan');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: staffAppBar(context, 'Pinjam & Kembali'),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _showLoanForm,
        icon: const Icon(Icons.add),
        label: const Text('Pinjam Buku'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _active.isEmpty
              ? const EmptyState(
                  icon: Icons.check_circle_outline,
                  title: 'Tidak ada peminjaman aktif',
                  subtitle:
                      'Tekan tombol Pinjam Buku untuk mencatat peminjaman.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                  itemCount: _active.length,
                  itemBuilder: (_, i) {
                    final loan = _active[i];
                    return LoanTile(
                      loan: loan,
                      action: TextButton.icon(
                        onPressed: () => _return(loan),
                        icon: const Icon(Icons.assignment_return, size: 18),
                        label: const Text('Kembalikan'),
                      ),
                    );
                  },
                ),
    );
  }
}