import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/event.dart';
import '../../repositories/event_repository.dart';
import '../../widgets/event_card.dart';
import '../profile/notifications_screen.dart';
import '../profile/profile_screen.dart';
import 'my_events_screen.dart';
import 'saved_events_screen.dart';

const Color _cream = Color(0xFFFFF9F5);
const Color _darkText = Color(0xFF2D2521);
const Color _mutedText = Color(0xFF94847A);
const Color _softPeach = Color(0xFFFFEADF);
const Color _orange = Color(0xFFFF762E);
const Color _border = Color(0xFFFFDFD3);

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
  final TextEditingController _searchController = TextEditingController();

  late Stream<List<Event>> _events;
  Timer? _timeRefreshTimer;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  int _selectedTab = 0;
  bool _showPastEvents = false;

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
    _searchController.dispose();
    super.dispose();
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

  List<Event> _filteredEvents(List<Event> events) {
    final query = _searchQuery.trim().toLowerCase();

    return events.where((event) {
      final matchesCategory = _selectedCategory == 'All' ||
          event.category.toLowerCase() == _selectedCategory.toLowerCase();

      final matchesSearch = query.isEmpty ||
          event.name.toLowerCase().contains(query) ||
          event.location.toLowerCase().contains(query) ||
          event.category.toLowerCase().contains(query);

      return matchesCategory && matchesSearch;
    }).toList();
  }

  DateTime _eventEndTime(Event event) {
    return event.endsAt ?? event.startsAt;
  }

  List<Event> _upcomingEvents(List<Event> events) {
    final now = DateTime.now();

    final upcoming = events
        .where((event) => _eventEndTime(event).isAfter(now))
        .toList();

    upcoming.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return upcoming;
  }

  List<Event> _pastEvents(List<Event> events) {
    final now = DateTime.now();

    final past = events
        .where((event) => !_eventEndTime(event).isAfter(now))
        .toList();

    past.sort(
          (a, b) => _eventEndTime(b).compareTo(_eventEndTime(a)),
    );
    return past;
  }

  String get _greetingName {
    final displayName = FirebaseAuth.instance.currentUser?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName.split(' ').first;
    }

    final emailName = widget.email.split('@').first.trim();
    return emailName.isEmpty ? 'User' : emailName;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
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
              debugPrint('Events load error: ${snapshot.error}');
              debugPrintStack(stackTrace: snapshot.stackTrace);

              return _MessageState(
                message:
                'Unable to load events. Check your connection and try again.',
                buttonLabel: 'Retry',
                onPressed: () => setState(_loadEvents),
              );
            }

            final allEvents = snapshot.data ?? const <Event>[];
            return _buildSelectedTab(allEvents);
          },
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab,
        onTap: (index) => setState(() => _selectedTab = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: _orange,
        unselectedItemColor: _mutedText,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            activeIcon: Icon(Icons.favorite),
            label: 'Saved',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.confirmation_number_outlined),
            activeIcon: Icon(Icons.confirmation_number),
            label: 'Tickets',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedTab(List<Event> allEvents) {
    switch (_selectedTab) {
      case 0:
        return _buildHome(allEvents);
      case 1:
        return _buildExplore(allEvents);
      case 2:
        return const SavedEventsScreen();
      case 3:
        return const MyEventsScreen();
      case 4:
        return _buildProfile();
      default:
        return _buildHome(allEvents);
    }
  }

  Widget _buildHome(List<Event> allEvents) {
    final visibleEvents = _filteredEvents(_upcomingEvents(allEvents));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hi, $_greetingName',
                    style: const TextStyle(
                      color: _mutedText,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Discover events',
                    style: TextStyle(
                      color: _darkText,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const NotificationsScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.notifications_none),
              color: _darkText,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: _border),
                minimumSize: const Size(48, 48),
              ),
              tooltip: 'Notifications',
            ),
          ],
        ),
        const SizedBox(height: 20),
        _searchField(),
        const SizedBox(height: 16),
        _categoryChips(),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Upcoming events',
                style: TextStyle(
                  color: _darkText,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _showPastEvents = false;
                  _selectedTab = 1;
                });
              },
              child: const Text(
                'See all',
                style: TextStyle(color: _orange, fontSize: 15),
              ),
            ),
          ],
        ),
        if (visibleEvents.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 32),
            child: _InlineEmptyState(
              message: 'No upcoming events match your search.',
            ),
          )
        else
          ...visibleEvents.take(5).map((event) => EventCard(event: event)),
      ],
    );
  }

  Widget _buildExplore(List<Event> allEvents) {
    final dateFilteredEvents =
    _showPastEvents ? _pastEvents(allEvents) : _upcomingEvents(allEvents);
    final visibleEvents = _filteredEvents(dateFilteredEvents);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      children: [
        const Text(
          'Explore',
          style: TextStyle(
            color: _darkText,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 18),
        _searchField(),
        const SizedBox(height: 16),
        _timeFilter(),
        const SizedBox(height: 20),
        const Text(
          'Browse by category',
          style: TextStyle(
            color: _darkText,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        _categoryChips(),
        const SizedBox(height: 20),
        if (visibleEvents.isEmpty)
          _InlineEmptyState(
            message: _showPastEvents
                ? 'No past events match your search or selected category.'
                : 'No upcoming events match your search or selected category.',
          )
        else
          ...visibleEvents.map((event) => EventCard(event: event)),
      ],
    );
  }

  Widget _timeFilter() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _softPeach.withOpacity(0.65),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TimeFilterButton(
              label: 'Upcoming',
              selected: !_showPastEvents,
              onTap: () => setState(() => _showPastEvents = false),
            ),
          ),
          Expanded(
            child: _TimeFilterButton(
              label: 'Past events',
              selected: _showPastEvents,
              onTap: () => setState(() => _showPastEvents = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: InputDecoration(
        hintText: _selectedTab == 0 ? 'Search events' : 'Search events, places',
        hintStyle: const TextStyle(color: _mutedText),
        prefixIcon: const Icon(Icons.search, color: _mutedText),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _orange),
        ),
      ),
    );
  }

  Widget _categoryChips() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final selected = _selectedCategory == category;

          return ChoiceChip(
            label: Text(category),
            selected: selected,
            onSelected: (_) {
              setState(() => _selectedCategory = category);
            },
            selectedColor: _orange,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color: selected ? Colors.white : _darkText,
              fontWeight: FontWeight.w600,
            ),
            side: BorderSide(color: selected ? _orange : _border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfile() {
    return ProfileScreen(
      email: widget.email,
      onSignOut: _signOut,
    );
  }
}

class _TimeFilterButton extends StatelessWidget {
  const _TimeFilterButton({
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
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? _darkText : _mutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _mutedText,
          fontSize: 15,
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