import 'package:url_launcher/url_launcher.dart';

/// Builds a Google Calendar "add event" template URL. Opens in the browser on
/// every platform (web + mobile) and lets the user save it to their own
/// calendar — no native calendar plugin or extra permissions required.
String googleCalendarUrl({
  required String title,
  required DateTime start,
  DateTime? end,
  String? details,
  String? location,
}) {
  String stamp(DateTime d) {
    final u = d.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${u.year}${two(u.month)}${two(u.day)}T'
        '${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
  }

  final e = end ?? start.add(const Duration(hours: 2));
  final params = <String, String>{
    'action': 'TEMPLATE',
    'text': title,
    'dates': '${stamp(start)}/${stamp(e)}',
    if (details != null && details.isNotEmpty) 'details': details,
    if (location != null && location.isNotEmpty) 'location': location,
  };
  final query = params.entries
      .map((kv) =>
          '${Uri.encodeComponent(kv.key)}=${Uri.encodeComponent(kv.value)}')
      .join('&');
  return 'https://calendar.google.com/calendar/render?$query';
}

/// Opens the add-to-calendar link. Returns false if no app could handle it.
Future<bool> openCalendar({
  required String title,
  required DateTime start,
  DateTime? end,
  String? details,
  String? location,
}) {
  final url = googleCalendarUrl(
    title: title,
    start: start,
    end: end,
    details: details,
    location: location,
  );
  return launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
