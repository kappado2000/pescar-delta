import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

enum SceneTime {
  dawn,
  day,
  dusk,
  night;

  static SceneTime of(DateTime t) => switch (t.hour) {
    >= 5 && < 8 => dawn,
    >= 8 && < 17 => day,
    >= 17 && < 21 => dusk,
    _ => night,
  };
}

/// Peisaj de Deltă desenat vectorial: cer, soare/lună, malul cu sălcii,
/// apă cu reflexii, stuf și o barcă cu pescar. Se schimbă după ora zilei.
class DeltaScene extends StatelessWidget {
  const DeltaScene({super.key, this.time, this.child});

  final SceneTime? time;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DeltaPainter(time ?? SceneTime.of(DateTime.now())),
      child: child ?? const SizedBox.expand(),
    );
  }
}

class _Palette {
  const _Palette(this.sky, this.water, this.sun, this.shore, this.glow);
  final List<Color> sky;
  final List<Color> water;
  final Color sun;
  final Color shore;
  final Color glow;
}

const _palettes = {
  SceneTime.dawn: _Palette(
    [Color(0xFF2B4C7E), Color(0xFFB87E9E), Color(0xFFF6C28B)],
    [Color(0xFFC99A8F), Color(0xFF3E5F8A), Color(0xFF1C3150)],
    Color(0xFFFFE0A3),
    Color(0xFF2A3550),
    Color(0x66FFD39A),
  ),
  SceneTime.day: _Palette(
    [Color(0xFF3A8DC1), Color(0xFF7CC4E4), Color(0xFFCDEBF5)],
    [Color(0xFF7DB9D3), Color(0xFF2C7DA8), Color(0xFF13506F)],
    Color(0xFFFFF4C9),
    Color(0xFF2F5D50),
    Color(0x55FFFFFF),
  ),
  SceneTime.dusk: _Palette(
    [Color(0xFF1D2B53), Color(0xFFB34D6A), Color(0xFFF4A259)],
    [Color(0xFFE08A5A), Color(0xFF7A3E5C), Color(0xFF1B2440)],
    Color(0xFFFFD08A),
    Color(0xFF1F1B33),
    Color(0x88F4A259),
  ),
  SceneTime.night: _Palette(
    [Color(0xFF050B1F), Color(0xFF0B2545), Color(0xFF173A63)],
    [Color(0xFF1E3D63), Color(0xFF0D2341), Color(0xFF050B1F)],
    Color(0xFFF1F4FF),
    Color(0xFF050B18),
    Color(0x44DDE6FF),
  ),
};

class _DeltaPainter extends CustomPainter {
  _DeltaPainter(this.time);
  final SceneTime time;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final p = _palettes[time]!;
    final horizon = h * 0.60;
    final rnd = Random(7);

