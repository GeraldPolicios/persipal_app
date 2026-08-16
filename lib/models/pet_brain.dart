import 'pet_state.dart';

enum PetMood {
  idle,
  happy,
  hungry,
  dirty,
  angry,
  neglected,
}

class PetBrain {
  final int hunger;
  final int happiness;
  final int cleanliness;

  final bool isBeingPetted;
  final bool isAngry;

  // NEW
  final bool isDirty;
  final bool isNeglected;

  PetBrain({
    required this.hunger,
    required this.happiness,
    required this.cleanliness,
    required this.isBeingPetted,
    required this.isAngry,
    required this.isDirty,
    required this.isNeglected,
  });

  PetMood get mood {
    // ============================
    // 0. NEGLECTED (highest)
    // ============================

    if (isNeglected) {
      return PetMood.neglected;
    }

    // ============================
    // 1. PLAY DIRTY
    // ============================

    if (isDirty) {
      return PetMood.dirty;
    }

    // ============================
    // 2. ANGRY
    // ============================

    if (isAngry) {
      return PetMood.angry;
    }

    // ============================
    // 3. HUNGRY
    // ============================

    if (hunger >= 70) {
      return PetMood.hungry;
    }

    // ============================
    // 4. DIRTY FROM LOW CLEANNESS
    // ============================

    if (cleanliness <= 30) {
      return PetMood.dirty;
    }

    // ============================
    // 5. HAPPY
    // ============================

    if (isBeingPetted) {
      return PetMood.happy;
    }

    return PetMood.idle;
  }

  PetState get animation {
    switch (mood) {
      case PetMood.neglected:
        return PetState.neglected;

      case PetMood.dirty:
        return PetState.dirty;

      case PetMood.angry:
        return PetState.angry;

      case PetMood.hungry:
        return PetState.sad;

      case PetMood.happy:
        return PetState.happy;

      case PetMood.idle:
        return PetState.idle;
    }
  }

  String? get thought {
    switch (mood) {
      case PetMood.neglected:
        return '💔';

      case PetMood.hungry:
        return '🍗';

      case PetMood.dirty:
        return '🧼';

      default:
        return null;
    }
  }
}
