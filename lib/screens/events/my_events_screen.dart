import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/event.dart';
import '../../repositories/registration_repository.dart';
import '../events/event_details_screen.dart';

const Color _cream = Color(0xFFFFF9F5);
const Color _darkText = Color(0xFF2D2521);
const Color _mutedText = Color(0xFF94847A);
const Color _softPeach = Color(0xFFFFEADF);
const Color _orange = Color(0xFFFF762E);
const Color _border = Color(0xFFFFE1D5);
const Color _completedBackground = Color(0xFFE5F4E9);
const Color _completedText = Color(0xFF25834A);

enum _MyEventsTab {
  upcoming,
  history,
}

class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  final RegistrationRepository _repository = RegistrationRepository();

  late Stream<List<Event>> _events;
  _MyEventsTab _selectedTab = _MyEventsTab.upcoming;
  Timer? _timeRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadEvents();

    _timeRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
          (_) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _timeRefreshTimer?.cancel();
    super.dispose();
  }

  void _loadEvents() {
    _events = _repository.watchMyEvents();
  }

  DateTime _eventEndTime(Event event) {
    return event.endsAt ?? event.startsAt;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'My events',
          style: TextStyle(
            color: _darkText,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _softPeach.withOpacity(0.7),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _TabButton(
                      label: 'Upcoming',
                      selected: _selectedTab == _MyEventsTab.upcoming,
                      onTap: () {
                        setState(() => _selectedTab = _MyEventsTab.upcoming);
                      },
                    ),
                  ),
                  Expanded(
                    child: _TabButton(
                      label: 'History',
                      selected: _selectedTab == _MyEventsTab.history,
                      onTap: () {
                        setState(() => _selectedTab = _MyEventsTab.history);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Event>>(
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
                    message: 'Unable to load your events. Please try again.',
                    buttonLabel: 'Retry',
                    onPressed: () => setState(_loadEvents),
                  );
                }

                final allEvents = snapshot.data ?? const <Event>[];
                final now = DateTime.now();

                final visibleEvents = allEvents.where((event) {
                  final isUpcoming = _eventEndTime(event).isAfter(now);
                  return _selectedTab == _MyEventsTab.upcoming
                      ? isUpcoming
                      : !isUpcoming;
                }).toList();

                if (_selectedTab == _MyEventsTab.history) {
                  visibleEvents.sort(
                        (a, b) => _eventEndTime(b).compareTo(_eventEndTime(a)),
                  );
                } else {
                  visibleEvents.sort(
                        (a, b) => a.startsAt.compareTo(b.startsAt),
                  );
                }

                if (visibleEvents.isEmpty) {
                  return _MessageState(
                    message: _selectedTab == _MyEventsTab.upcoming
                        ? 'You have no upcoming event registrations.'
                        : 'You have no completed events yet.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
                  itemCount: visibleEvents.length,
                  separatorBuilder: (context, index) =>
                  const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final event = visibleEvents[index];
                    final isCompleted =
                        _selectedTab == _MyEventsTab.history;

                    return _RegisteredEventCard(
                      event: event,
                      isCompleted: isCompleted,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RegisteredEventCard extends StatelessWidget {
  const _RegisteredEventCard({
    required this.event,
    required this.isCompleted,
  });

  final Event event;
  final bool isCompleted;

  String _dateAndTime(BuildContext context) {
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

  IconData _categoryIcon() {
    switch (event.category.toLowerCase()) {
      case 'sports':
        return Icons.emoji_events_outlined;
      case 'academic':
        return Icons.menu_book_outlined;
      case 'seminars':
        return Icons.mic_none;
      case 'organization':
        return Icons.groups_outlined;
      case 'entertainment':
        return Icons.music_note_outlined;
      default:
        return Icons.event_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusBackground =
    isCompleted ? _completedBackground : _softPeach;
    final statusColor = isCompleted ? _completedText : _orange;
    final statusLabel = isCompleted ? 'Completed' : 'Registered';

    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _border, width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => EventDetailsScreen(event: event),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EventImage(
                imageUrl: event.imageUrl,
                icon: _categoryIcon(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _darkText,
                        fontSize: 17,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      event.category,
                      style: const TextStyle(
                        color: _mutedText,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.calendar_today_outlined,
                            size: 15,
                            color: _mutedText,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _dateAndTime(context),
                            style: const TextStyle(
                              color: _mutedText,
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.location_on_outlined,
                            size: 15,
                            color: _mutedText,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            event.location,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _mutedText,
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusBackground,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventImage extends StatelessWidget {
  const _EventImage({
    required this.imageUrl,
    required this.icon,
  });

  final String imageUrl;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: _softPeach,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        icon,
        color: _orange,
        size: 32,
      ),
    );

    if (imageUrl.trim().isEmpty) {
      return placeholder;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        imageUrl,
        width: 84,
        height: 84,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder,
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? _darkText : _mutedText,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
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
                color: _mutedText,
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