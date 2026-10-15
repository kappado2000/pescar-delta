import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/app_store.dart';
import '../models/doc_copy.dart';

/// Galerie de copii de acte. Modifică direct lista [docs]; salvarea se face
/// de ecranul părinte.
class DocumentsEditor extends StatefulWidget {
  const DocumentsEditor({
    super.key,
    required this.docs,
    required this.presets,
    this.title = 'Copii acte',
  });

  final List<DocCopy> docs;

  /// Etichete propuse la adăugare (ex. „CI față”, „Cupon pensie”).
  final List<String> presets;
  final String title;

  @override
  State<DocumentsEditor> createState() => _DocumentsEditorState();
}

class _DocumentsEditorState extends State<DocumentsEditor> {
  Future<void> _add() async {
    final choice = await showModalBottomSheet<(String, ImageSource)>(
      useRootNavigator: true,
      context: context,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final label in widget.presets)
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: Text(label),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Fotografiază',
                      icon: const Icon(Icons.photo_camera),
                      onPressed: () =>
                          Navigator.pop(c, (label, ImageSource.camera)),
                    ),
                    IconButton(
                      tooltip: 'Din galerie',
                      icon: const Icon(Icons.photo_library),
                      onPressed: () =>
                          Navigator.pop(c, (label, ImageSource.gallery)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    final x = await ImagePicker().pickImage(
      source: choice.$2,
      maxWidth: 1800,
      imageQuality: 80,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() {
      widget.docs.add(
        DocCopy(id: newId(), label: choice.$1, base64: base64Encode(bytes)),
      );
    });
  }

  void _view(DocCopy d) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: Text(d.label),
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  setState(() => widget.docs.remove(d));
                  Navigator.pop(c);
                },
              ),
            ],
          ),
          body: InteractiveViewer(
            maxScale: 6,
            child: Center(child: Image.memory(base64Decode(d.base64))),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            TextButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Adaugă copie'),
            ),
          ],
        ),
        if (widget.docs.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Nicio copie încă (${widget.presets.take(3).join(', ')}…).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.docs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final d = widget.docs[i];
                return GestureDetector(
                  onTap: () => _view(d),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          base64Decode(d.base64),
                          width: 120,
                          height: 86,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 120,
                        child: Text(
                          d.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
