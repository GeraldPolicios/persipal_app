// lib/widgets/pet_photo_avatar.dart
//
// Shared circular pet photo/avatar + the gallery-picking helpers behind
// "Add Photo" / "Change Photo" everywhere they appear (pet creation dialog,
// the pet grid, the profile hero). Keeping this in one place means every
// screen shows a pet's photo identically and falls back to the same
// color-tinted placeholder when no photo exists yet.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Circular pet photo, or a color-tinted placeholder with a cat emoji when
/// [photoPath] is null or the file no longer exists on disk.
class PetPhotoAvatar extends StatelessWidget {
  final String? photoPath;
  final Color color;
  final double size;
  final VoidCallback? onTap;
  final bool showEditBadge;

  const PetPhotoAvatar({
    super.key,
    required this.photoPath,
    required this.color,
    this.size = 84,
    this.onTap,
    this.showEditBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final path = photoPath;
    final hasPhoto = path != null && File(path).existsSync();

    Widget circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hasPhoto ? Colors.white : color.withValues(alpha: 0.9),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        image: hasPhoto
            ? DecorationImage(image: FileImage(File(path)), fit: BoxFit.cover)
            : null,
      ),
      child: hasPhoto
          ? null
          : Center(child: Text('🐱', style: TextStyle(fontSize: size * 0.45))),
    );

    if (showEditBadge) {
      circle = Stack(
        clipBehavior: Clip.none,
        children: [
          circle,
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF8C69),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
            ),
          ),
        ],
      );
    }

    final semanticLabel = hasPhoto
        ? 'Pet photo. Double tap to change.'
        : 'No pet photo yet. Double tap to add one.';

    if (onTap == null) return circle;

    return Semantics(
      button: true,
      label: onTap != null ? semanticLabel : null,
      child: GestureDetector(onTap: onTap, child: circle),
    );
  }
}

/// Opens the device gallery and returns a lightly-downsized/compressed
/// [File], or null if the user cancelled. Shows a SnackBar and returns null
/// on any picker failure (denied permission, plugin error) instead of
/// throwing — callers never need their own try/catch.
Future<File?> pickPetPhotoFromGallery(BuildContext context) async {
  try {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return null; // user cancelled — not an error
    final file = File(picked.path);
    return await file.exists() ? file : null;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Couldn't access photos. Check the app's photo permission and try again."),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return null;
  }
}
