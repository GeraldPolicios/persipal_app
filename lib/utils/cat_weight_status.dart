// lib/utils/cat_weight_status.dart
//
// A pure, stateless weight-status estimator for Persian cats.
//
// This file has NO dependency on any provider, storage, or widget — it is
// a plain function of its inputs (weightKg, birthDate, gender, asOf) and
// always returns a fully-defined result, including for the "can't
// classify" cases (too young, missing birthday). It reads nothing and
// writes nothing.
//
// IMPORTANT — evidence basis and limitations:
//   • The 10–20% "overweight" / >20% "obese" thresholds are a widely used
//     veterinary weight-management heuristic (VCA, Cornell Feline Health
//     Center, IAMS, Chewy, Pawlicy/APOP, Aztec Animal Clinic, FDA/APOP all
//     converge on this). It is NOT a diagnosis — every one of those
//     sources notes that body condition scoring (a hands-on vet exam) is
//     the actual clinical standard, not scale weight alone.
//   • The junior/adult Persian weight ranges below are synthesized from
//     several independent Persian breed-guide sources that converge
//     reasonably but are not peer-reviewed veterinary data.
//   • Cats under 12 months are deliberately NOT classified at all — kitten
//     growth is too fast and the available reference data too
//     inconsistent between sources to give a reliable range with any
//     confidence. See the accompanying research/approval discussion for
//     the full source table.
//
// This result is always an ESTIMATE, never a diagnosis. See
// [kCatWeightStatusDisclaimer].

/// Every possible outcome of [classifyCatWeight]. Always fully defined —
/// there is no "null"/unhandled case.
enum CatWeightStatus {
  /// [birthDate] was null — there isn't enough information to compute an
  /// age, so no attempt is made to guess one.
  unknownAgeNeeded,

  /// The cat is under 12 months old. Deliberately not classified — see
  /// the file-level doc comment for why.
  notClassified,

  underweight,
  normal,
  overweight,
  obese,
}

/// The full result of a weight-status estimate: the [status] itself, a
/// short human-readable [label], and a longer [detail] explaining the
/// reasoning (which reference range was used, or why no range applies).
class CatWeightStatusResult {
  final CatWeightStatus status;
  final String label;
  final String detail;

  const CatWeightStatusResult({
    required this.status,
    required this.label,
    required this.detail,
  });
}

/// Shown wherever a [CatWeightStatusResult] is displayed. Kept as a
/// single constant so every call site uses identical wording.
const String kCatWeightStatusDisclaimer =
    'Estimated weight status based on general Persian breed weight '
    'references — not a diagnosis. A vet\'s hands-on body condition '
    'assessment is the reliable way to confirm this.';

// ─── Approved reference ranges ──────────────────────────────────────────
//
// 12–<24 months (junior):
//   Male:   3.6 – 5.8 kg
//   Female: 3.0 – 4.8 kg
//
// ≥24 months (adult):
//   Male:   4.0 – 6.0 kg
//   Female: 3.0 – 4.8 kg
//
// Applied identically to both brackets:
//   weight < low                      -> Underweight
//   low <= weight <= high             -> Normal
//   high < weight <= high * 1.20      -> Overweight
//   weight > high * 1.20              -> Obese

class _WeightRange {
  final double low;
  final double high;
  final String label;

  const _WeightRange(this.low, this.high, this.label);
}

const _juniorMale = _WeightRange(3.6, 5.8, 'junior male Persian (12–24mo)');
const _juniorFemale = _WeightRange(3.0, 4.8, 'junior female Persian (12–24mo)');
const _adultMale = _WeightRange(4.0, 6.0, 'adult male Persian (24mo+)');
const _adultFemale = _WeightRange(3.0, 4.8, 'adult female Persian (24mo+)');

/// Estimates a Persian cat's weight status.
///
/// - [weightKg] should be the latest recorded `GrowthEntry.weightKg` — this
///   function does not read any storage itself, the caller supplies it.
/// - [birthDate] should come from `FullPetProfile.birthDate` (already
///   nullable there); pass null if unknown/unparseable.
/// - [gender] is treated as 'Male' (case-sensitive, matching the app's
///   existing toggle values) or anything else is treated as female —
///   consistent with the model's own default.
/// - [asOf] is the reference date age is computed against — normally
///   `DateTime.now()`, but callers may pass any date.
///
/// Always returns a fully-defined [CatWeightStatusResult]. Never throws,
/// never returns null.
CatWeightStatusResult classifyCatWeight({
  required double weightKg,
  required DateTime? birthDate,
  required String gender,
  required DateTime asOf,
}) {
  if (birthDate == null) {
    return const CatWeightStatusResult(
      status: CatWeightStatus.unknownAgeNeeded,
      label: 'Unknown — age needed',
      detail: 'Add this cat\'s birthday to see a weight-status estimate.',
    );
  }

  final ageMonths = _wholeMonthsBetween(birthDate, asOf);

  if (ageMonths < 12) {
    return const CatWeightStatusResult(
      status: CatWeightStatus.notClassified,
      label: 'Not classified — still growing',
      detail: 'Kittens grow too quickly for a reliable weight range. '
          'Track the trend and ask your vet if growth looks off.',
    );
  }

  final isJunior = ageMonths < 24;
  final isMale = gender == 'Male';

  final range = isJunior
      ? (isMale ? _juniorMale : _juniorFemale)
      : (isMale ? _adultMale : _adultFemale);

  return _classifyAgainstRange(weightKg, range);
}

CatWeightStatusResult _classifyAgainstRange(
  double weightKg,
  _WeightRange range,
) {
  final rangeText =
      '${range.low.toStringAsFixed(1)}–${range.high.toStringAsFixed(1)} kg '
      '(${range.label} reference range)';

  if (weightKg < range.low) {
    return CatWeightStatusResult(
      status: CatWeightStatus.underweight,
      label: 'Underweight (estimate)',
      detail: 'Below the $rangeText.',
    );
  }

  if (weightKg <= range.high) {
    return CatWeightStatusResult(
      status: CatWeightStatus.normal,
      label: 'Normal (estimate)',
      detail: 'Within the $rangeText.',
    );
  }

  final obeseThreshold = range.high * 1.20;

  if (weightKg <= obeseThreshold) {
    return CatWeightStatusResult(
      status: CatWeightStatus.overweight,
      label: 'Overweight (estimate)',
      detail: 'Above the $rangeText (10–20% over).',
    );
  }

  return CatWeightStatusResult(
    status: CatWeightStatus.obese,
    label: 'Obese (estimate)',
    detail: 'More than 20% above the $rangeText.',
  );
}

/// Whole months between [from] and [to], matching the same calendar-month
/// arithmetic used elsewhere in the app's age display (pet_age.dart's
/// formatAge) — kept as an independent copy here so this file has zero
/// import dependency on anything else, per "keep the classifier pure and
/// separate."
int _wholeMonthsBetween(DateTime from, DateTime to) {
  var totalMonths = (to.year - from.year) * 12 + (to.month - from.month);

  if (to.day < from.day) {
    totalMonths -= 1;
  }

  return totalMonths;
}
