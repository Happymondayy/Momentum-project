import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData get theme => ThemeData(
    primaryColor: const Color(0xFF9D8CFF),
    scaffoldBackgroundColor: const Color(0xFFF8F8FA),
    textTheme: GoogleFonts.notoSansTextTheme(),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: Colors.transparent,
    ),
  );
}
