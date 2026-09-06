import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/storage.dart';

enum AppearanceMode { system, light, dark }

class AppearanceState {
  const AppearanceState({
    this.mode = AppearanceMode.system,
    this.accentIndex = 0,
  });

  final AppearanceMode mode;
  final int accentIndex;

  Brightness? get explicitBrightness {
    switch (mode) {
      case AppearanceMode.system:
        return null;
      case AppearanceMode.light:
        return Brightness.light;
      case AppearanceMode.dark:
        return Brightness.dark;
    }
  }

  Color get accent => accentColors[accentIndex.clamp(0, accentColors.length - 1)];

  AppearanceState copyWith({AppearanceMode? mode, int? accentIndex}) =>
      AppearanceState(
        mode: mode ?? this.mode,
        accentIndex: accentIndex ?? this.accentIndex,
      );
}

/// 8 个主题色,顺序与 Settings 页色块对应。
const List<Color> accentColors = [
  CupertinoColors.systemIndigo,
  CupertinoColors.systemBlue,
  CupertinoColors.systemTeal,
  CupertinoColors.systemMint,
  CupertinoColors.systemGreen,
  CupertinoColors.systemOrange,
  CupertinoColors.systemPink,
  CupertinoColors.systemPurple,
];

class AppearanceController extends StateNotifier<AppearanceState> {
  AppearanceController() : super(const AppearanceState()) {
    _load();
  }

  static const _modeKey = 'appearance_mode';
  static const _accentKey = 'appearance_accent';

  void _load() {
    final modeIdx = AppStorage.settings.get(_modeKey) as int?;
    final accentIdx = AppStorage.settings.get(_accentKey) as int?;
    state = AppearanceState(
      mode: AppearanceMode.values[
          (modeIdx ?? 0).clamp(0, AppearanceMode.values.length - 1)],
      accentIndex: (accentIdx ?? 0).clamp(0, accentColors.length - 1),
    );
  }

  Future<void> setMode(AppearanceMode mode) async {
    state = state.copyWith(mode: mode);
    await AppStorage.settings.put(_modeKey, mode.index);
  }

  Future<void> setAccent(int index) async {
    final clamped = index.clamp(0, accentColors.length - 1);
    state = state.copyWith(accentIndex: clamped);
    await AppStorage.settings.put(_accentKey, clamped);
  }
}

final appearanceProvider =
    StateNotifierProvider<AppearanceController, AppearanceState>(
        (ref) => AppearanceController());
