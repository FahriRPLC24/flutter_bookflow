import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/loan.dart';
import '../widgets/empty_state.dart';
import '../widgets/loan_tile.dart';
import '../widgets/stat_card.dart';
import '../widgets/ui_helpers.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _db = DatabaseHelper.instance;
  Map<String, int> _stats = {};
  List<Loan> _recent = [];
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
      final recent = await _db.getRecentLoans(limit: 5);
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _recent = recent;
        _loading = false;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, e.message, isError: true);
    }
  }

  String _v(String key) => (_stats[key] ?? 0).toString();

  Widget _statRow(StatCard left, StatCard right) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: left),
            const SizedBox(width: 12),
            Expanded(child: right),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: staffAppBar(context, 'BookFlow'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Ringkasan Perpustakaan',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _statRow(
                    StatCard(
                        label: 'Total judul buku',
                        value: _v('titles'),
                        icon: Icons.menu_book,
                        color: Colors.indigo),
                    StatCard(
                        label: 'Total stok buku',
                        value: _v('totalStock'),
                        icon: Icons.inventory_2,
                        color: Colors.teal),
                  ),
                  _statRow(
                    StatCard(
                        label: 'Total anggota',
                        value: _v('members'),
                        icon: Icons.people,
                        color: Colors.orange.shade800),
                    StatCard(
                        label: 'Peminjaman aktif',
                        value: _v('activeLoans'),
                        icon: Icons.swap_horiz,
                        color: Colors.blue),
                  ),
                  _statRow(
                    StatCard(
                        label: 'Buku sedang dipinjam',
                        value: _v('borrowedBooks'),
                        icon: Icons.bookmark,
                        color: Colors.purple),
                    StatCard(
                        label: 'Transaksi terlambat',
                        value: _v('overdue'),
                        icon: Icons.warning_amber,
                        color: Colors.red.shade700),
                  ),
                  _statRow(
                    StatCard(
                        label: 'Pengajuan menunggu',
                        value: _v('pendingRequests'),
                        icon: Icons.assignment,
                        color: Colors.amber.shade800),
                    StatCard(
                        label: 'Total denda terkumpul',
                        value: formatRupiah(_stats['totalFine'] ?? 0),
                        icon: Icons.payments,
                        color: Colors.red.shade700),
                  ),
                  const SizedBox(height: 8),
                  Text('Transaksi Terbaru',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_recent.isEmpty)
                    const SizedBox(
                      height: 200,
                      child: EmptyState(
                        icon: Icons.receipt_long,
                        title: 'Belum ada transaksi',
                        subtitle:
                            'Buka tab Pinjam untuk mencatat peminjaman pertama.',
                      ),
                    )
                  else
                    for (final loan in _recent) LoanTile(loan: loan),
                ],
              ),
            ),
    );
  }
}