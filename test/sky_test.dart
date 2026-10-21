import 'package:flutter_test/flutter_test.dart';
import 'package:pescar_delta/services/weather_service.dart';
import 'package:pescar_delta/widgets/sky.dart';

void main() {
  test('starea cerului: consensul modelelor, nu un singur model', () {
    // fără ploaie: norii decid
    expect(skyCode(codes: [0, 1, 0], precip: 0, cloud: 5, temp: 15), 0);
    expect(skyCode(codes: [3, 3, 2], precip: 0, cloud: 100, temp: 15), 3);
    // un singur model cu furtună nu face furtună
    expect(
      skyCode(codes: [95, 3, 3, 61, 3], precip: 0, cloud: 90, temp: 15),
      3,
    );
    expect(
      skyCode(codes: [95, 95, 95, 61, 3], precip: 2, cloud: 90, temp: 15),
      95,
    );
    // ploaia după intensitate
    expect(skyCode(codes: [61, 63, 3], precip: 0.3, cloud: 90, temp: 15), 61);
    expect(skyCode(codes: [63, 63, 61], precip: 2, cloud: 90, temp: 15), 63);
    expect(skyCode(codes: [80, 81, 61], precip: 5, cloud: 70, temp: 15), 82);
    // ceață, ninsoare
    expect(skyCode(codes: [45, 45, 3], precip: 0, cloud: 100, temp: 5), 45);
    expect(skyCode(codes: [73, 71, 61], precip: 1.5, cloud: 100, temp: 0), 73);
    expect(skyLabel(0), 'Soare');
    expect(skyLabel(0, night: true), 'Senin');
    expect(skyLabel(63), 'Ploaie');
  });
}
