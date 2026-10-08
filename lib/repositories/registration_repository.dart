import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/event.dart';

class RegistrationRepository {
  RegistrationRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<bool> watchRegistration(String eventId) {
    final user = _auth.currentUser;
    if (user == null) return Stream<bool>.value(false);

    return _registrationRef(
      user.uid,
      eventId,
    ).snapshots().map((document) => document.exists);
  }

  Stream<List<Event>> watchMyEvents() {
    final user = _auth.currentUser;
    if (user == null) return Stream<List<Event>>.value(<Event>[]);

    final registrations = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('registrations');

    return registrations.snapshots().asyncMap((snapshot) async {
      final eventDocuments = await Future.wait(
        snapshot.docs.map(
          (registration) =>
              _firestore.collection('events').doc(registration.id).get(),
        ),
      );

      final events = eventDocuments
          .where((document) => document.exists)
          .map(Event.fromDocument)
          .toList();

      events.sort((a, b) => a.startsAt.compareTo(b.startsAt));
      return events;
    });
  }

  Future<void> registerForEvent(String eventId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Please log in to register.');
    }

    final registrationRef = _registrationRef(user.uid, eventId);
    final eventRef = _firestore.collection('events').doc(eventId);

    await _firestore.runTransaction((transaction) async {
      final registration = await transaction.get(registrationRef);
      final event = await transaction.get(eventRef);

      if (registration.exists) {
        throw StateError('You are already registered for this event.');
      }

      if (!event.exists) {
        throw StateError('This event is no longer available.');
      }

      final startsAt = event.data()?['startsAt'];
      if (startsAt is! Timestamp) {
        throw StateError('This event has an invalid date.');
      }

      if (!startsAt.toDate().isAfter(DateTime.now())) {
        throw StateError(
          'Registration is closed because this event has started.',
        );
      }

      transaction.set(registrationRef, {
        'userId': user.uid,
        'eventId': eventId,
        'registeredAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> cancelRegistration(String eventId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Please log in to cancel your registration.');
    }

    await _registrationRef(user.uid, eventId).delete();
  }

  DocumentReference<Map<String, dynamic>> _registrationRef(
    String userId,
    String eventId,
  ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('registrations')
        .doc(eventId);
  }
}
