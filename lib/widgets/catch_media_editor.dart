import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../data/app_store.dart';
import '../models/catch_entry.dart';
import '../services/download/download.dart';
import '../theme.dart';

/// Pozele și video-urile unei capturi: fotografiezi / filmezi cu telefonul
/// sau alegi din galerie. Modifică direct lista [media].
class CatchMediaEditor extends StatefulWidget {
  const CatchMediaEditor({
    super.key,
    required this.catchId,
    required this.media,
    this.onCaptured,
    this.onChanged,
  });
  final String catchId;
  final List<CatchMedia> media;

  /// Apelat după o poză / un video nou (ex. ca să se ia poziția GPS).
  final VoidCallback? onCaptured;

  /// Apelat după ce lista s-a schimbat (poze adăugate / șterse), ca captura
  /// să se salveze imediat — nu doar la „Salvează”.
  final VoidCallback? onChanged;

  @override
  State<CatchMediaEditor> createState() => _CatchMediaEditorState();
}

class _CatchMediaEditorState extends State<CatchMediaEditor> {
  final _picker = ImagePicker();
  bool _busy = false;

  bool _isVideoFile(XFile f) {
    final mime = f.mimeType ?? '';
    if (mime.startsWith('video/')) return true;
    final n = f.name.toLowerCase();
    return n.endsWith('.mp4') ||
        n.endsWith('.mov') ||
        n.endsWith('.3gp') ||
        n.endsWith('.webm');
  }

  Future<void> _addFiles(List<XFile> files) async {
    if (files.isEmpty) return;
    widget.onCaptured?.call();
    final store = context.read<AppStore>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    var skippedVideos = 0;
    for (final f in files) {
      final video = _isVideoFile(f);
      final dot = f.name.lastIndexOf('.');
      final ext = dot > 0
          ? f.name.substring(dot).toLowerCase()
          : (video ? '.mp4' : '.jpg');
      if (kIsWeb) {
        // pe web nu există fișiere: pozele rămân ca text, video-urile nu
        if (video) {
          skippedVideos++;
          continue;
        }
        widget.media.add(
          CatchMedia(
            id: newId(),
            isVideo: false,
            base64: base64Encode(await f.readAsBytes()),
          ),
        );
        continue;
      }
      // pe telefon: fișierul se copiază direct în media/ (fără să treacă
      // tot prin memorie — un video lung închidea aplicația)
      final path = await store.saveCatchMedia(
        widget.catchId,
        sourcePath: f.path,
        ext: ext,
      );
      widget.media.add(CatchMedia(id: newId(), isVideo: video, path: path));
    }
    if (!mounted) return;
    setState(() => _busy = false);
    widget.onChanged?.call();
    if (skippedVideos > 0) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Video-urile se pot salva doar în aplicația de pe telefon.',
          ),
        ),
      );
    }
  }

  Future<void> _photo() async {
    final x = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 75,
    );
    if (x != null) await _addFiles([x]);
  }

  Future<void> _video() async {
    final x = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(minutes: 3),
    );
    if (x != null) await _addFiles([x]);
  }

  Future<void> _gallery() async {
    final files = await _picker.pickMultipleMedia(
      maxWidth: 1600,
      imageQuality: 75,
    );
    await _addFiles(files);
  }

  void _open(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaViewer(
          media: widget.media,
          initialIndex: index,
          onDelete: (m) async {
            await context.read<AppStore>().deleteMediaFile(m.path);
            setState(() => widget.media.remove(m));
            widget.onChanged?.call();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (media.isEmpty)
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: Sea.foam,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_outlined, size: 40, color: Sea.ocean),
                SizedBox(height: 6),
                Text('Poze și video cu captura'),
              ],
            ),
          )
        else
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: media.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _open(i),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: media.length == 1 ? 260 : 150,
                    child: MediaThumb(media: media[i]),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            TextButton.icon(
              onPressed: _busy ? null : _photo,
              icon: const Icon(Icons.photo_camera),
              label: const Text('Poză'),
            ),
            TextButton.icon(
              onPressed: _busy ? null : _video,
              icon: const Icon(Icons.videocam),
              label: const Text('Video'),
            ),
            TextButton.icon(
              onPressed: _busy ? null : _gallery,
              icon: const Icon(Icons.photo_library),
              label: const Text('Galerie'),
            ),
            if (media.isNotEmpty)
              IconButton(
                tooltip: 'Exportă pozele și video-urile',
                onPressed: _busy ? null : () => exportMedia(context, media),
                icon: const Icon(Icons.ios_share),
              ),
          ],
        ),
      ],
    );
  }
}

/// Miniatura unei poze sau a unui video (cu iconiță de redare).
class MediaThumb extends StatelessWidget {
  const MediaThumb({super.key, required this.media});
  final CatchMedia media;

