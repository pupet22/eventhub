import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/event.dart';
import '../../repositories/registration_repository.dart';
import '../../services/reminder_notification_service.dart';

const Color _cream = Color(0xFFFFF9F5);
const Color _darkText = Color(0xFF2D2521);
const Color _mutedText = Color(0xFF94847A);
const Color _orange = Color(0xFFFF762E);

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final RegistrationRepository _repository = RegistrationRepository();
  late Stream<List<Event>> _events;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  void _loadEvents() {
    _events = _repository.watchMyEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        title: const Text('Notifications'),
      ),
      body: kIsWeb
          ? const _MessageState(
        message:
        'Event reminders are available in the EventHub Android app.',
      )
          : StreamBuilder<List<Event>>(
        stream: _events,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _orange),
            );
          }

          if (snapshot.hasError) {
            return _MessageState(
              message:
              'Unable to load your registered events. Please try again.',
              buttonLabel: 'Retry',
              onPressed: () => setState(_loadEvents),
            );
          }

          final now = DateTime.now();
          final upcomingEvents =
          (snapshot.data ?? const <Event>[]).where((event) {
            return (event.endsAt ?? event.startsAt).isAfter(now);
          }).toList()
            ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

          if (upcomingEvents.isEmpty) {
            return const _MessageState(
              message:
              'You have no upcoming registered events to set reminders for.',
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 0, 4, 16),
                child: Text(
                  'Manage reminders for your registered events. '
                      'Reminders are scheduled one day before each event.',
                  style: TextStyle(color: _mutedText),
                ),
              ),
              ...upcomingEvents.map(
                    (event) => _ReminderTile(event: event),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReminderTile extends StatefulWidget {
  const _ReminderTile({required this.event});

  final Event event;

  @override
  State<_ReminderTile> createState() => _ReminderTileState();
}

class _ReminderTileState extends State<_ReminderTile> {
  bool _isLoading = true;
  bool _isWorking = false;
  bool _isEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadReminderStatus();
  }

  Future<void> _loadReminderStatus() async {
    try {
      final isEnabled =
      await ReminderNotificationService.isReminderScheduled(
        widget.event.id,
      );

      if (!mounted) return;
      setState(() {
        _isEnabled = isEnabled;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _changeReminder(bool enable) async {
    if (_isWorking) return;

    setState(() => _isWorking = true);

    try {
      if (enable) {
        final scheduled =
        await ReminderNotificationService.scheduleReminder(widget.event);

        if (!mounted) return;

        if (!scheduled) {
          _showMessage(
            'Notifications are disabled. Allow EventHub notifications in Android settings.',
          );
        } else {
          setState(() => _isEnabled = true);
          _showMessage('Reminder set for ${widget.event.name}.');
        }
      } else {
        await ReminderNotificationService.cancelReminder(widget.event.id);

        if (!mounted) return;
        setState(() => _isEnabled = false);
        _showMessage('Reminder cancelled.');
      }
    } on StateError catch (error) {
      if (!mounted) return;
      _showMessage(error.message.toString());
    } catch (_) {
      if (!mounted) return;
      _showMessage('Unable to update the reminder. Please try again.');
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _dateAndTime(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatMediumDate(widget.event.startsAt);
    final startTime =
    TimeOfDay.fromDateTime(widget.event.startsAt).format(context);
    final endsAt = widget.event.endsAt;

    if (endsAt == null) return '$date · $startTime';

    final endTime = TimeOfDay.fromDateTime(endsAt).format(context);
    final sameDay = widget.event.startsAt.year == endsAt.year &&
        widget.event.startsAt.month == endsAt.month &&
        widget.event.startsAt.day == endsAt.day;

    if (sameDay) return '$date · $startTime – $endTime';

    final endDate = localizations.formatMediumDate(endsAt);
    return '$date $startTime – $endDate $endTime';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: SwitchListTile(
        value: _isEnabled,
        onChanged: _isLoading || _isWorking ? null : _changeReminder,
        activeThumbColor: _orange,
        secondary: _isWorking
            ? const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: _orange,
          ),
        )
            : const Icon(Icons.notifications_outlined, color: _orange),
        title: Text(
          widget.event.name,
          style: const TextStyle(
            color: _darkText,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${_dateAndTime(context)}\n${widget.event.location}',
          style: const TextStyle(color: _mutedText),
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.message,
    this.buttonLabel,
    this.onPressed,
  });

  final String message;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _mutedText),
            ),
            if (buttonLabel != null && onPressed != null) ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: onPressed,
                child: Text(buttonLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}