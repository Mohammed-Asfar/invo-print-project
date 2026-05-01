import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_colors.dart';

class ThemeState extends Equatable {
  const ThemeState({required this.themeMode, required this.primaryColor});

  factory ThemeState.initial() {
    return const ThemeState(
      themeMode: ThemeMode.dark,
      primaryColor: Color(0xFF7C4DFF),
    );
  }

  final ThemeMode themeMode;
  final Color primaryColor;

  bool get isDark => themeMode == ThemeMode.dark;

  @override
  List<Object?> get props => [themeMode, primaryColor];
}

class ThemeCubit extends Cubit<ThemeState> {
  ThemeCubit() : super(ThemeState.initial()) {
    AppColors.apply(dark: state.isDark, primaryColor: state.primaryColor);
  }

  void apply({required String themeMode, required String primaryColorHex}) {
    final nextState = ThemeState(
      themeMode: _themeModeFromString(themeMode),
      primaryColor: parseColor(primaryColorHex),
    );
    AppColors.apply(
      dark: nextState.isDark,
      primaryColor: nextState.primaryColor,
    );
    emit(nextState);
  }

  static Color parseColor(String hex) {
    final cleaned = hex.replaceAll('#', '').trim();
    final value = int.tryParse(
      cleaned.length == 6 ? 'FF$cleaned' : cleaned,
      radix: 16,
    );
    return Color(value ?? 0xFF7C4DFF);
  }

  static String colorToHex(Color color) {
    final value = color.toARGB32() & 0xFFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  static ThemeMode _themeModeFromString(String value) {
    return value.toLowerCase() == 'light' ? ThemeMode.light : ThemeMode.dark;
  }
}