    // Cer
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, horizon),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: p.sky,
        ).createShader(Rect.fromLTWH(0, 0, w, horizon)),
    );

    // Stele
    if (time == SceneTime.night) {
      final star = Paint()..color = Colors.white;
      for (var i = 0; i < 60; i++) {
        star.color = Colors.white.withValues(
          alpha: 0.3 + rnd.nextDouble() * 0.7,
        );
        canvas.drawCircle(
          Offset(rnd.nextDouble() * w, rnd.nextDouble() * horizon * 0.85),
          rnd.nextDouble() * 1.2 + 0.3,
          star,
        );
      }
    }

    // Soare / lună cu halo
    final sunPos = switch (time) {
      SceneTime.dawn => Offset(w * 0.78, horizon - h * 0.06),
      SceneTime.day => Offset(w * 0.80, h * 0.20),
      SceneTime.dusk => Offset(w * 0.72, horizon - h * 0.04),
      SceneTime.night => Offset(w * 0.82, h * 0.18),
    };
    final r = h * (time == SceneTime.day ? 0.07 : 0.085);
    canvas.drawCircle(
      sunPos,
      r * 3.2,
      Paint()
        ..shader = RadialGradient(colors: [p.glow, p.glow.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: sunPos, radius: r * 3.2)),
    );
    canvas.drawCircle(sunPos, r, Paint()..color = p.sun);
    if (time == SceneTime.night) {
      // semiluna: decupaj cu culoarea cerului
      canvas.drawCircle(
        sunPos.translate(r * 0.45, -r * 0.2),
        r * 0.9,
        Paint()..color = p.sky[1],
      );
    }

    // Păsări
    if (time == SceneTime.day ||
        time == SceneTime.dusk ||
        time == SceneTime.dawn) {
      final bird = Paint()
        ..color = p.shore.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;
      for (final b in [
        Offset(w * 0.30, h * 0.16),
        Offset(w * 0.35, h * 0.12),
        Offset(w * 0.40, h * 0.18),
      ]) {
        final s = h * 0.025;
        canvas.drawPath(
          Path()
            ..moveTo(b.dx - s, b.dy)
            ..quadraticBezierTo(b.dx - s / 2, b.dy - s * 0.7, b.dx, b.dy)
            ..quadraticBezierTo(b.dx + s / 2, b.dy - s * 0.7, b.dx + s, b.dy),
          bird,
        );
      }
    }

    // Malul îndepărtat cu sălcii (siluete rotunjite)
    final shore = Path()..moveTo(0, horizon);
    for (double x = 0; x <= w; x += w / 60) {
      final y =
          horizon -
          h * 0.035 -
          h * 0.03 * (0.5 + 0.5 * sin(x / w * 13)) -
          h * 0.025 * (0.5 + 0.5 * sin(x / w * 31 + 1.3));
      shore.lineTo(x, y);
    }
    shore
      ..lineTo(w, horizon)
      ..close();
    canvas.drawPath(shore, Paint()..color = p.shore.withValues(alpha: 0.85));

    // Apă
    final waterRect = Rect.fromLTWH(0, horizon, w, h - horizon);
    canvas.drawRect(
      waterRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: p.water,
        ).createShader(waterRect),
    );

    // Reflexia soarelui pe apă
    final refl = Paint()..color = p.sun.withValues(alpha: 0.55);
    for (var i = 0; i < 9; i++) {
      final y = horizon + 4 + i * (h - horizon) / 11;
      final half = r * (1.4 - i * 0.12) * (0.7 + rnd.nextDouble() * 0.6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(sunPos.dx, y),
            width: half * 2,
            height: 2.2,
          ),
          const Radius.circular(2),
        ),
        refl,
      );
    }

    // Unduiri
    final ripple = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 14; i++) {
      final x = rnd.nextDouble() * w;
      final y = horizon + 8 + rnd.nextDouble() * (h - horizon - 12);
      canvas.drawLine(
        Offset(x, y),
        Offset(x + 10 + rnd.nextDouble() * 24, y),
        ripple,
      );
    }

    // Barca cu pescarul
    final silhouette = Paint()
      ..color = Sea.navy.withValues(alpha: time == SceneTime.day ? 0.85 : 0.95);
    final bx = w * 0.38, by = horizon + (h - horizon) * 0.42;
    final bl = min(w * 0.16, h * 0.42);
    canvas.drawPath(
      Path()
        ..moveTo(bx - bl / 2, by - bl * 0.08)
        ..lineTo(bx + bl / 2, by - bl * 0.10)
        ..quadraticBezierTo(
          bx + bl * 0.42,
          by + bl * 0.06,
          bx + bl * 0.30,
          by + bl * 0.07,
        )
        ..lineTo(bx - bl * 0.34, by + bl * 0.07)
        ..quadraticBezierTo(
          bx - bl * 0.46,
          by + bl * 0.04,
          bx - bl / 2,
          by - bl * 0.08,
        )
        ..close(),
      silhouette,
    );
    // pescar așezat
    final fx = bx + bl * 0.05, fy = by - bl * 0.09;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(fx - bl * 0.05, fy - bl * 0.22, bl * 0.11, bl * 0.22),
        Radius.circular(bl * 0.04),
      ),
      silhouette,
    );
    canvas.drawCircle(
      Offset(fx + bl * 0.005, fy - bl * 0.27),
      bl * 0.05,
      silhouette,
    );
    // pălărie
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(fx, fy - bl * 0.315),
        width: bl * 0.15,
        height: bl * 0.018,
      ),
      silhouette,
    );
    // lanseta + firul
    final rodStart = Offset(fx + bl * 0.05, fy - bl * 0.14);
    final rodEnd = Offset(fx + bl * 0.75, fy - bl * 0.62);
    canvas.drawLine(
      rodStart,
      rodEnd,
      Paint()
        ..color = silhouette.color
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      Path()
        ..moveTo(rodEnd.dx, rodEnd.dy)
        ..quadraticBezierTo(
          rodEnd.dx + bl * 0.12,
          by - bl * 0.2,
          rodEnd.dx + bl * 0.1,
          by + bl * 0.02,
        ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke,
    );
    // reflexia bărcii
    canvas.drawRect(
      Rect.fromLTWH(bx - bl * 0.32, by + bl * 0.09, bl * 0.62, 2),
      Paint()..color = Sea.navy.withValues(alpha: 0.25),
    );

    // Stuf în prim-plan (stânga și dreapta)
    _reeds(canvas, size, left: true, color: silhouette.color, rnd: Random(3));
    _reeds(canvas, size, left: false, color: silhouette.color, rnd: Random(11));
  }

  void _reeds(
    Canvas canvas,
    Size size, {
    required bool left,
    required Color color,
    required Random rnd,
  }) {
    final w = size.width, h = size.height;
    final stem = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final head = Paint()..color = color;
    final count = 14;
    for (var i = 0; i < count; i++) {
      final t = i / count;
      final x = left ? t * w * 0.16 : w - t * w * 0.14;
      final height = h * (0.22 + rnd.nextDouble() * 0.30) * (1 - t * 0.5);
      final bend = (left ? 1 : -1) * (rnd.nextDouble() * 14 - 4);
      stem.strokeWidth = 1.2 + rnd.nextDouble() * 1.4;
      final top = Offset(x + bend, h - height);
      canvas.drawPath(
        Path()
          ..moveTo(x, h)
          ..quadraticBezierTo(x + bend * 0.2, h - height * 0.6, top.dx, top.dy),
        stem,
      );
      if (rnd.nextDouble() < 0.45) {
        // papură
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: top.translate(0, height * 0.08),
              width: 4.5,
              height: height * 0.16,
            ),
            const Radius.circular(3),
          ),
          head,
        );
      } else {
        // frunză curbată
        canvas.drawPath(
          Path()
            ..moveTo(x + bend * 0.1, h - height * 0.35)
            ..quadraticBezierTo(
              x + bend * 0.4 + (left ? 18 : -18),
              h - height * 0.7,
              x + bend + (left ? 26 : -26),
              h - height * 0.55,
            ),
          stem..strokeWidth = 1.2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DeltaPainter old) => old.time != time;
}

