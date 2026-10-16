import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/event.dart';
import '../../repositories/registration_repository.dart';
import '../../services/reminder_notification_service.dart';

class EventDetailsScreen extends StatefulWidget {
  const EventDetailsScreen({super.key, required this.event});

  final Event event;

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  final _registrationRepository = RegistrationRepository();

  late Stream<bool> _registrationStatus;
  bool _isWorking = false;
  bool _isCheckingReminder = true;
  bool _isReminderWorking = false;
  bool _hasReminder = false;

  @override
  void initState() {
    super.initState();
    _registrationStatus = _registrationRepository.watchRegistration(
      widget.event.id,
    );
    _loadReminderStatus();
  }

  Future<void> _loadReminderStatus() async {
    if (kIsWeb) {
      _isCheckingReminder = false;
      return;
    }

    try {
      final hasReminder =
      await ReminderNotificationService.isReminderScheduled(
        widget.event.id,
      );

      if (!mounted) return;
      setState(() {
        _hasReminder = hasReminder;
        _isCheckingReminder = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCheckingReminder = false;
      });
    }
  }

  Future<void> _toggleReminder() async {
    if (kIsWeb || _isReminderWorking) return;

    setState(() => _isReminderWorking = true);

    try {
      if (_hasReminder) {
        await ReminderNotificationService.cancelReminder(widget.event.id);

        if (!mounted) return;
        setState(() => _hasReminder = false);
        _showMessage('Event reminder cancelled.');
      } else {
        final scheduled =
        await ReminderNotificationService.scheduleReminder(widget.event);

        if (!mounted) return;

        if (!scheduled) {
          _showMessage(
            'Notifications are disabled. Allow EventHub notifications in Android settings.',
          );
        } else {
          setState(() => _hasReminder = true);
          _showMessage('Reminder set for one day before the event.');
        }
      }
    } on StateError catch (error) {
      if (!mounted) return;
      _showMessage(error.message.toString());
    } catch (_) {
      if (!mounted) return;
      _showMessage('Unable to update the reminder. Please try again.');
    } finally {
      if (mounted) setState(() => _isReminderWorking = false);
    }
  }

  Future<void> _openLocationInMaps() async {
    final location = widget.event.location.trim();

    if (location.isEmpty) {
      _showMessage('There is no location for this event.');
      return;
    }

    final mapUri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': location,
    });

    try {
      final opened = await launchUrl(
        mapUri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        _showMessage('Could not open the map.');
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Could not open the map.');
      }
    }
  }

  Future<void> _register() async {
    setState(() => _isWorking = true);

    try {
      await _registrationRepository.registerForEvent(widget.event.id);
      if (!mounted) return;

      _showMessage('Registration successful.');
    } on StateError catch (error) {
      if (!mounted) return;
      _showMessage(error.message.toString());
    } catch (_) {
      if (!mounted) return;
      _showMessage('Unable to register. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _cancelRegistration() async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel registration?'),
          content: const Text(
            'You will be removed from My Events for this event.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep registration'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Cancel registration'),
            ),
          ],
        );
      },
    );

    if (shouldCancel != true) return;

    setState(() => _isWorking = true);

    try {
      await _registrationRepository.cancelRegistration(widget.event.id);

      if (!kIsWeb) {
        try {
          await ReminderNotificationService.cancelReminder(widget.event.id);
        } catch (_) {
          // Keep registration cancellation successful if reminder removal
          // fails on the device.
        }
      }

      if (!mounted) return;

      setState(() => _hasReminder = false);
      _showMessage('Registration cancelled.');
    } on StateError catch (error) {
      if (!mounted) return;
      _showMessage(error.message.toString());
    } catch (_) {
      if (!mounted) return;
      _showMessage('Unable to cancel. Please try again.');
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _eventDateAndTime(Event event, BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final startDate = localizations.formatMediumDate(event.startsAt);
    final startTime =
    TimeOfDay.fromDateTime(event.startsAt).format(context);

    final endsAt = event.endsAt;
    if (endsAt == null) {
      return '$startDate at $startTime';
    }

    final endTime = TimeOfDay.fromDateTime(endsAt).format(context);
    final sameDay = event.startsAt.year == endsAt.year &&
        event.startsAt.month == endsAt.month &&
        event.startsAt.day == endsAt.day;

    if (sameDay) {
      return '$startDate · $startTime – $endTime';
    }

    final endDate = localizations.formatMediumDate(endsAt);
    return '$startDate $startTime – $endDate $endTime';
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;

    return Scaffold(
      appBar: AppBar(title: const Text('Event details')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _eventImage(context),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Chip(label: Text(event.category)),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.calendar_today,
                    text: _eventDateAndTime(event, context),
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    text: event.location,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _openLocationInMaps,
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Open in Maps'),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'About this event',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(event.description),
                  const SizedBox(height: 24),
                  _eventActions(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventActions() {
    if (_isWorking) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<bool>(
      stream: _registrationStatus,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Text('Unable to check your registration status.');
        }

        if (snapshot.data == true) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('You are registered for this event.'),
              const SizedBox(height: 12),
              if (kIsWeb)
                Text(
                  'Event reminders are available in the Android app.',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else if (_isCheckingReminder || _isReminderWorking)
                const Center(child: CircularProgressIndicator())
              else
                OutlinedButton.icon(
                  onPressed: _toggleReminder,
                  icon: Icon(
                    _hasReminder
                        ? Icons.notifications_active
                        : Icons.notifications_none,
                  ),
                  label: Text(
                    _hasReminder
                        ? 'Cancel reminder'
                        : 'Remind me 1 day before',
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _cancelRegistration,
                child: const Text('Cancel registration'),
              ),
            ],
          );
        }

        if (!widget.event.startsAt.isAfter(DateTime.now())) {
          return const Text('This event has started. Registration is closed.');
        }

        return SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _register,
            child: const Text('Register'),
          ),
        );
      },
    );
  }

  Widget _eventImage(BuildContext context) {
    final placeholder = Container(
      height: 220,
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.event, size: 64),
    );

    if (widget.event.imageUrl.trim().isEmpty) return placeholder;

    return Image.network(
      widget.event.imageUrl,
      height: 220,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}