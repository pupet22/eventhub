import 'dart:html' as html;

String _key(String eventId) => 'eventhub_reminder_$eventId';

bool isEnabled(String eventId) =>
    html.window.localStorage[_key(eventId)] == 'true';

void enable(String eventId) {
  html.window.localStorage[_key(eventId)] = 'true';
}

void disable(String eventId) {
  html.window.localStorage.remove(_key(eventId));
}
