import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../services/auth_service.dart';

void showSnack(BuildContext context, String message, {bool isError = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor:
          isError ? Theme.of(context).colorScheme.error : Colors.green.shade700,
    ),
  );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = 'Ya',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmText)),
      ],
    ),
  );
  return result ?? false;
}

/// AppBar standar untuk halaman petugas, dengan tombol ganti password & logout.
PreferredSizeWidget staffAppBar(BuildContext context, String title) {
  return AppBar(
    title: Text(title),
    backgroundColor: Colors.transparent,
    actions: [
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
  );
}

Future<void> confirmLogoutDialog(BuildContext context) async {
  final ok = await confirmDialog(
    context,
    title: 'Keluar?',
    message: 'Yakin ingin keluar dari akun ini?',
    confirmText: 'Keluar',
  );
  if (ok != true) return;
  await AuthService.instance.logout();
}

Future<void> showChangePasswordDialog(BuildContext context) async {
  final user = AuthService.instance.currentUser;
  if (user == null) return;
  final oldPass = TextEditingController();
  final newPass = TextEditingController();
  final confirmPass = TextEditingController();
  final formKey = GlobalKey<FormState>();
  String? error;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialog) => AlertDialog(
        title: const Text('Ganti Password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: oldPass,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Password lama', border: OutlineInputBorder()),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: newPass,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Password baru', border: OutlineInputBorder()),
                validator: (v) {
                  if (v == null || v.trim().length < 4) {
                    return 'Minimal 4 karakter';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: confirmPass,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Ulangi password baru',
                    border: OutlineInputBorder()),
                validator: (v) => v != newPass.text ? 'Tidak cocok' : null,
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!,
                    style:
                        TextStyle(color: Theme.of(ctx).colorScheme.error)),
              ],
            ],
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
                await DatabaseHelper.instance.changePassword(
                  userId: user.id!,
                  oldPassword: oldPass.text,
                  newPassword: newPass.text.trim(),
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx, true);
              } on AppException catch (e) {
                setDialog(() => error = e.message);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    ),
  );

  if (ok == true && context.mounted) {
    showSnack(context, 'Password berhasil diubah');
  }
}