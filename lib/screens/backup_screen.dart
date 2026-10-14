import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/app_store.dart';
import '../services/download/download.dart';
import '../theme.dart';

/// Exportă toate datele într-un fișier .json: în browser îl descarcă,
/// pe telefon deschide meniul de partajare. Întoarce numele fișierului.
Future<String> exportBackupFile(AppStore store) async {
  final data = await store.exportData();
  final bytes = Uint8List.fromList(utf8.encode(jsonEncode(data)));
  final name =
      'PescarDelta_copie_${DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now())}.json';
  if (kIsWeb) {
    await downloadFile(bytes, name, 'application/json');
  } else {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(bytes, name: name, mimeType: 'application/json'),
        ],
        fileNameOverrides: [name],
      ),
    );
  }
  return name;
}

/// Copie de siguranță: toate datele într-un fișier, ca să le muți pe alt
/// dispozitiv (ex. din previzualizarea de pe calculator pe telefon).
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;

  Future<void> _export() async {
    final store = context.read<AppStore>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final name = await exportBackupFile(store);
      if (kIsWeb) {
        messenger.showSnackBar(SnackBar(content: Text('Descărcat: $name')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export eșuat: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final store = context.read<AppStore>();
    final messenger = ScaffoldMessenger.of(context);
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (picked.isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      final raw = utf8.decode(await picked.single.readAsBytes());
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['app'] != 'pescar_delta') {
        throw const FormatException('Fișierul nu e o copie Pescar Deltă.');
      }
      int n(String k) => (data[k] as List?)?.length ?? 0;
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Înlocuiești datele?'),
          content: Text(
            'Copia din ${_date(data['exportedAt'])} conține:\n'
            '• ${n('participants')} participanți, ${n('boats')} bărci\n'
            '• ${n('seasons')} sezoane, ${n('catches')} capturi\n'
            '• ${n('spots')} locuri, ${n('permitFiles')} permise salvate\n\n'
            'Datele de acum din aplicație se înlocuiesc cu acestea.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Anulează'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Importă'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      await store.importData(data);
      messenger.showSnackBar(
        const SnackBar(content: Text('Datele au fost importate.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Import eșuat: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _date(dynamic iso) {
    final d = DateTime.tryParse('$iso');
    return d == null ? '?' : DateFormat('d MMMM yyyy, HH:mm').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('Copie de siguranță')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'În aplicație: ${store.participants.length} participanți, '
            '${store.boats.length} bărci, ${store.seasons.length} sezoane, '
            '${store.catches.length} capturi.',
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.upload_file,
                color: Sea.ocean,
                size: 32,
              ),
              title: const Text('Exportă toate datele'),
              subtitle: const Text(
                'Un fișier cu participanții, bărcile, sezoanele, capturile '
                '(cu poze), cheltuielile și permisele. Video-urile nu intră.',
              ),
              onTap: _busy ? null : _export,
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.download, color: Sea.teal, size: 32),
              title: const Text('Importă dintr-o copie'),
              subtitle: const Text(
                'Alegi fișierul .json (ex. din iCloud Drive). '
                'Datele de acum se înlocuiesc.',
              ),
              onTap: _busy ? null : _import,
            ),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          const SizedBox(height: 16),
          Card(
            color: Sea.sunset.withValues(alpha: 0.12),
            child: const ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('Atenție'),
              subtitle: Text(
                'Fișierul conține CNP-uri și copii de acte. Păstrează-l doar '
                'în contul tău (iCloud) și nu-l trimite altora.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
