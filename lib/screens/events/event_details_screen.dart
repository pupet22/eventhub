import 'package:flutter/material.dart';

import '../../models/event.dart';

class EventDetailsScreen extends StatelessWidget {
  const EventDetailsScreen({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventImage(BuildContext context) {
    final placeholder = Container(
      height: 220,
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.event, size: 64),
    );

    if (event.imageUrl.trim().isEmpty) return placeholder;

    return Image.network(
      event.imageUrl,
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
