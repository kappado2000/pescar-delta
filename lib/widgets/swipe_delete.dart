import 'package:flutter/material.dart';

import '../theme.dart';

/// Cere confirmarea ștergerii unui rând numerotat (ex. „Ștergi 3. Porumb?”).
Future<bool> confirmDeleteRow(
  BuildContext context,
  int number,
  String text,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('Ștergi rândul $number?'),
      content: Text(text.trim().isEmpty ? '(rând gol)' : text.trim()),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Anulează'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Sea.coral),
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Șterge'),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Rând care se șterge glisându-l (în orice parte), după confirmare.
class SwipeToDelete extends StatelessWidget {
  const SwipeToDelete({
    super.key,
    required this.id,
    required this.number,
    required this.text,
    required this.onDelete,
    required this.child,
  });

  final String id;
  final int number;
  final String text;
  final VoidCallback onDelete;
  final Widget child;

  Widget _bg(Alignment align) => Container(
    alignment: align,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    decoration: BoxDecoration(
      color: Sea.coral,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.delete_outline, color: Colors.white),
        SizedBox(width: 6),
        Text(
          'Șterge',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('del_$id'),
      direction: DismissDirection.horizontal,
      background: _bg(Alignment.centerLeft),
      secondaryBackground: _bg(Alignment.centerRight),
      confirmDismiss: (_) => confirmDeleteRow(context, number, text),
      onDismissed: (_) => onDelete(),
      child: child,
    );
  }
}
