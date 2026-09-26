/// Remaining distance, time and arrival as a driver reads them. The library
/// hands over metres and seconds; the numbers are split into value and unit
/// for the two-style layout of the template.
library;

/// Metres rounded to 10 below 1 km, km with one decimal below 10 km, whole
/// km above: "350 m", "1,0 km" (not "1000 m"), "3,2 km", "498 km".
(String, String) formatRouteDistance(
  double meters, {
  String decimalSeparator = ',',
}) {
  final rounded = (meters / 10).round() * 10;
  if (rounded < 1000) {
    return ('$rounded', 'm');
  }
  final tenths = (meters / 100).round();
  if (tenths < 100) {
    return (
      (tenths / 10).toStringAsFixed(1).replaceAll('.', decimalSeparator),
      'km',
    );
  }
  return ('${(meters / 1000).round()}', 'km');
}

/// Hours and minutes as value/unit pairs: "35 min", "4 h 49 min", "2 h",
/// never "289 min". Below a minute it still says "1 min".
List<(String, String)> formatRouteDuration(int seconds) {
  final minutes = (seconds / 60).round();
  if (minutes < 60) {
    return [('${minutes < 1 ? 1 : minutes}', 'min')];
  }
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return [('$hours', 'h'), if (rest != 0) ('$rest', 'min')];
}

/// Arrival time as "HH:MM" and how many days after [now] it falls.
(String, int) formatArrival(DateTime now, int remainingSeconds) {
  final at = now.add(Duration(seconds: remainingSeconds));
  final time =
      '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}';
  // Calendar days in UTC, so a DST switch overnight cannot make it 23 h.
  final days = DateTime.utc(
    at.year,
    at.month,
    at.day,
  ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
  return (time, days);
}
