import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../data/app_store.dart';
import '../models/season.dart';
import '../services/permit_catalog.dart';

/// Parcurge pe rând permisele necumpărate ale sezonului: deschide pagina de
/// comandă rapidă de pe permise.ddbra.ro și completează automat formularul.
/// PDF-urile descărcate la final se salvează în folderul `permise`.
class PermitBuyScreen extends StatefulWidget {
  const PermitBuyScreen({super.key, required this.seasonId, this.onlyTaskKey});
  final String seasonId;
  final String? onlyTaskKey;

  @override
  State<PermitBuyScreen> createState() => _PermitBuyScreenState();
}

class _PermitBuyScreenState extends State<PermitBuyScreen> {
  late final AppStore _store = context.read<AppStore>();
  late final Season _season = _store.season(widget.seasonId)!;
  late final List<PermitTask> _queue;
  final Set<String> _inCart = {};

  /// Linkuri care nu au întors PDF direct — lăsate să se deschidă în pagină.
  final Set<String> _allowNavigation = {};
  int _index = 0;
  bool _finishing = false;
  int _filled = 0;
  bool _loading = true;
  WebViewController? _web;

  PermitTask? get _task => _index < _queue.length ? _queue[_index] : null;

  @override
  void initState() {
    super.initState();
    final all = buildPermitTasks(
      season: _season,
      participants: _store.participants,
      boats: _store.boats,
    );
    _queue = widget.onlyTaskKey != null
        ? all.where((t) => t.key == widget.onlyTaskKey).toList()
        : all.where((t) => _season.purchased[t.key] != true).toList();
    if (!kIsWeb) {
      _web = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) => setState(() => _loading = true),
            onPageFinished: _onPageFinished,
            onNavigationRequest: _onNavigationRequest,
          ),
        );
      if (_task != null) _web!.loadRequest(Uri.parse(_task!.product.url));
    }
  }

  Future<void> _onPageFinished(String url) async {
    setState(() => _loading = false);
    final task = _task;
    if (_finishing || task == null) return;
    if (url.contains('comanda_rapida') &&
        url.contains('currentId=${task.product.id}')) {
      await _fill();
    } else {
      // După „Salvează” site-ul afișează mesajul de succes.
      final ok = await _web!.runJavaScriptReturningResult(
        "document.body.innerText.indexOf('Succes') >= 0",
      );
      if (ok == true || ok.toString() == 'true') {
        setState(() => _inCart.add(task.key));
      }
    }
  }

  Future<void> _fill() async {
    final task = _task;
    if (task == null || _web == null) return;
    final res = await _web!.runJavaScriptReturningResult(
      buildAutofillScript(task.fields),
    );
    setState(() => _filled = int.tryParse(res.toString()) ?? 0);
  }

  /// Linkurile de descărcare a permiselor → salvare în folderul „permise”.
  Future<NavigationDecision> _onNavigationRequest(NavigationRequest req) async {
    final url = req.url.toLowerCase();
    final isPdf =
        url.endsWith('.pdf') ||
        url.contains('.pdf?') ||
        url.contains('download') ||
        url.contains('descarca');
    if (!isPdf ||
        !url.contains('ddbra.ro') ||
        _allowNavigation.contains(req.url)) {
      return NavigationDecision.navigate;
    }
    _download(req.url);
    return NavigationDecision.prevent;
  }

  Future<void> _download(String url) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await http.get(Uri.parse(url));
      final type = res.headers['content-type'] ?? '';
      if (res.statusCode != 200 || !type.contains('pdf')) {
        _allowNavigation.add(url);
        await _web!.loadRequest(Uri.parse(url));
        return;
      }
      final disposition = res.headers['content-disposition'] ?? '';
      final m = RegExp(r'filename="?([^";]+)"?').firstMatch(disposition);
      final name =
          m?.group(1) ??
          'permis_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final f = await _store.addPermitFile(
        season: _season,
        fileName: name,
        bytes: res.bodyBytes,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Salvat în permise/${_season.folderName}/${f.fileName}',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Descărcare eșuată: $e')));
    }
  }

  void _next() {
    setState(() {
      _index++;
      _filled = 0;
    });
    if (_task != null) {
      _web?.loadRequest(Uri.parse(_task!.product.url));
    } else {
      _goToCart();
    }
  }

  void _goToCart() {
    setState(() => _finishing = true);
    _web?.loadRequest(Uri.parse('$ddbraBaseUrl/general?module=shop'));
  }

  Future<void> _markPaid() async {
    final keys = _inCart.isEmpty ? _queue.map((t) => t.key) : _inCart;
    for (final k in keys) {
      await _store.setPurchased(_season, k, true);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_queue.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Permise')),
        body: const Center(child: Text('Toate permisele sunt cumpărate. 🎣')),
      );
    }
    if (kIsWeb) return _WebFallback(tasks: _queue);

    final task = _task;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _finishing || task == null
              ? 'Finalizare comandă'
              : '${_index + 1}/${_queue.length} · ${task.kind.label}',
        ),
        bottom: _loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              )
            : null,
      ),
      body: Column(
        children: [
          if (task != null && !_finishing)
            _TaskBanner(task: task, filled: _filled),
          if (_finishing)
            const MaterialBanner(
              content: Text(
                'Deschide coșul și apasă „Finalizează cumpărăturile”. '
                'La final, apasă pe linkul de descărcare — permisele se '
                'salvează automat în folderul „permise”.',
              ),
              actions: [SizedBox.shrink()],
            ),
          Expanded(child: WebViewWidget(controller: _web!)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: _finishing || task == null
              ? FilledButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Am plătit — marchează cumpărate'),
                  onPressed: _markPaid,
                )
              : Row(
                  children: [
                    IconButton(
                      tooltip: 'Completează din nou',
                      icon: const Icon(Icons.refresh),
                      onPressed: _fill,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _inCart.contains(task.key)
                            ? '✓ Adăugat în coș'
                            : 'Verifică datele și apasă „Salveaza” pe pagină',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    FilledButton(
                      onPressed: _next,
                      child: Text(
                        _index + 1 < _queue.length ? 'Următorul' : 'Spre coș',
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _TaskBanner extends StatelessWidget {
  const _TaskBanner({required this.task, required this.filled});
  final PermitTask task;
  final int filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: task.ready ? scheme.primaryContainer : scheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        task.ready
            ? '${task.ownerName} · ${task.product.title}'
                  '${filled > 0 ? ' · $filled câmpuri completate' : ''}'
            : '${task.ownerName}: lipsește ${task.missing.join(', ')} — '
                  'completează pe pagină sau în fișa participantului',
      ),
    );
  }
}

/// În browser (previzualizare) nu există WebView: afișăm datele cu buton de
/// copiere și deschidem site-ul într-un tab nou.
class _WebFallback extends StatelessWidget {
  const _WebFallback({required this.tasks});
  final List<PermitTask> tasks;

  static const _labels = {
    'fname': 'Nume',
    'lname': 'Prenume',
    'cnp': 'CNP',
    'email': 'Email',
    'phone': 'Telefon',
    'country': 'Țară',
    'state': 'Județ',
    'denumire_nava': 'Denumire ambarcațiune',
    'numar_inmatriculare': 'Nr. înmatriculare',
    'capacitate_motor': 'Capacitate motor',
    'tipul_ambarcatiunii': 'Tip ambarcațiune',
    'port_inmatriculare': 'Port înmatriculare',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Permise — date de completat')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text(
                'Completarea automată merge în aplicația de pe telefon.',
              ),
              subtitle: Text('În browser poți copia datele câmp cu câmp.'),
            ),
          ),
          for (final t in tasks)
            Card(
              child: ExpansionTile(
                title: Text('${t.kind.label} — ${t.ownerName}'),
                subtitle: Text(t.product.title),
                children: [
                  for (final e in t.fields.entries)
                    ListTile(
                      dense: true,
                      title: Text(_labels[e.key] ?? 'Valabil de la'),
                      subtitle: Text(e.value.isEmpty ? '—' : e.value),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () =>
                            Clipboard.setData(ClipboardData(text: e.value)),
                      ),
                    ),
                  TextButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Deschide pagina permisului'),
                    onPressed: () => launchUrl(Uri.parse(t.product.url)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
