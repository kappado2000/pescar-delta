import 'dart:math';

import 'package:flutter/widgets.dart';

/// Termometrul 🌡 așezat orizontal (emoji-ul e desenat oblic).
WidgetSpan thermoSpan() => WidgetSpan(
  alignment: PlaceholderAlignment.middle,
  child: Transform.rotate(angle: pi / 4, child: const Text('🌡')),
);
