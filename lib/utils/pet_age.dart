// lib/utils/pet_age.dart
//
// Pure, stateless helpers for parsing a pet's stored birthday string and
// computing a human-readable age from it. No state, no storage, no
// dependency on any provider — safe to reuse anywhere (Growth Tracker,
// dashboard, future classifier) without new plumbing.
//
// IMPORTANT: this does NOT change how birthday is stored. FullPetProfile
// keeps storing it as the existing 'MMMM d, yyyy' formatted string (the
// same format pet_details_screen.dart's date picker already writes) —
// parsing happens only at read time, so existing pets with a blank or
// unusual birthday value are handled gracefully (null, never a crash).

import 'package:intl/intl.dart';

final DateFormat _birthdayFormat = DateFormat('MMMM d, yyyy');

/// Safely parses a pet's stored birthday string into a [DateTime].
/// Returns null for an empty string or anything that doesn't match the
/// expected format — never throws.
DateTime? parsePetBirthday(String raw) {
  final trimmed = raw.trim();

  if (trimmed.isEmpty) {
    return null;
  }

  try {
    return _birthdayFormat.parseStrict(trimmed);
  } catch (_) {
    return null;
  }
}

/// Formats [birthDate] as a human-readable age relative to [asOf].
///
/// This is deliberately generic over [asOf] so the same function can be
/// used for "current age" (asOf: DateTime.now()) and, later, "age at a
/// specific growth measurement" (asOf: entry.recordedAt) — age is always
/// computed on demand, never stored.
String formatAge(DateTime birthDate, DateTime asOf) {
  if (asOf.isBefore(birthDate)) {
    return 'Not yet born';
  }

  final totalDays = asOf.difference(birthDate).inDays;

  if (totalDays < 30) {
    return totalDays <= 1 ? '1 day old' : '$totalDays days old';
  }

  var totalMonths =
      (asOf.year - birthDate.year) * 12 + (asOf.month - birthDate.month);

  if (asOf.day < birthDate.day) {
    totalMonths -= 1;
  }

  if (totalMonths < 12) {
    return totalMonths <= 1 ? '1 month old' : '$totalMonths months old';
  }

  final years = totalMonths ~/ 12;
  final months = totalMonths % 12;

  if (months == 0) {
    return years == 1 ? '1 year old' : '$years years old';
  }

  final yearLabel = years == 1 ? '1 year' : '$years years';
  final monthLabel = months == 1 ? '1 month' : '$months months';

  return '$yearLabel, $monthLabel old';
}
