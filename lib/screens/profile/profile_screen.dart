import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/event.dart';
import '../../repositories/registration_repository.dart';
import '../../repositories/saved_event_repository.dart';
import 'notifications_screen.dart';

const Color _cream = Color(0xFFFFF9F5);
const Color _darkText = Color(0xFF2D2521);
const Color _mutedText = Color(0xFF94847A);
const Color _softPeach = Color(0xFFFFEADF);
const Color _orange = Color(0xFFFF762E);
const Color _border = Color(0xFFFFDFD3);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.email,
    required this.onSignOut,
  });

  final String email;
  final Future<void> Function() onSignOut;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final RegistrationRepository _registrationRepository =
  RegistrationRepository();
  final SavedEventRepository _savedEventRepository = SavedEventRepository();

  late Stream<List<Event>> _registeredEvents;
  late Stream<List<Event>> _savedEvents;
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    _registeredEvents = _registrationRepository.watchMyEvents();
    _savedEvents = _savedEventRepository.watchSavedEvents();
  }

  String get _displayName {
    final name = _user?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;

    final emailName = (_user?.email ?? widget.email).split('@').first.trim();
    return emailName.isEmpty ? 'EventHub user' : emailName;
  }

  Future<void> _editProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _EditProfileDialog(
        initialName: user.displayName ?? '',
      ),
    );

    if (!mounted || newName == null || newName.isEmpty) return;

    try {
      await user.updateDisplayName(newName);
      await user.reload();

      if (!mounted) return;
      setState(() => _user = FirebaseAuth.instance.currentUser);
      _showMessage('Profile name updated.');
    } catch (_) {
      if (!mounted) return;
      _showMessage('Could not update your profile. Please try again.');
    }
  }

  Future<void> _confirmSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Log out?',
          style: TextStyle(
            color: _darkText,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'Are you sure you want to log out of EventHub?',
          style: TextStyle(color: _mutedText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: _mutedText),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFCC4438),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (shouldSignOut != true || !mounted) return;
    await widget.onSignOut();
  }

  void _showNotificationsInfo() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const NotificationsScreen(),
      ),
    );
  }

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Help and support'),
        content: const Text(
          'Browse events from Home or Explore. Open an event to see its '
              'details and register. Your registrations appear under Tickets, '
              'and events you save with the heart button appear under Saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: _darkText,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: StreamBuilder<List<Event>>(
        stream: _registeredEvents,
        builder: (context, registrationsSnapshot) {
          return StreamBuilder<List<Event>>(
            stream: _savedEvents,
            builder: (context, savedSnapshot) {
              final now = DateTime.now();
              final registrations =
                  registrationsSnapshot.data ?? const <Event>[];
              final saved = savedSnapshot.data ?? const <Event>[];

              final upcomingCount = registrations.where((event) {
                return (event.endsAt ?? event.startsAt).isAfter(now);
              }).length;
              final pastCount = registrations.length - upcomingCount;

              return ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                children: [
                  Center(
                    child: Container(
                      width: 116,
                      height: 116,
                      decoration: BoxDecoration(
                        color: _orange,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 6),
                        boxShadow: [
                          BoxShadow(
                            color: _orange.withOpacity(0.18),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _displayName.isEmpty
                            ? 'U'
                            : _displayName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      _displayName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _darkText,
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      _user?.email ?? widget.email,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _mutedText,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _ProfileStat(
                          value: registrationsSnapshot.hasError
                              ? '–'
                              : '$upcomingCount',
                          label: 'Upcoming',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ProfileStat(
                          value: registrationsSnapshot.hasError
                              ? '–'
                              : '$pastCount',
                          label: 'Past',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ProfileStat(
                          value: savedSnapshot.hasError ? '–' : '${saved.length}',
                          label: 'Saved',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _ProfileOption(
                    icon: Icons.edit_outlined,
                    title: 'Edit profile',
                    onTap: _editProfile,
                  ),
                  const SizedBox(height: 10),
                  _ProfileOption(
                    icon: Icons.notifications_none,
                    title: 'Notifications',
                    onTap: _showNotificationsInfo,
                  ),
                  const SizedBox(height: 10),
                  _ProfileOption(
                    icon: Icons.help_outline,
                    title: 'Help and support',
                    onTap: _showHelp,
                  ),
                  const SizedBox(height: 10),
                  _ProfileOption(
                    icon: Icons.logout,
                    title: 'Log out',
                    isDestructive: true,
                    showChevron: false,
                    onTap: () => _confirmSignOut(),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: _orange,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _mutedText,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileOption extends StatelessWidget {
  const _ProfileOption({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? const Color(0xFFCC4438) : _darkText;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDestructive
                      ? const Color(0xFFFFE8E5)
                      : _softPeach,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: isDestructive ? color : _orange,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (showChevron)
                const Icon(
                  Icons.chevron_right,
                  color: _mutedText,
                  size: 26,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({required this.initialName});

  final String initialName;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late String _name;

  @override
  void initState() {
    super.initState();
    _name = widget.initialName;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit profile'),
      content: TextFormField(
        initialValue: widget.initialName,
        autofocus: true,
        maxLength: 50,
        decoration: const InputDecoration(
          labelText: 'Full name',
          hintText: 'Enter your name',
        ),
        onChanged: (value) => _name = value,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(_name.trim());
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}