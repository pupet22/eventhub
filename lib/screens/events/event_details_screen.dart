import 'package:flutter/material.dart';

import '../../models/event.dart';
import '../../repositories/registration_repository.dart';

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

  @override
  void initState() {
    super.initState();
    _registrationStatus = _registrationRepository.watchRegistration(
      widget.event.id,
    );
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
      if (!mounted) return;

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

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final date = MaterialLocalizations.of(context)
        .formatMediumDate(event.startsAt);
    final time = TimeOfDay.fromDateTime(event.startsAt).format(context);

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
                  _InfoRow(icon: Icons.calendar_today, text: '$date · $time'),
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    text: event.location,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'About this event',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(event.description),
                  const SizedBox(height: 24),
                  _registrationButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _registrationButton() {
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
