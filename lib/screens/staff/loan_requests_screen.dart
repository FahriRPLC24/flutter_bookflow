import 'package:flutter/material.dart';

import '../../database/database_helper.dart';
import '../../models/loan.dart';
import '../../models/loan_request.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/ui_helpers.dart';

class LoanRequestsScreen extends StatefulWidget {
  const LoanRequestsScreen({super.key});
  @override
  State<LoanRequestsScreen> createState() => _LoanRequestsScreenState();
}

class _LoanRequestsScreenState extends State<LoanRequestsScreen> {
  final _db = DatabaseHelper.instance;
  List<LoanRequest> _all = [];
  String _filter = 'Menunggu';
  bool _loading = true;

  static const _filters = [
    'Menunggu',
    'Disetujui',
    'Ditolak',
    'Kedaluwarsa',
    'Semua'
  ];

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
      await _db.expireOldRequests();
      final data = await _db.getAllRequests();
      if (!mounted) return;
      setState(() {
        _all = data;
        _loading = false;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, e.message, isError: true);
    }
  }

  List<LoanRequest> get _filtered {
    if (_filter == 'Semua') return _all;
    return _all.where((r) => r.statusLabel == _filter).toList();
  }

  Future<void> _approve(LoanRequest r) async {
    final loanDays = TextEditingController(text: '7');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Setujui pengajuan?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                '${r.memberName} meminjam "${r.bookTitle}" × ${r.quantity}.'),
            const SizedBox(height: 12),
            TextField(
              controller: loanDays,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Durasi pinjam (hari)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Setujui')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final days = int.tryParse(loanDays.text.trim()) ?? 7;
      await _db.approveRequest(r.id!, loanDays: days < 1 ? 7 : days);
      if (mounted) {
        showSnack(context,
            'Pengajuan disetujui. Stok berkurang & transaksi dibuat.');
      }
    } on AppException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _reject(LoanRequest r) async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tolak pengajuan?'),
        content: TextField(
          controller: note,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Alasan (opsional)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _db.rejectRequest(r.id!,
          note: note.text.trim().isEmpty ? null : note.text.trim());
      if (mounted) showSnack(context, 'Pengajuan ditolak.');
    } on AppException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      appBar: staffAppBar(context, 'Pengajuan Peminjaman'),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? const EmptyState(
                        icon: Icons.assignment_turned_in,
                        title: 'Tidak ada pengajuan',
                        subtitle: 'Belum ada pengajuan pada filter ini.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: list.length,
                        itemBuilder: (_, i) => _card(list[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _card(LoanRequest r) {
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
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(r.bookTitle,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(r.statusLabel,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('${r.memberName} • Jumlah: ${r.quantity}'),
            Text(
              'Diajukan: ${formatDate(r.requestDate)}'
              '${r.expiryDate != null ? ' • Batas: ${formatDate(r.expiryDate!)}' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (r.note != null && r.note!.isNotEmpty)
              Text('Catatan: ${r.note}',
                  style: Theme.of(context).textTheme.bodySmall),
            if (r.isPending) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _reject(r),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Tolak'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _approve(r),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Setujui'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}