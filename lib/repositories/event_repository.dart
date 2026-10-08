import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/event.dart';

class EventRepository {
  EventRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<Event>> watchEvents() {
    return _firestore
        .collection('events')
        .orderBy('startsAt')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(Event.fromDocument).toList(growable: false),
        );
  }

  Future<Event?> getEvent(String eventId) async {
    final document = await _firestore.collection('events').doc(eventId).get();

    if (!document.exists) return null;
    return Event.fromDocument(document);
  }
}
