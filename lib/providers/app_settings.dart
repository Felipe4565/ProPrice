import 'package:flutter/material.dart';

class AppSettings extends ChangeNotifier {
  bool _hideBalance = false;
  bool _showDetailedCharts = true;

  bool get hideBalance => _hideBalance;
  bool get showDetailedCharts => _showDetailedCharts;

  void toggleHideBalance(bool value) {
    _hideBalance = value;
    notifyListeners();
  }

  void toggleShowDetailedCharts(bool value) {
    _showDetailedCharts = value;
    notifyListeners();
  }
}