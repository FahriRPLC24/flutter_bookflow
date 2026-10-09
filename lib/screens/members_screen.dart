import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/member.dart';
import '../widgets/empty_state.dart';
import '../widgets/ui_helpers.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final _db = DatabaseHelper.instance;
  List<Member> _members = [];
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
      final data = await _db.getAllMembers();
      if (!mounted) return;
      setState(() {
        _members = data;
        _loading = false;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, e.message, isError: true);
    }
  }

  List<Member> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _members;
    return _members
        .where((m) =>
            m.name.toLowerCase().contains(q) ||
            m.memberNo.toLowerCase().contains(q) ||
            m.className.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _showForm([Member? member]) async {
    final isEdit = member != null;
    final formKey = GlobalKey<FormState>();
    final no = TextEditingController(text: member?.memberNo ?? '');
    final name = TextEditingController(text: member?.name ?? '');
    final cls = TextEditingController(text: member?.className ?? '');
    final phone = TextEditingController(text: member?.phone ?? '');
    var active = member?.isActive ?? true;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          final err = error;
          return AlertDialog(
            title: Text(isEdit ? 'Edit Anggota' : 'Tambah Anggota'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: no,
                      decoration:
                          const InputDecoration(labelText: 'Nomor anggota *'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Nomor wajib diisi'
                          : null,
                    ),
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Nama *'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Nama wajib diisi'
                          : null,
                    ),
                    TextFormField(
                        controller: cls,
                        decoration:
                            const InputDecoration(labelText: 'Kelas')),
                    TextFormField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                          labelText: 'Nomor telepon (opsional)'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Anggota aktif'),
                      value: active,
                      onChanged: (v) => setDialog(() => active = v),
                    ),
                    if (err != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
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
                  final phoneText = phone.text.trim();
                  final item = Member(
                    id: member?.id,
                    memberNo: no.text.trim(),
                    name: name.text.trim(),
                    className: cls.text.trim(),
                    phone: phoneText.isEmpty ? null : phoneText,
                    isActive: active,
                  );
                  try {
                    if (isEdit) {
                      await _db.updateMember(item);
                    } else {
                      await _db.insertMember(item);
                    }
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (mounted) {
                      showSnack(
                          context,
                          isEdit
                              ? 'Anggota berhasil diperbarui'
                              : 'Anggota berhasil ditambahkan');
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

  Future<void> _delete(Member m) async {
    final ok = await confirmDialog(
      context,
      title: 'Hapus anggota?',
      message: 'Anggota "${m.name}" akan dihapus permanen.',
      confirmText: 'Hapus',
    );
    if (!ok) return;
    try {
      await _db.deleteMember(m.id!);
      if (mounted) showSnack(context, 'Anggota dihapus');
    } on AppException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      appBar: staffAppBar(context, 'Data Anggota'),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _showForm(),
        icon: const Icon(Icons.person_add),
        label: const Text('Anggota'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari nama, nomor, atau kelas',
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
                        icon: Icons.people,
                        title: _query.isEmpty
                            ? 'Belum ada anggota'
                            : 'Anggota tidak ditemukan',
                        subtitle: _query.isEmpty
                            ? 'Tekan tombol + Anggota untuk menambah.'
                            : 'Coba kata kunci lain.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                        itemCount: list.length,
                        itemBuilder: (_, i) => _memberCard(list[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _memberCard(Member m) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: () => _showForm(m),
        leading: CircleAvatar(
          backgroundColor: (m.isActive ? Colors.indigo : Colors.grey)
              .withValues(alpha: 0.12),
          child: Icon(Icons.person,
              color: m.isActive ? Colors.indigo : Colors.grey),
        ),
        title:
            Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${m.memberNo} • ${m.className.isEmpty ? '-' : m.className}'
          '${m.phone != null ? '\n${m.phone}' : ''}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              m.isActive ? 'Aktif' : 'Nonaktif',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color:
                    m.isActive ? Colors.green.shade700 : Colors.grey.shade600,
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) => v == 'edit' ? _showForm(m) : _delete(m),
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