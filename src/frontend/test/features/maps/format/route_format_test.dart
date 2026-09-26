import 'package:carnine_frontend/features/maps/presentation/format/route_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('distance: metres, one decimal below 10 km, whole km above', () {
    expect(formatRouteDistance(347), ('350', 'm'));
    expect(formatRouteDistance(996), ('1,0', 'km'), reason: 'not "1000 m"');
    expect(formatRouteDistance(3240), ('3,2', 'km'));
    expect(formatRouteDistance(9960), ('10', 'km'), reason: 'not "10,0 km"');
    expect(formatRouteDistance(500600), ('501', 'km'));
    expect(formatRouteDistance(3240, decimalSeparator: '.'), ('3.2', 'km'));
  });

  test('duration in hours and minutes instead of minutes only', () {
    expect(formatRouteDuration(289 * 60), [('4', 'h'), ('49', 'min')]);
    expect(formatRouteDuration(120 * 60), [('2', 'h')]);
    expect(formatRouteDuration(35 * 60), [('35', 'min')]);
    expect(formatRouteDuration((59.6 * 60).round()), [('1', 'h')]);
    expect(formatRouteDuration(10), [('1', 'min')]);
  });

  test('arrival today, tomorrow and later', () {
    final now = DateTime(2026, 9, 26, 17, 31);
    expect(formatArrival(now, 289 * 60), ('22:20', 0));
    expect(formatArrival(now, 7 * 3600), ('00:31', 1));
    expect(formatArrival(now, 40 * 3600), ('09:31', 2));
  });

  test('arrival counts calendar days across a DST switch', () {
    // The night of 24/25 October 2026 has 25 hours in Central Europe; in
    // other time zones the check is trivially true.
    final now = DateTime(2026, 10, 24, 23, 30);
    expect(formatArrival(now, 3600).$2, 1);
  });
}
