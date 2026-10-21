import 'dart:async';

import 'package:flutter/widgets.dart';

/// Semnalul de actualizare automată a vremii: la fiecare 30 de minute, la
/// fiecare oră nouă și când revii în aplicație (după cel puțin 10 minute).
class WeatherClock extends ChangeNotifier with WidgetsBindingObserver {
  WeatherClock() {
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _check());
  }

  late final Timer _timer;
  DateTime _last = DateTime.now();

  void _check({bool force = false}) {
    final now = DateTime.now();
    if (force ||
        now.difference(_last) >= const Duration(minutes: 30) ||
        now.hour != _last.hour) {
      _last = now;
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        DateTime.now().difference(_last) >= const Duration(minutes: 10)) {
      _check(force: true);
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

/// Un singur ceas pentru toată aplicația.
final weatherClock = WeatherClock();
