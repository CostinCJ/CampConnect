// lib/features/map/domain/location.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum LocationCategory {
  nature(Icons.park, Color(0xFF4CAF50)),
  historical(Icons.account_balance, Color(0xFF795548));

  final IconData icon;
  final Color color;

  const LocationCategory(this.icon, this.color);

  static LocationCategory fromString(String value) {
    return LocationCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => LocationCategory.nature,
    );
  }
}

class Location {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String description;
  final LocationCategory category;
  final String? photoUrl;
  final List<String> facts;
  final String funFact;
  final String? quizQuestion;
  final String? quizAnswer;
  final String createdBy;
  final DateTime timestamp;

  const Location({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.description,
    required this.category,
    this.photoUrl,
    required this.facts,
    required this.funFact,
    this.quizQuestion,
    this.quizAnswer,
    required this.createdBy,
    required this.timestamp,
  });

  factory Location.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Location(
      id: doc.id,
      name: data['name'] as String? ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      description: data['description'] as String? ?? '',
      category: LocationCategory.fromString(data['category'] as String? ?? 'nature'),
      photoUrl: data['photoUrl'] as String?,
      facts: List<String>.from(data['facts'] as List? ?? []),
      funFact: data['funFact'] as String? ?? '',
      quizQuestion: data['quizQuestion'] as String?,
      quizAnswer: data['quizAnswer'] as String?,
      createdBy: data['createdBy'] as String? ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'category': category.name,
      'photoUrl': photoUrl,
      'facts': facts,
      'funFact': funFact,
      'quizQuestion': quizQuestion,
      'quizAnswer': quizAnswer,
      'createdBy': createdBy,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'category': category.name,
      'photoUrl': photoUrl,
      'facts': facts,
      'funFact': funFact,
      'quizQuestion': quizQuestion,
      'quizAnswer': quizAnswer,
      'createdBy': createdBy,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] as String? ?? '',
      category: LocationCategory.fromString(json['category'] as String? ?? 'nature'),
      photoUrl: json['photoUrl'] as String?,
      facts: List<String>.from(json['facts'] as List? ?? []),
      funFact: json['funFact'] as String? ?? '',
      quizQuestion: json['quizQuestion'] as String?,
      quizAnswer: json['quizAnswer'] as String?,
      createdBy: json['createdBy'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Location copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    String? description,
    LocationCategory? category,
    String? photoUrl,
    List<String>? facts,
    String? funFact,
    String? quizQuestion,
    String? quizAnswer,
    String? createdBy,
    DateTime? timestamp,
  }) {
    return Location(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      description: description ?? this.description,
      category: category ?? this.category,
      photoUrl: photoUrl ?? this.photoUrl,
      facts: facts ?? this.facts,
      funFact: funFact ?? this.funFact,
      quizQuestion: quizQuestion ?? this.quizQuestion,
      quizAnswer: quizAnswer ?? this.quizAnswer,
      createdBy: createdBy ?? this.createdBy,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
