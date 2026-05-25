import 'package:flutter/material.dart';

class AppColors {
  static const Color canvas      = Color(0xFFF8F5F0);
  static const Color paper       = Color(0xFFFFFFFF);
  static const Color parchment   = Color(0xFFF4EFE8);
  static const Color inkDark     = Color(0xFF1A1614);
  static const Color inkMid      = Color(0xFF3D3530);
  static const Color inkLight    = Color(0xFF7A6F65);
  static const Color inkFaint    = Color(0xFFB5AAA0);
  static const Color gold        = Color(0xFFC8A96B);
  static const Color goldLight   = Color(0xFFDFC28E);
  static const Color goldFaint   = Color(0xFFF4EFE8);
  static const Color rule        = Color(0xFFE0D7CA);
  static const Color cardBorder  = Color(0xFFEDE6DC);

  // Header gradient — cream-to-parchment (replaces harsh black)
  static const Color headerTop    = Color(0xFFF8F5F0);
  static const Color headerBottom = Color(0xFFEEE8DF);
}

class AppRadius {
  static const double sm   = 8.0;
  static const double md   = 14.0;
  static const double lg   = 20.0;
  static const double xl   = 28.0;
  static const double pill = 100.0;
}

/// Classic ornamental divider row (✦ dengan dua garis tipis di kiri-kanan)
class OrnamentDivider extends StatelessWidget {
  final double lineWidth;
  final double opacity;
  const OrnamentDivider({Key? key, this.lineWidth = 40, this.opacity = 1.0})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = AppColors.gold.withOpacity(opacity);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: lineWidth, height: 0.5, color: color),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '✦',
            style: TextStyle(color: color, fontSize: 8),
          ),
        ),
        Container(width: lineWidth, height: 0.5, color: color),
      ],
    );
  }
}

/// Logo Musra — menghilangkan background hitam via BlendMode.multiply
/// sehingga logo tampak transparan di atas background cream/parchment
class MusraLogo extends StatelessWidget {
  final double height;
  const MusraLogo({Key? key, this.height = 280}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo_musra.png',
      height: height,
      fit: BoxFit.contain,
      // BlendMode.multiply: pixel hitam (0,0,0) × background cream → background
      // pixel putih/abu logo tetap terlihat dengan nuansa krem
      color: const Color(0xFFF8F5F0),
      colorBlendMode: BlendMode.lighten,
    );
  }
}

/// Versi kecil logo untuk avatar/dialog (background transparan via multiply)
class MusraLogoSmall extends StatelessWidget {
  final double size;
  final Color bgColor;
  const MusraLogoSmall({
    Key? key,
    this.size = 56,
    this.bgColor = AppColors.canvas,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
        border: Border.all(
          color: AppColors.gold.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/logo_musra.png',
          fit: BoxFit.contain,
          color: bgColor,
          colorBlendMode: BlendMode.lighten,
        ),
      ),
    );
  }
}