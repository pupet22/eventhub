import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/event.dart';

class SavedEventRepository {
  SavedEventRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<bool> watchIsSaved(String eventId) {
    final user = _auth.currentUser;
    if (user == null) return Stream<bool>.value(false);

    return _savedEventRef(user.uid, eventId)
        .snapshots()
        .map((document) => document.exists);
  }

  Stream<List<Event>> watchSavedEvents() {
    final user = _auth.currentUser;
    if (user == null) return Stream<List<Event>>.value(<Event>[]);

    final savedEvents = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('savedEvents');

    return savedEvents.snapshots().asyncMap((snapshot) async {
      final eventDocuments = await Future.wait(
        snapshot.docs.map(
              (savedEvent) =>
              _firestore.collection('events').doc(savedEvent.id).get(),
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

  Future<void> saveEvent(String eventId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Please log in to save events.');
    }

    final savedEventRef = _savedEventRef(user.uid, eventId);

    await _firestore.runTransaction((transaction) async {
      final savedEvent = await transaction.get(savedEventRef);

      // Avoid updating an existing document, since the rules only allow create.
      if (!savedEvent.exists) {
        transaction.set(savedEventRef, {
          'userId': user.uid,
          'eventId': eventId,
          'savedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> removeSavedEvent(String eventId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Please log in to manage saved events.');
    }

    final savedEventRef = _savedEventRef(user.uid, eventId);

    await _firestore.runTransaction((transaction) async {
      final savedEvent = await transaction.get(savedEventRef);
      if (savedEvent.exists) {
        transaction.delete(savedEventRef);
      }
    });
  }

  DocumentReference<Map<String, dynamic>> _savedEventRef(
      String userId,
      String eventId,
      ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('savedEvents')
        .doc(eventId);
  }
}