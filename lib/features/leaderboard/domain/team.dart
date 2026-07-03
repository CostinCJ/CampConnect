import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Team {
  final String id;
  final String name;
  final String colorHex; // e.g. "#E53935"
  final int points;

  const Team({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.points,
  });

  /// Parses [colorHex] (with or without leading '#') to a [Color].
  Color get color {
    final hex = colorHex.replaceFirst('#', '');
    final value = int.tryParse('FF$hex', radix: 16) ?? 0xFF9E9E9E; // grey fallback
    return Color(value);
  }

  Color get onColor =>
      color.computeLuminance() > 0.5 ? Colors.black : Colors.white;

  factory Team.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Team(
      id: doc.id,
      name: data['name'] as String? ?? doc.id,
      colorHex: data['colorHex'] as String? ?? '#9E9E9E',
      points: (data['points'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'colorHex': colorHex,
      'points': points,
    };
  }

  Team copyWith({String? id, String? name, String? colorHex, int? points}) {
    return Team(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      points: points ?? this.points,
    );
  }
}
