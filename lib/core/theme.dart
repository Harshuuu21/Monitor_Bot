// theme.dart
// This file defines the entire visual look of the app.
// Colors, fonts, button styles — all in one place.
// Any screen that needs styling just imports this file.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────
// APP COLORS
// We define all colors here as constants.
// This way if you ever want to change a color,
// you change it in ONE place and it updates everywhere.
// ─────────────────────────────────────────
class AppColors {
  // Primary brand color — used for buttons, highlights, active states
  static const Color primary = Color(0xFF6C63FF);       // Purple
  static const Color primaryDark = Color(0xFF4B44CC);   // Darker purple for pressed states

  // Background colors
  static const Color background = Color(0xFF0F0F1A);    // Very dark navy — main background
  static const Color surface = Color(0xFF1A1A2E);       // Slightly lighter — card background
  static const Color surfaceLight = Color(0xFF252540);  // Even lighter — input fields

  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);   // White — main text
  static const Color textSecondary = Color(0xFFB0B0C8); // Muted — secondary text
  static const Color textHint = Color(0xFF6B6B8A);      // Very muted — placeholder text

  // Status colors
  static const Color success = Color(0xFF1DB954);       // Green — all good
  static const Color warning = Color(0xFFF59E0B);       // Amber — approaching limit
  static const Color error = Color(0xFFEF4444);         // Red — over limit / failed
  static const Color info = Color(0xFF3B82F6);          // Blue — info messages

  // Provider brand colors
  static const Color gemini = Color(0xFF4285F4);        // Google blue
  static const Color openai = Color(0xFF10A37F);        // OpenAI green
  static const Color claude = Color(0xFFD4A853);        // Anthropic gold

  // Card border
  static const Color border = Color(0xFF2A2A45);        // Subtle border color
}

// ─────────────────────────────────────────
// APP THEME
// This is the main theme object Flutter uses.
// We pass this to MaterialApp and it applies everywhere.
// ─────────────────────────────────────────
class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      // Tell Flutter we're using a dark theme
      brightness: Brightness.dark,

      // Main colors
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,

      // Color scheme — Flutter uses this internally for many widgets
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.primaryDark,
        surface: AppColors.surface,
        error: AppColors.error,
      ),

      // Font — we use 'Inter' from Google Fonts
      // It's clean, modern, and perfect for a tech app
      textTheme: GoogleFonts.interTextTheme(
        const TextTheme(
          // Large headings (e.g. "Welcome to Monitor Bot")
          headlineLarge: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
          // Medium headings (e.g. screen titles)
          headlineMedium: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          // Small headings (e.g. card titles)
          headlineSmall: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          // Body text (e.g. descriptions, paragraphs)
          bodyLarge: TextStyle(
            fontSize: 16,
            color: AppColors.textPrimary,
            height: 1.5,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
          bodySmall: TextStyle(
            fontSize: 12,
            color: AppColors.textHint,
          ),
          // Labels (e.g. button text, tags)
          labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),

      // AppBar (the top bar on each screen)
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,                          // No shadow
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),

      // Card styling (the white/dark boxes throughout the app)
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),

      // Primary button styling (the big purple buttons)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52), // Full width, 52px tall
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),

      // Outlined button styling (secondary buttons)
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Text input field styling
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),

      // Bottom navigation bar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textHint,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}

// ─────────────────────────────────────────
// REUSABLE STYLE HELPERS
// Quick shortcuts for common styles
// so you don't repeat yourself in every screen
// ─────────────────────────────────────────
class AppTextStyles {
  static TextStyle get screenTitle => GoogleFonts.inter(
    fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary,
  );

  static TextStyle get cardTitle => GoogleFonts.inter(
    fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
  );

  static TextStyle get cardSubtitle => GoogleFonts.inter(
    fontSize: 13, color: AppColors.textSecondary,
  );

  static TextStyle get badge => GoogleFonts.inter(
    fontSize: 11, fontWeight: FontWeight.w600,
  );

  static TextStyle get monospace => const TextStyle(
    fontFamily: 'monospace', fontSize: 13, color: AppColors.textSecondary,
  );
}

// ─────────────────────────────────────────
// SPACING CONSTANTS
// Standard spacing values used throughout the app
// Keeps everything visually consistent
// ─────────────────────────────────────────
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}