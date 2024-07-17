import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:univalle_app/config/themes/app_colors.dart';

final lightTheme = ThemeData.light().copyWith(
  scaffoldBackgroundColor: AppColors.lightGrey,
  primaryColor: AppColors.primaryRed,
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.primaryRed,
    titleTextStyle: TextStyle(
      color: AppColors.white,
      fontSize: 20,
    ),
  ),
);

final appThemeProvider = Provider<ThemeData>((ref) {
  return lightTheme;
});
