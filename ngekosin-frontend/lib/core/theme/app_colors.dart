import 'package:flutter/material.dart';

/// Palet Ngekos.in: biru tinta (kepercayaan) + kuning kunyit (hangat, "kunci kamar").
/// Sengaja berbeda dari Mamikos (hijau) dan MariKos (ungu).
class AppColors {
  AppColors._();

  static const ink = Color(0xFF1B2559);        // primer
  static const inkDeep = Color(0xFF111A40);
  static const marigold = Color(0xFFFFB21E);   // aksen / CTA
  static const marigoldSoft = Color(0xFFFFF1CF);
  static const surface = Color(0xFFF5F6FB);
  static const card = Colors.white;
  static const textPrimary = Color(0xFF161B33);
  static const textMuted = Color(0xFF6B7194);
  static const line = Color(0xFFE3E6F2);
  static const success = Color(0xFF0F9D75);
  static const danger = Color(0xFFD9455F);

  // warna label jenis kos
  static const putra = Color(0xFF2D6BFF);
  static const putri = Color(0xFFE0468B);
  static const campur = Color(0xFF0F9D9D);

  static Color forType(String type) {
    switch (type) {
      case 'putra':
        return putra;
      case 'putri':
        return putri;
      default:
        return campur;
    }
  }
}
