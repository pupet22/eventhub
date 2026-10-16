import 'package:cloud_firestore/cloud_firestore.dart';

class Event {
  const Event({
    required this.id,
    required this.name,
    required this.description,
    required this.startsAt,
    required this.location,
    required this.category,
    required this.imageUrl,
    this.endsAt,
  });

  final String id;
  final String name;
  final String description;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String location;
  final String category;
  final String imageUrl;

  factory Event.fromDocument(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data();

    if (data == null) {
      throw FormatException('Event ${document.id} has no data.');
    }

    final startsAtValue = data['startsAt'];
    if (startsAtValue is! Timestamp) {
      throw FormatException(
        'Event ${document.id} is missing a valid startsAt timestamp.',
      );
    }

    final startsAt = startsAtValue.toDate();
    final endsAtValue = data['endsAt'];
    DateTime? endsAt;

    if (endsAtValue != null) {
      if (endsAtValue is! Timestamp) {
        throw FormatException(
          'Event ${document.id} has an invalid endsAt timestamp.',
        );
      }

      endsAt = endsAtValue.toDate();

      if (!endsAt.isAfter(startsAt)) {
        throw FormatException(
          'Event ${document.id} must end after it starts.',
        );
      }
    }

    return Event(
      id: document.id,
      name: _requiredString(data, 'name', document.id),
      description: _requiredString(data, 'description', document.id),
      startsAt: startsAt,
      endsAt: endsAt,
      location: _requiredString(data, 'location', document.id),
      category: _requiredString(data, 'category', document.id),
      imageUrl: data['imageUrl'] as String? ?? '',
    );
  }

  static String _requiredString(
      Map<String, dynamic> data,
      String field,
      String documentId,
      ) {
    final value = data[field];

    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Event $documentId is missing a valid $field.');
    }

    return value;
  }
}