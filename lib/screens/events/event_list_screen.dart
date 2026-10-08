import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/event.dart';
import '../../repositories/event_repository.dart';
import '../../widgets/event_card.dart';

class EventListScreen extends StatefulWidget {
  const EventListScreen({super.key, required this.email});

  final String email;

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  static const List<String> _categories = [
    'All',
    'Academic',
    'Sports',
    'Seminars',
    'Organization',
    'Entertainment',
  ];

  final EventRepository _repository = EventRepository();

  late Stream<List<Event>> _events;
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  void _loadEvents() {
    _events = _repository.watchEvents();
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not log out. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        actions: [
          IconButton(
            onPressed: _signOut,
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<List<Event>>(
        stream: _events,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _MessageState(
              message:
                  'Unable to load events. Check your connection and try again.',
              buttonLabel: 'Retry',
              onPressed: () {
                setState(_loadEvents);
              },
            );
          }

          final events = snapshot.data ?? const <Event>[];

          if (events.isEmpty) {
            return const _MessageState(
              message: 'There are no events to show yet.',
            );
          }

          final visibleEvents = _selectedCategory == 'All'
              ? events
              : events
                    .where(
                      (event) =>
                          event.category.toLowerCase() ==
                          _selectedCategory.toLowerCase(),
                    )
                    .toList();

          return Column(
            children: [
              SizedBox(
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: _categories.length,
                  separatorBuilder: (context, index) {
                    return const SizedBox(width: 8);
                  },
                  itemBuilder: (context, index) {
                    final category = _categories[index];

                    return FilterChip(
                      label: Text(category),
                      selected: _selectedCategory == category,
                      onSelected: (_) {
                        setState(() {
                          _selectedCategory = category;
                        });
                      },
                    );
                  },
                ),
              ),
              Expanded(
                child: visibleEvents.isEmpty
                    ? Center(child: Text('No $_selectedCategory events found.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: visibleEvents.length,
                        itemBuilder: (context, index) {
                          return EventCard(event: visibleEvents[index]);
                        },
                      ),
              ),
            ],
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
            Text(message, textAlign: TextAlign.center),
            if (buttonLabel != null && onPressed != null) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: onPressed, child: Text(buttonLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
