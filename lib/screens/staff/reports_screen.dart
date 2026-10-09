import 'package:flutter/material.dart';

import '../../database/database_helper.dart';
import '../../models/book.dart';
import '../../models/loan.dart';
import '../../services/file_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/ui_helpers.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _db = DatabaseHelper.instance;
  final _files = FileService();

  Map<String, int> _stats = {};
  List<Book> _topBooks = [];
  List<Loan> _allLoans = [];
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
      final stats = await _db.getStats();
      final top = await _db.getTopBooks(limit: 5);
      final loans = await _db.getAllLoans();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _topBooks = top;
        _allLoans = loans;
        _loading = false;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _exportRekap() async {
    try {
      if (_allLoans.isEmpty) {
        if (mounted) {
          showSnack(context, 'Belum ada transaksi untuk diekspor',
              isError: true);
        }
        return;
      }
      final path = await _files.exportLoansToJson(
        _allLoans,
        stats: _stats,
        topBooks: _topBooks,
      );
      await _files.shareFile(path, text: 'Laporan BookFlow');
      if (mounted) {
        showSnack(context, 'Laporan diekspor (${_allLoans.length} transaksi)');
      }
    } on AppException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } catch (e) {
      if (mounted) showSnack(context, 'Ekspor gagal: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final maxCount = _topBooks.isEmpty
        ? 1
        : (_topBooks.first.borrowedTotal ?? 0).clamp(1, 1 << 30);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Ekspor laporan',
            icon: const Icon(Icons.ios_share),
            onPressed: _exportRekap,
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
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Rekapitulasi',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _statCard('Total judul buku', _stats['titles'] ?? 0),
            _statCard('Total stok buku', _stats['totalStock'] ?? 0),
            _statCard('Total anggota', _stats['members'] ?? 0),
            _statCard('Peminjaman aktif', _stats['activeLoans'] ?? 0),
            _statCard('Buku sedang dipinjam', _stats['borrowedBooks'] ?? 0),
            _statCard('Transaksi terlambat', _stats['overdue'] ?? 0),
            _statCard('Pengajuan menunggu', _stats['pendingRequests'] ?? 0),
            _statCard('Total denda terkumpul', _stats['totalFine'] ?? 0,
                isMoney: true),
            const SizedBox(height: 24),
            Text('Top 5 Buku Terfavorit',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_topBooks.isEmpty)
              const EmptyState(
                icon: Icons.bar_chart,
                title: 'Belum ada data peminjaman',
              )
            else
              for (var i = 0; i < _topBooks.length; i++)
                _topBookTile(i + 1, _topBooks[i], maxCount),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, int value, {bool isMoney = false}) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        title: Text(label),
        trailing: Text(
          isMoney ? formatRupiah(value) : value.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  Widget _topBookTile(int rank, Book b, int maxCount) {
    final count = b.borrowedTotal ?? 0;
    final ratio = maxCount == 0 ? 0.0 : (count / maxCount).clamp(0.0, 1.0);
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.indigo.withValues(alpha: 0.1),
              child: Text('$rank',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.indigo)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text('${b.author} • ${b.publisher}',
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                      value: ratio, backgroundColor: Colors.grey.shade200),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text('$count×',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}