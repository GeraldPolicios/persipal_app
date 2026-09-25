// lib/game/interaction_state.dart
//
// Small, self-contained enums for the reusable Virtual Pet Flame
// interaction engine (VirtualPetInteractionGame). Deliberately independent
// of PetState/PetMood (game_screen.dart's own mood axis, used by the main
// GameScreen's CatAnimation) — these describe WHAT THE CAT IS DOING (an
// interaction activity), not how it feels. Kept minimal: only what Phase 1
// (Groom) actually uses is wired up in the engine itself.

/// What the interaction engine is currently doing. Used internally to guard
/// against overlapping commands (e.g. a second groom() call arriving while
/// a reaction is still playing) — the same guard style already used by
/// CatAnimation's `_isWaking`/`_reacting` flags.
enum CatActivity {
  idle,
  approaching,
  performingAction,
  reacting,
  returningToIdle,
}

/// Grooming tools. Soap/Shower/Brush all drive the same happy reaction via
/// groom(); Trim is intentionally NOT routed through groom() — it's driven
/// continuously by the existing Flutter pan gesture via
/// setFurStage()/finishTrim() instead of a single discrete command.
enum GroomTool { soap, shower, brush, trim }

/// Which reusable reaction animation to play. Only .happy is used in
/// Phase 1 (Groom); .sad is declared now so a later phase (Feed's Milk
/// reaction) can reuse this same enum instead of inventing a parallel one.
enum ReactionKind { happy, sad }
