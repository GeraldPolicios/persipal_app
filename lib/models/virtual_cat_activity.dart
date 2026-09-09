// lib/models/virtual_cat_activity.dart
//
// Coarse "what is the cat currently doing" behavior state — layered ON TOP
// OF, not replacing, the existing mood-driven PetState (happy/sad/dirty/
// angry/neglected/idle in pet_state.dart). PetState decides WHICH cat
// picture/animation set applies; VirtualCatActivity is only meaningful
// while PetState is `idle`, and describes the idle behavior itself.
//
// Phase 9.1 only drives [idle] and [idleVariation]. The remaining values
// are declared now — not implemented — purely so a later phase (room
// walking, tap interactions, sleep, reactions) can extend this enum and the
// widget that reads it without restructuring either.
enum VirtualCatActivity {
  idle,
  idleVariation,
  walk, // Phase 9.2+
  interact, // future
  rest, // future
  react, // future
}
