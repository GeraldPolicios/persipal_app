import 'package:flutter/material.dart';

class DirtyState extends ChangeNotifier {
  DirtyState._();

  static final DirtyState instance = DirtyState._();

  bool _isDirty = false;

  bool get isDirty => _isDirty;

  void setDirty(bool value) {
    if (_isDirty == value) return;

    _isDirty = value;
    notifyListeners();
  }
}
