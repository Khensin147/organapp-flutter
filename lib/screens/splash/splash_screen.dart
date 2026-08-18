import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:organappfr/screens/onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Fase 1 (0.0 - 0.45): posisi Y bola jatuh dari atas -> tengah -> mantul 3x
  late final Animation<double> _ballOffsetY;

  // Fase 2 (0.45 - 0.75): radius lingkaran membesar sampai menutupi
  // SELURUH layar (teknik "circular reveal")
  late final Animation<double> _scaleAnim;

  // Fase 3 (0.75 - 1.0): logo muncul dari bawah ke tengah + fade in
  late final Animation<double> _logoSlideAnim;
  late final Animation<double> _logoFadeAnim;

  static const double _circleSize = 40.0; // diameter bola saat jatuh & mantul
  static const double _dropStartY = -1200.0;
  static const Duration _holdAfterLogo = Duration(milliseconds: 900);

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );

    _ballOffsetY = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: _dropStartY, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -50.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 12,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -50.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 12,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -22.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 9,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -22.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 9,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -9.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 6,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -9.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 6,
      ),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.45),
    ));

    _scaleAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 0.75, curve: Curves.easeInOutCubic),
    );

    _logoSlideAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.75, 1.0, curve: Curves.easeOutCubic),
    );

    _logoFadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.8, 1.0, curve: Curves.easeIn),
    );

    _navigateNext();
  }

  void _navigateNext() async {
    await _controller.forward();
    await Future.delayed(_holdAfterLogo);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          // Splash SELALU ke OnboardingScreen sekarang, tidak peduli
          // apakah user sudah pernah login atau belum. Pengecekan sesi
          // login (skip login jika masih dalam 2 menit) dipindah ke
          // langkah SETELAH onboarding, lewat AuthGate.
          builder: (context) => const OnboardingScreen(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder dipakai (bukan cuma MediaQuery) supaya ukuran yang
    // dipakai untuk hitung radius benar-benar sama dengan ukuran ruang
    // yang tersedia untuk widget ini, apa pun kondisi parent-nya.
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenSize = Size(constraints.maxWidth, constraints.maxHeight);

          // Jarak dari titik tengah layar ke pojok terjauh (setengah diagonal).
          // Ini radius MINIMAL yang dibutuhkan supaya lingkaran benar-benar
          // menyentuh semua pojok. Dikali 1.5 sebagai buffer supaya pasti aman.
          final halfDiagonal = math.sqrt(
            math.pow(screenSize.width / 2, 2) +
                math.pow(screenSize.height / 2, 2),
          ) *
              1.5;

          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              // Titik pusat lingkaran: bergerak naik-turun saat fase
              // jatuh & mantul, lalu diam persis di tengah layar
              // begitu fase itu selesai (offsetY kembali ke 0).
              final ballCenter = Offset(
                screenSize.width / 2,
                screenSize.height / 2 + _ballOffsetY.value,
              );

              // Radius lubang lingkaran: kecil (bola) -> besar (menutupi layar)
              final revealRadius = (_circleSize / 2) +
                  (halfDiagonal - _circleSize / 2) * _scaleAnim.value;

              final logoOffsetY =
                  (screenSize.height / 2 + 150) * (1 - _logoSlideAnim.value);

              return Stack(
                children: [
                  // --- Container hijau SUDAH seukuran layar penuh,
                  //     hanya "dibuka" lewat lubang lingkaran yang membesar.
                  //     Karena container-nya sudah pas layar, begitu radius
                  //     cukup besar, otomatis SELURUH layar tertutup. ---
                  Positioned.fill(
                    child: ClipPath(
                      clipper: _CircleRevealClipper(
                        center: ballCenter,
                        radius: revealRadius,
                      ),
                      child: Container(
                        color: const Color(0xFF1B3F9E), // biru sesuai warna logo
                      ),
                    ),
                  ),

                  // --- Logo muncul dari bawah setelah layar tertutup ---
                  if (_controller.value >= 0.75)
                    Center(
                      child: Transform.translate(
                        offset: Offset(0, logoOffsetY),
                        child: Opacity(
                          opacity: _logoFadeAnim.value,
                          child: Image.asset(
                            'assets/images/solo.png',
                            width: 150,
                            height: 150,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Clipper yang membuat "lubang" berbentuk lingkaran pada child-nya.
/// Dipakai untuk efek circular reveal: container hijau full-layar
/// hanya terlihat di area dalam lingkaran ini, dan begitu radius-nya
/// cukup besar, seluruh container otomatis ikut terlihat (menutupi layar).
class _CircleRevealClipper extends CustomClipper<Path> {
  final Offset center;
  final double radius;

  _CircleRevealClipper({required this.center, required this.radius});

  @override
  Path getClip(Size size) {
    return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldReclip(covariant _CircleRevealClipper oldClipper) {
    return oldClipper.center != center || oldClipper.radius != radius;
  }
}