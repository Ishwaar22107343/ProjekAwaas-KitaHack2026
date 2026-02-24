import 'package:flutter/material.dart';

const bgDeep    = Color(0xFF080C14);
const bgCard    = Color(0xFF0F1624);
const bgSurface = Color(0xFF161E30);
const accent    = Color(0xFF00E5FF);
const accentDim = Color(0xFF0097A7);
const danger    = Color(0xFFFF3B30);
const safe      = Color(0xFF00E676);
const warn      = Color(0xFFFFD600);
const textPrimary   = Color(0xFFEEF2FF);
const textSecondary = Color(0xFF7B8BB2);

ThemeData appTheme() => ThemeData.dark().copyWith(
  scaffoldBackgroundColor: bgDeep,
  colorScheme: const ColorScheme.dark(
    primary: accent,
    secondary: accentDim,
    surface: bgCard,
  ),
);