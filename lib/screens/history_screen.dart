import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/loan.dart';
import '../services/file_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/loan_tile.dart';
import '../widgets/ui_helpers.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const List<String> _filters = [
    'Semua',
    'Dipinjam',
    'Terlambat',
    'Dikembalikan',
  ];

  final _db = DatabaseHelper.instance;
  final _files = FileService();
  List<Loan> _loans = [];
  String _query = '';
  String _filter = 'Semua';
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
      final data = await _db.getAllLoans();
      if (!mounted) return;
      setState(() {
        _loans = data;
        _loading = false;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, e.message, isError: true);
    }
  }

  List<Loan> get _filtered {
    final q = _query.trim().toLowerCase();
    return _loans.where((l) {
      final statusOk = _filter == 'Semua' || l.statusLabel == _filter;
      final textOk = q.isEmpty ||
          l.memberName.toLowerCase().contains(q) ||
          l.bookTitle.toLowerCase().contains(q);
      return statusOk && textOk;
    }).toList();
  }

  Future<void> _exportJson() async {
    try {
      final all = await _db.getAllLoans();
      if (all.isEmpty) {
        if (mounted) {
          showSnack(context, 'Belum ada transaksi untuk diekspor',
              isError: true);
        }
        return;
      }
      final stats = await _db.getStats();
      final top = await _db.getTopBooks(limit: 5);
      final path =
          await _files.exportLoansToJson(all, stats: stats, topBooks: top);
      await _files.shareFile(path, text: 'Laporan peminjaman BookFlow');
      if (mounted) {
        showSnack(context, 'File JSON dibuat (${all.length} transaksi)');
      }
    } on AppException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } catch (e) {
      if (mounted) showSnack(context, 'Ekspor gagal: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Peminjaman'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Ekspor laporan JSON',
            icon: const Icon(Icons.ios_share),
            onPressed: _exportJson,
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari nama anggota atau judul buku',
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final f in _filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
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
                        icon: Icons.history,
                        title: 'Tidak ada transaksi',
                        subtitle: 'Ubah filter atau kata kunci pencarian.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: list.length,
                        itemBuilder: (_, i) => LoanTile(loan: list[i]),
                      ),
          ),
        ],
      ),
    );
  }
}