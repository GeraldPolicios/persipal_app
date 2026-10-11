import 'cat_animation.dart';
import '../models/virtual_pet_state.dart';
import '../models/virtual_pet_status.dart';

enum CatState {
  normal,
  sleepy,
  resting,
  sleeping,
  sad,
  neglected,
}

class CatStateController {
  final CatAnimation catAnimation;

  CatState _currentState = CatState.normal;

  CatStateController({
    required this.catAnimation,
  });

  CatState get currentState => _currentState;

  bool get isNormal => _currentState == CatState.normal;

  bool get isSleepy => _currentState == CatState.sleepy;

  bool get isResting => _currentState == CatState.resting;

  bool get isSleeping => _currentState == CatState.sleeping;

  bool get isSad => _currentState == CatState.sad;

  bool get isNeglected => _currentState == CatState.neglected;

  // ==========================================================
  // UPDATE STATE FROM CAT STATS
  // ==========================================================
  void updateFromStats({
    required int hunger,
    required int happiness,
    required int cleanliness,
    required int energy,
    required bool wantsToPlay,
    int furStage = 0,
  }) {
    // Use the same priority resolver as VirtualPetProvider and GameScreen.
    // Sleeping/Resting remain action states and are handled separately.
    final status = resolveVirtualPetStatus(
      VirtualPetState.initial().copyWith(
        hunger: hunger,
        happiness: happiness,
        cleanliness: cleanliness,
        energy: energy,
        furStage: furStage,
        wantsToPlay: wantsToPlay,
      ),
    );

    // An active Rest/Sleep animation must not be replaced by a normal
    // stat refresh. Wake/sleep transitions are handled by onCatTap().
    if (catAnimation.isResting) {
      _currentState = CatState.resting;
      return;
    }

    if (catAnimation.isSleeping) {
      _currentState = CatState.sleeping;
      return;
    }

    switch (status) {
      case VirtualPetStatus.neglected:
        _setState(CatState.neglected, force: true, furStage: furStage);
        return;

      case VirtualPetStatus.criticalHunger:
      case VirtualPetStatus.sad:
      case VirtualPetStatus.hungry:
        _setState(CatState.sad, force: true, furStage: furStage);
        return;

      case VirtualPetStatus.sleepy:
        _setState(CatState.sleepy, force: true);
        return;

      case VirtualPetStatus.dirty:
      case VirtualPetStatus.wantsToPlay:
      case VirtualPetStatus.normal:
        // Dirt and Wants-to-Play are visual/thought states. They do not
        // require a separate Flame animation, so keep the normal idle cat.
        if (catAnimation.isBusy) {
          return;
        }
        _setState(CatState.normal, furStage: furStage);
        return;
    }
  }

  // ==========================================================
  // CAT TAP
  // ==========================================================
  Future<void> onCatTap({required int energy}) async {
    // ========================================================
    // NEGLECTED
    // ========================================================
    if (isNeglected) {
      return;
    }

    // ========================================================
    // SLEEPY → REST → SLEEPING
    // ========================================================
    if (catAnimation.isSleepy) {
      _currentState = CatState.resting;

      await catAnimation.restAndSleep();

      if (catAnimation.isSleeping) {
        _currentState = CatState.sleeping;
      }

      return;
    }

    // ========================================================
    // RESTING
    // ========================================================
    if (catAnimation.isResting) {
      _currentState = CatState.resting;
      return;
    }

    // ========================================================
    // SLEEPING
    //
    // Energy <= 20: tapping does NOT wake the cat.
    // GameScreen handles the 😴 / ZZZ thought bubble.
    //
    // Energy > 20: wake is now allowed.
    // ========================================================
    if (catAnimation.isSleeping) {
      _currentState = CatState.sleeping;

      if (energy <= 20) {
        return;
      }

      await catAnimation.wakeUp();

      if (!catAnimation.isSleeping && !catAnimation.isWaking) {
        _currentState = CatState.normal;

        catAnimation.showIdle();
      }

      return;
    }

    // ========================================================
    // WAKING
    // ========================================================
    if (catAnimation.isWaking) {
      return;
    }
  }

  // ==========================================================
  // REFRESH
  // ==========================================================
  void refresh({
    required int hunger,
    required int happiness,
    required int cleanliness,
    required int energy,
    required bool wantsToPlay,
    int furStage = 0,
  }) {
    updateFromStats(
      hunger: hunger,
      happiness: happiness,
      cleanliness: cleanliness,
      energy: energy,
      wantsToPlay: wantsToPlay,
      furStage: furStage,
    );
  }

  // ==========================================================
  // SET STATE
  // ==========================================================
  void _setState(
    CatState state, {
    bool force = false,
    int furStage = 0,
  }) {
    if (!force && _currentState == state) {
      return;
    }

    _currentState = state;

    switch (state) {
      case CatState.normal:
        catAnimation.setFurStage(furStage);
        catAnimation.showIdle();
        break;

      case CatState.sleepy:
        catAnimation.enterSleepy(
          force: force,
        );
        break;

      case CatState.resting:
        break;

      case CatState.sleeping:
        break;

      case CatState.sad:
        // Long fur takes visual priority until the player trims it back to
        // Fur0. Keep the real care state in _currentState so it is evaluated
        // again after grooming, but do not show its animation yet.
        if (furStage > 0) {
          catAnimation.showFurIdle(furStage, force: true);
        } else {
          catAnimation.showSad(force: true);
        }
        break;

      case CatState.neglected:
        // Fur1/Fur2 stay visible while neglected. The room's heavy dirt/fly
        // overlay communicates neglect until trimming is complete.
        catAnimation.setFurStage(furStage);
        if (furStage == 0) {
          catAnimation.showSad(force: true);
        } else {
          catAnimation.showFurIdle(furStage, force: true);
        }
        break;
    }
  }
}