  @override
  Widget build(BuildContext context) {
    if (!media.isVideo) return _photo(context, media, BoxFit.cover);
    return Container(
      decoration: const BoxDecoration(gradient: Sea.headerGradient),
      child: const Center(
        child: Icon(Icons.play_circle_fill, size: 48, color: Colors.white),
      ),
    );
  }
}

/// Vizualizare pe tot ecranul: poze cu zoom, video cu redare.
class MediaViewer extends StatefulWidget {
  const MediaViewer({
    super.key,
    required this.media,
    required this.initialIndex,
    this.onDelete,
  });
  final List<CatchMedia> media;
  final int initialIndex;
  final Future<void> Function(CatchMedia)? onDelete;

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  late final _page = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    final items = widget.media;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} / ${items.length}'),
        actions: [
          if (items.isNotEmpty)
            IconButton(
              tooltip: 'Exportă',
              icon: const Icon(Icons.ios_share),
              onPressed: () => exportMedia(context, [items[_index]]),
            ),
          if (widget.onDelete != null && items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final m = items[_index];
                await widget.onDelete!(m);
                if (!context.mounted) return;
                if (items.isEmpty) {
                  Navigator.pop(context);
                } else {
                  setState(() => _index = _index.clamp(0, items.length - 1));
                }
              },
            ),
        ],
      ),
      body: PageView.builder(
        controller: _page,
        itemCount: items.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) {
          final m = items[i];
          if (m.isVideo) return _VideoPage(key: ValueKey(m.id), media: m);
          return InteractiveViewer(
            maxScale: 6,
            child: Center(child: _photo(context, m, BoxFit.contain)),
          );
        },
      ),
    );
  }
}

class _VideoPage extends StatefulWidget {
  const _VideoPage({super.key, required this.media});
  final CatchMedia media;

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  VideoPlayerController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (kIsWeb) {
      setState(() => _error = 'Video-ul se redă în aplicația de pe telefon.');
      return;
    }
    final path = await context.read<AppStore>().mediaFilePath(
      widget.media.path,
    );
    if (path == null || !File(path).existsSync()) {
      setState(() => _error = 'Fișierul video lipsește.');
      return;
    }
    final c = VideoPlayerController.file(File(path));
    await c.initialize();
    await c.setLooping(true);
    if (!mounted) {
      await c.dispose();
      return;
    }
    setState(() => _controller = c);
    await c.play();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.white)),
      );
    }
    if (c == null) return const Center(child: CircularProgressIndicator());
    return GestureDetector(
      onTap: () => setState(() => c.value.isPlaying ? c.pause() : c.play()),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c)),
          if (!c.value.isPlaying)
            const Icon(Icons.play_circle_fill, size: 72, color: Colors.white70),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: VideoProgressIndicator(c, allowScrubbing: true),
          ),
        ],
      ),
    );
  }
}

/// O poză: din fișier (telefon) sau din text (web / copii vechi).
Widget _photo(BuildContext context, CatchMedia m, BoxFit fit) {
  Widget broken(_, _, _) => Container(
    color: Sea.foam,
    child: const Center(child: Icon(Icons.broken_image_outlined, size: 36)),
  );
  if (m.base64 != null) {
    return Image.memory(
      base64Decode(m.base64!),
      fit: fit,
      errorBuilder: broken,
    );
  }
  final file = context.read<AppStore>().mediaFile(m.path);
  if (file == null) return broken(null, null, null);
  return Image.file(file, fit: fit, errorBuilder: broken);
}

/// Exportă poze / video-uri prin meniul de partajare al telefonului (de
/// acolo: Salvează în Poze, Fișiere, WhatsApp…). Pe web le descarcă.
Future<void> exportMedia(BuildContext context, List<CatchMedia> items) async {
  final store = context.read<AppStore>();
  final messenger = ScaffoldMessenger.of(context);
  final files = <XFile>[];
  final names = <String>[];
  var n = 0;
  for (final m in items) {
    n++;
    final file = store.mediaFile(m.path);
    if (file != null && file.existsSync()) {
      final ext = file.path.split('.').last.toLowerCase();
      names.add('captura_$n.$ext');
      files.add(
        XFile(
          file.path,
          mimeType: m.isVideo
              ? (ext == 'mov' ? 'video/quicktime' : 'video/mp4')
              : 'image/jpeg',
        ),
      );
    } else if (m.base64 != null) {
      final bytes = base64Decode(m.base64!);
      final name = 'captura_$n.jpg';
      if (kIsWeb) {
        await downloadFile(bytes, name, 'image/jpeg');
        continue;
      }
      names.add(name);
      files.add(XFile.fromData(bytes, name: name, mimeType: 'image/jpeg'));
    }
  }
  if (files.isEmpty) {
    if (!kIsWeb) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Nu am găsit fișierele de exportat.')),
      );
    }
    return;
  }
  await SharePlus.instance.share(
    ShareParams(files: files, fileNameOverrides: names),
  );
}
