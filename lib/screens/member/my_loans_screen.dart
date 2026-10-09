import 'package:flutter/material.dart';

import '../../database/database_helper.dart';
import '../../models/loan.dart';
import '../../models/loan_request.dart';
import '../../services/auth_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loan_tile.dart';
import '../../widgets/ui_helpers.dart';

class MyLoansScreen extends StatefulWidget {
  const MyLoansScreen({super.key});
  @override
  State<MyLoansScreen> createState() => _MyLoansScreenState();
}

class _MyLoansScreenState extends State<MyLoansScreen> {
  final _db = DatabaseHelper.instance;
  List<Loan> _loans = [];
  List<LoanRequest> _requests = [];
  bool _loading = true;

  int? get _memberId => AuthService.instance.currentUser?.memberId;

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
    final id = _memberId;
    if (id == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      await _db.expireOldRequests();
      final loans = await _db.getLoansByMember(id);
      final reqs = await _db.getRequestsByMember(id);
      if (!mounted) return;
      setState(() {
        _loans = loans;
        _requests = reqs;
        _loading = false;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, e.message, isError: true);
    }
  }

  List<Loan> get _active =>
      _loans.where((l) => l.status == Loan.statusBorrowed).toList();

  int get _totalFine => _loans
      .where((l) => l.status == Loan.statusReturned)
      .fold(0, (s, l) => s + l.fine);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final returned =
        _loans.where((l) => l.status == Loan.statusReturned).toList();
    return Scaffold(
      appBar: AppBar(
          title: const Text('Pinjaman Saya'),
          backgroundColor: Colors.transparent),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_active.isNotEmpty) ...[
              _buildReminderBanner(),
              const SizedBox(height: 12),
            ],
            Text('Peminjaman Aktif',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_active.isEmpty)
              const EmptyState(
                icon: Icons.check_circle_outline,
                title: 'Tidak ada pinjaman aktif',
                subtitle: 'Ajukan buku dari tab Katalog.',
              )
            else
              for (final l in _active) LoanTile(loan: l),
            const SizedBox(height: 16),
            Text('Pengajuan Saya',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_requests.isEmpty)
              const EmptyState(
                icon: Icons.assignment_outlined,
                title: 'Belum ada pengajuan',
              )
            else
              for (final r in _requests) _requestTile(r),
            const SizedBox(height: 16),
            Text('Riwayat', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (returned.isEmpty)
              const EmptyState(icon: Icons.history, title: 'Belum ada riwayat')
            else ...[
              for (final l in returned) LoanTile(loan: l),
              if (_totalFine > 0)
                Card(
                  color: Colors.red.shade50,
                  elevation: 0,
                  child: ListTile(
                    leading: const Icon(Icons.payments, color: Colors.red),
                    title: const Text('Total denda terkumpul'),
                    trailing: Text(
                      formatRupiah(_totalFine),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReminderBanner() {
    final overdue = _active.where((l) => l.isOverdue).toList();
    final dueSoon =
        _active.where((l) => !l.isOverdue && l.daysRemaining <= 2).toList();
    if (overdue.isEmpty && dueSoon.isEmpty) return const SizedBox.shrink();

    if (overdue.isNotEmpty) {
      return Card(
        color: Colors.red.shade50,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${overdue.length} buku terlambat!',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.red)),
                    Text(
                        'Segera kembalikan. Denda ${formatRupiah(finePerDay)}/hari/buku.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      color: Colors.orange.shade50,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.alarm, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${dueSoon.length} buku akan jatuh tempo dalam ≤ 2 hari. Jangan lupa dikembalikan!',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _requestTile(LoanRequest r) {
    Color color;
    switch (r.status) {
      case LoanRequest.statusApproved:
        color = Colors.green.shade700;
        break;
      case LoanRequest.statusRejected:
        color = Colors.red.shade700;
        break;
      case LoanRequest.statusExpired:
        color = Colors.grey.shade600;
        break;
      default:
        color = Colors.orange.shade800;
    }
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        title: Text(r.bookTitle,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          'Jumlah: ${r.quantity}\nDiajukan: ${formatDate(r.requestDate)}'
          '${r.expiryDate != null ? ' • Batas: ${formatDate(r.expiryDate!)}' : ''}'
          '${r.note != null && r.note!.isNotEmpty ? '\nCatatan: ${r.note}' : ''}',
        ),
        isThreeLine: true,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(r.statusLabel,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 11)),
        ),
      ),
    );
  }
}