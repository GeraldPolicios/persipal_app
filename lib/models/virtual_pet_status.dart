import 'virtual_pet_state.dart';

/// The single priority resolver used by every virtual-pet room.
///
/// Actual Sleeping/Resting is handled separately because it is an action
/// state, not something that should be forced by low Energy.
enum VirtualPetStatus {
  neglected,
  criticalHunger,
  sleepy,
  sad,
  hungry,
  dirty,
  wantsToPlay,
  normal,
}

VirtualPetStatus resolveVirtualPetStatus(VirtualPetState pet) {
  if (pet.hunger >= 90 && pet.happiness <= 20 && pet.cleanliness <= 20) {
    return VirtualPetStatus.neglected;
  }

  // Critical hunger wins over Sleepy. This lets the player feed a cat that
  // is both very hungry and low on Energy instead of forcing it to sleep.
  if (pet.hunger >= 90) {
    return VirtualPetStatus.criticalHunger;
  }

  // Hunger should take priority over Sleepy so players can always respond
  // to a hungry cat before putting it to rest.
  if (pet.hunger >= 70) {
    return VirtualPetStatus.hungry;
  }

  // A dirty cat must be cleaned before low Energy takes over.
  if (pet.cleanliness <= 30) {
    return VirtualPetStatus.dirty;
  }

  if (pet.energy <= 20) {
    return VirtualPetStatus.sleepy;
  }

  if (pet.happiness <= 20) {
    return VirtualPetStatus.sad;
  }

  if (pet.wantsToPlay) {
    return VirtualPetStatus.wantsToPlay;
  }

  return VirtualPetStatus.normal;
}

extension VirtualPetStatusLabel on VirtualPetStatus {
  String get label {
    switch (this) {
      case VirtualPetStatus.neglected:
        return 'Neglected';
      case VirtualPetStatus.criticalHunger:
        return 'Very Hungry';
      case VirtualPetStatus.sleepy:
        return 'Sleepy';
      case VirtualPetStatus.sad:
        return 'Sad';
      case VirtualPetStatus.hungry:
        return 'Hungry';
      case VirtualPetStatus.dirty:
        return 'Dirty';
      case VirtualPetStatus.wantsToPlay:
        return 'Wants to Play';
      case VirtualPetStatus.normal:
        return 'Normal';
    }
  }
}