/// Bara de sus cu peisaj: titlu mare, subtitlu și acțiuni, peste scenă.
class SceneAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SceneAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.bottom,
    this.height = 132,
    this.time,
    this.caption,
  });

  final String title;
  final String? subtitle;

  /// Text în colțul din stânga jos al peisajului (ex. salutul).
  final String? caption;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final double height;
  final SceneTime? time;

  @override
  Size get preferredSize =>
      Size.fromHeight(height + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    const shadow = [Shadow(blurRadius: 8, color: Colors.black54)];
    // titlul și acțiunile stau sus; restul înălțimii rămâne pentru peisaj
    final toolbar = subtitle == null ? kToolbarHeight : 68.0;
    final rest = height - toolbar;
    return AppBar(
      toolbarHeight: toolbar,
      backgroundColor: Sea.navy,
      flexibleSpace: Stack(
        fit: StackFit.expand,
        children: [
          DeltaScene(time: time),
          // întunecare ușoară pentru lizibilitate
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66000000),
                  Color(0x00000000),
                  Color(0x33000000),
                ],
              ),
            ),
          ),
          if (caption != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 10 + (bottom?.preferredSize.height ?? 0),
              child: Text(
                caption!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  shadows: shadow,
                ),
              ),
            ),
        ],
      ),
      titleSpacing: 16,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              shadows: shadow,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                shadows: shadow,
              ),
            ),
        ],
      ),
      actions: actions,
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(
          rest + (bottom?.preferredSize.height ?? 0),
        ),
        child: Column(
          children: [
            SizedBox(height: rest),
            if (bottom != null)
              ColoredBox(
                color: Sea.navy.withValues(alpha: 0.55),
                child: bottom,
              ),
          ],
        ),
      ),
    );
  }
}
