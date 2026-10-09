import 'package:flutter/material.dart';

import '../models/loan.dart';

/// Kartu satu transaksi peminjaman, dipakai di Dashboard, Pinjam, dan Riwayat.
/// [action] opsional, contoh tombol "Kembalikan".
class LoanTile extends StatelessWidget {
  final Loan loan;
  final Widget? action;

  const LoanTile({super.key, required this.loan, this.action});

  Color get _color {
    switch (loan.statusLabel) {
      case 'Dikembalikan':
        return Colors.green.shade700;
      case 'Terlambat':
        return Colors.red.shade700;
      default:
        return Colors.indigo;
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;
    final label = loan.statusLabel == 'Terlambat'
        ? 'Terlambat ${loan.daysLate} hari'
        : loan.statusLabel;
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
                  child: Text(loan.bookTitle,
                      style: style.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(label,
                      style: style.labelSmall?.copyWith(color: _color, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('${loan.memberName} • ${loan.quantity} buku', style: style.bodyMedium),
            const SizedBox(height: 2),
            Text(
              'Pinjam ${formatDate(loan.loanDate)}  •  Tempo ${formatDate(loan.dueDate)}'
              '${loan.returnDate != null ? '  •  Kembali ${formatDate(loan.returnDate!)}' : ''}',
              style: style.bodySmall?.copyWith(color: Colors.grey.shade700),
            ),
            if (action != null) Align(alignment: Alignment.centerRight, child: action!),
          ],
        ),
      ),
    );
  }
}
