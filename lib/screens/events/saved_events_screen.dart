import 'package:flutter/material.dart';

import '../../models/event.dart';
import '../../repositories/saved_event_repository.dart';
import '../../widgets/event_card.dart';

const Color _savedCream = Color(0xFFFFF9F5);
const Color _savedDarkText = Color(0xFF2D2521);
const Color _savedMutedText = Color(0xFF94847A);
const Color _savedOrange = Color(0xFFFF762E);

class SavedEventsScreen extends StatefulWidget {
  const SavedEventsScreen({super.key});

  @override
  State<SavedEventsScreen> createState() => _SavedEventsScreenState();
}

class _SavedEventsScreenState extends State<SavedEventsScreen> {
  final SavedEventRepository _repository = SavedEventRepository();
  late Stream<List<Event>> _events;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  void _loadEvents() {
    _events = _repository.watchSavedEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _savedCream,
      appBar: AppBar(
        backgroundColor: _savedCream,
        title: const Text(
          'Saved',
          style: TextStyle(
            color: _savedDarkText,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: StreamBuilder<List<Event>>(
        stream: _events,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _savedOrange),
            );
          }

          if (snapshot.hasError) {
            return _MessageState(
              message: 'Unable to load saved events. Please try again.',
              buttonLabel: 'Retry',
              onPressed: () => setState(_loadEvents),
            );
          }

          final events = snapshot.data ?? const <Event>[];

          if (events.isEmpty) {
            return const _MessageState(
              message: 'You have not saved any events yet.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: events.length,
            itemBuilder: (context, index) {
              return EventCard(event: events[index]);
            },
          );
        },
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
              style: const TextStyle(
                color: _savedMutedText,
                fontSize: 16,
              ),
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