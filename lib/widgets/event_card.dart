import 'package:flutter/material.dart';

import '../models/event.dart';
import '../repositories/saved_event_repository.dart';
import '../screens/events/event_details_screen.dart';

class EventCard extends StatefulWidget {
  const EventCard({super.key, required this.event});

  final Event event;

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  final SavedEventRepository _savedEventRepository = SavedEventRepository();
  bool _isSaving = false;

  String _dateAndTime(BuildContext context) {
    final event = widget.event;
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatMediumDate(event.startsAt);
    final startTime = TimeOfDay.fromDateTime(event.startsAt).format(context);
    final endsAt = event.endsAt;

    if (endsAt == null) {
      return '$date · $startTime';
    }

    final endTime = TimeOfDay.fromDateTime(endsAt).format(context);
    final sameDay = event.startsAt.year == endsAt.year &&
        event.startsAt.month == endsAt.month &&
        event.startsAt.day == endsAt.day;

    if (sameDay) {
      return '$date · $startTime – $endTime';
    }

    final endDate = localizations.formatMediumDate(endsAt);
    return '$date $startTime – $endDate $endTime';
  }

  Future<void> _toggleSaved(bool isSaved) async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      if (isSaved) {
        await _savedEventRepository.removeSavedEvent(widget.event.id);
      } else {
        await _savedEventRepository.saveEvent(widget.event.id);
      }
    } on StateError catch (error) {
      if (!mounted) return;
      _showMessage(error.message.toString());
    } catch (_) {
      if (!mounted) return;
      _showMessage('Unable to update saved events. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => EventDetailsScreen(event: event),
            ),
          );
        },
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
                    Text(_dateAndTime(context)),
                    const SizedBox(height: 4),
                    Text(event.location),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              _saveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _saveButton() {
    return StreamBuilder<bool>(
      stream: _savedEventRepository.watchIsSaved(widget.event.id),
      builder: (context, snapshot) {
        final isSaved = snapshot.data ?? false;

        return IconButton(
          tooltip: isSaved ? 'Remove from saved events' : 'Save event',
          onPressed: _isSaving || snapshot.hasError
              ? null
              : () => _toggleSaved(isSaved),
          icon: _isSaving
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : Icon(
            isSaved ? Icons.favorite : Icons.favorite_border,
            color: isSaved ? const Color(0xFFFF762E) : null,
          ),
        );
      },
    );
  }

  Widget _image(BuildContext context) {
    final event = widget.event;
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