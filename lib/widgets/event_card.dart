import 'package:flutter/material.dart';

import '../models/event.dart';

class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final date = MaterialLocalizations.of(context)
        .formatMediumDate(event.startsAt);
    final time = TimeOfDay.fromDateTime(event.startsAt).format(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _image(context),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(event.category),
                  const SizedBox(height: 8),
                  Text('$date · $time'),
                  const SizedBox(height: 4),
                  Text(event.location),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _image(BuildContext context) {
    final placeholder = Container(
      width: 88,
      height: 88,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.event),
    );

    if (event.imageUrl.trim().isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        event.imageUrl,
        width: 88,
        height: 88,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder,
      ),
    );
  }
}
