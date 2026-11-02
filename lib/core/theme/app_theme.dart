import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_tokens.dart';

/// The single app theme. Wire it with `MaterialApp(theme: AppTheme.light)`.
class AppTheme {
  AppTheme._();

  /// Status bar over a blue header (the home screens): the same solid blue as
  /// the header, with light icons. A solid colour is used rather than
  /// transparent because on devices where the app is not drawn behind the
  /// status bar (Android 11 here) the system paints that strip itself, and a
  /// transparent or unset colour shows Android's own darker default. Wrap such
  /// a screen in
  /// `AnnotatedRegion<SystemUiOverlayStyle>(value: AppTheme.statusBarOnPrimary)`.
  static const SystemUiOverlayStyle statusBarOnPrimary = SystemUiOverlayStyle(
    statusBarColor: AppColors.primary,
    statusBarIconBrightness: Brightness.light, // Android
    statusBarBrightness: Brightness.dark, // iOS
    systemStatusBarContrastEnforced: false,
  );

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(seedColor: AppColors.primary)
        .copyWith(
          primary: AppColors.primary,
          secondary: AppColors.accentStrong,
          surface: AppColors.surfaceCard,
          onSurface: AppColors.ink,
          error: AppColors.cancelledFg,
        );

    final textTheme = TextTheme(
      displayLarge: AppText.display,
      displayMedium: AppText.display,
      displaySmall: AppText.display,
      headlineLarge: AppText.title,
      headlineMedium: AppText.title,
      headlineSmall: AppText.title,
      titleLarge: AppText.title,
      titleMedium: AppText.heading,
      titleSmall: AppText.bodyStrong,
      bodyLarge: AppText.body,
      bodyMedium: AppText.body,
      bodySmall: AppText.caption,
      labelLarge: AppText.bodyStrong,
      labelMedium: AppText.caption,
      labelSmall: AppText.caption,
    ).apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);

    OutlineInputBorder inputBorder(Color color, double width) =>
        OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.surfaceBg,
      textTheme: textTheme,
      primaryTextTheme: textTheme,

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceCard,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 64,
        titleTextStyle: AppText.heading.copyWith(color: AppColors.ink),
        // Light bar, so the status-bar icons are dark and the status bar is
        // white like the bar. Set explicitly: left unset, Android keeps its
        // own default and can draw a darker strip.
        systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: AppColors.surfaceCard,
          systemStatusBarContrastEnforced: false,
        ),
        shape: const Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),

      // The one main action per screen.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentStrong,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.inkFaint,
          elevation: 0,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
          textStyle: AppText.heading,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 2),
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
          textStyle: AppText.bodyStrong,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(44, 44),
          tapTargetSize: MaterialTapTargetSize.padded,
          textStyle: AppText.bodyStrong,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3,
          vertical: AppSpacing.s4,
        ),
        border: inputBorder(AppColors.borderStrong, 1.5),
        enabledBorder: inputBorder(AppColors.borderStrong, 1.5),
        disabledBorder: inputBorder(AppColors.border, 1.5),
        focusedBorder: inputBorder(AppColors.primary, 2),
        errorBorder: inputBorder(AppColors.cancelledFg, 1.5),
        focusedErrorBorder: inputBorder(AppColors.cancelledFg, 2),
        hintStyle: AppText.body.copyWith(color: AppColors.inkFaint),
        errorStyle: AppText.caption.copyWith(color: AppColors.cancelledFg),
        prefixIconColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? AppColors.primary
              : AppColors.inkFaint,
        ),
        suffixIconColor: AppColors.inkFaint,
      ),

      // ChoiceChip filters.
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        // 20px label line + 8px top and bottom = 36px high.
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3,
          vertical: AppSpacing.s2,
        ),
        backgroundColor: AppColors.surfaceCard,
        selectedColor: AppColors.primary,
        disabledColor: AppColors.border,
        showCheckmark: false,
        side: WidgetStateBorderSide.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.borderStrong,
            width: 1.5,
          ),
        ),
        labelStyle: WidgetStateTextStyle.resolveWith(
          (states) => AppText.bodyStrong.copyWith(
            color: states.contains(WidgetState.selected)
                ? AppColors.onPrimary
                : AppColors.inkMuted,
          ),
        ),
        secondaryLabelStyle: AppText.bodyStrong.copyWith(
          color: AppColors.onPrimary,
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: AppColors.primaryTint,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppText.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                )
              : AppText.caption.copyWith(color: AppColors.inkFaint),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.inkFaint,
          ),
        ),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brLg),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brLg),
        titleTextStyle: AppText.title.copyWith(color: AppColors.ink),
        contentTextStyle: AppText.body.copyWith(color: AppColors.inkMuted),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surfaceCard,
        modalBackgroundColor: AppColors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.topXl),
        showDragHandle: true,
        dragHandleColor: AppColors.borderStrong,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
        contentTextStyle: AppText.bodyStrong.copyWith(
          color: AppColors.onPrimary,
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.primaryTint,
        circularTrackColor: Colors.transparent,
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
