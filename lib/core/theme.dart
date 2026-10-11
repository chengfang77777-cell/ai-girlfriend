import 'package:flutter/material.dart';

class AppTheme {
  // Primary colors
  static const Color primaryColor = Color(0xFF527564);
  static const Color primaryLight = Color(0xFFDCE6DB);
  static const Color primaryDark = Color(0xFF365746);
  static const Color primarySoft = Color(0xFFEAF0E8);

  // Accent colors
  static const Color accentPink = Color(0xFFC48792);
  static const Color accentRose = Color(0xFFB87986);
  static const Color accentPeach = Color(0xFFE6C8BE);

  // Warm palette aliases
  static const Color warmPink = Color(0xFF527564);
  static const Color warmPeach = Color(0xFFF0E3D3);

  // Background colors
  static const Color bgLight = Color(0xFFF6F5F0);
  static const Color bgDark = Color(0xFF293D35);
  static const Color bgCardLight = Color(0xFFFFFFFF);
  static const Color bgCardDark = Color(0xFF35473D);

  // Text colors
  static const Color textPrimary = Color(0xFF293D35);
  static const Color textSecondary = Color(0xFF69786F);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textHint = Color(0xFF7E8B81);

  // Chat bubble colors
  static const Color bubbleUser = Color(0xFFDCE6DB);
  static const Color bubbleAi = Color(0xFFFFFFFF);
  static const Color bubbleUserText = Color(0xFF293D35);
  static const Color bubbleAiText = Color(0xFF293D35);

  // Status / emotion indicator colors
  static const Color happy = Color(0xFF75927C);
  static const Color shy = Color(0xFFDCE6DB);
  static const Color angry = Color(0xFFBA5A58);
  static const Color sad = Color(0xFF8191AC);
  static const Color surprised = Color(0xFFC6A565);
  static const Color neutral = Color(0xFF96A58F);

  // Border and divider
  static const Color border = Color(0xFFDDE2D8);
  static const Color divider = Color(0xFFE8EBE2);

  // Shadow
  static const Color shadow = Color(0x0D293D35);

  // Gradient colors for backgrounds
  static const List<Color> gradientWarm = [
    Color(0xFFF6F5F0),
    Color(0xFFEAF0E8),
    Color(0xFFF0F2EA),
  ];

  static const List<Color> gradientLove = [
    Color(0xFF527564),
    Color(0xFFC48792),
    Color(0xFFDCE6DB),
  ];

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Microsoft YaHei UI',
      fontFamilyFallback: const [
        'Microsoft YaHei',
        'PingFang SC',
        'Noto Sans CJK SC',
        'sans-serif'
      ],
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        onPrimary: textOnPrimary,
        primaryContainer: primaryLight,
        onPrimaryContainer: primaryDark,
        secondary: accentPink,
        onSecondary: textOnPrimary,
        secondaryContainer: primarySoft,
        onSecondaryContainer: primaryDark,
        tertiary: accentPeach,
        onTertiary: textOnPrimary,
        error: angry,
        onError: textOnPrimary,
        surface: bgLight,
        onSurface: textPrimary,
        onSurfaceVariant: textSecondary,
        surfaceContainerHighest: primarySoft,
        surfaceContainerLow: bgCardLight,
        outline: border,
        outlineVariant: divider,
      ),
      scaffoldBackgroundColor: bgLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: bgLight,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 72,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardTheme(
        color: bgCardLight,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        elevation: 0,
        shadowColor: shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: bgCardLight,
        selectedItemColor: primaryColor,
        unselectedItemColor: textHint,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: textOnPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 2,
          shadowColor: shadow,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      iconTheme: const IconThemeData(color: primaryColor, size: 22),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        iconColor: primaryColor,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgCardLight,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: angry),
        ),
        hintStyle: const TextStyle(color: textHint, fontSize: 14),
        prefixIconColor: textHint,
        suffixIconColor: primaryColor,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: primarySoft,
        selectedColor: primaryColor,
        labelStyle: const TextStyle(color: primaryDark, fontSize: 13),
        secondaryLabelStyle:
            const TextStyle(color: textOnPrimary, fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        side: const BorderSide(color: border),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: bgCardLight,
        elevation: 8,
        shadowColor: shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: primaryDark,
        contentTextStyle: const TextStyle(color: textOnPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: textOnPrimary,
        elevation: 4,
        shape: CircleBorder(),
      ),
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,
        linearTrackColor: primarySoft,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryColor,
        inactiveTrackColor: primarySoft,
        thumbColor: primaryColor,
        overlayColor: primaryColor.withOpacity(0.2),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor;
          return textHint;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryLight;
          return divider;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(textOnPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      tabBarTheme: const TabBarTheme(
        labelColor: primaryColor,
        unselectedLabelColor: textSecondary,
        indicatorColor: primaryColor,
        labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle:
            TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          height: 1.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.5,
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.5,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.5,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          height: 1.5,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          height: 1.5,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textOnPrimary,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          height: 1.5,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
      ),
    );
  }
}
