import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HasilScreen extends StatelessWidget {
  final int score;
  final int totalSoal;

  const HasilScreen({
    super.key,
    required this.score,
    required this.totalSoal,
  });

  @override
  Widget build(BuildContext context) {
    // ── PERHITUNGAN NILAI — LOGIC TIDAK DIUBAH ──────────────
    final int nilai =
    totalSoal == 0 ? 0 : ((score / totalSoal) * 100).toInt();
    // ─────────────────────────────────────────────────────────

    final bool isGreat = nilai >= 80;
    final bool isGood = nilai >= 60 && nilai < 80;

    final Color accentColor = isGreat
        ? Colors.amber.shade700
        : isGood
        ? const Color(0xFF3D7A5C)
        : Colors.blueGrey;

    final String titleText = isGreat
        ? "Luar Biasa! 🎉"
        : isGood
        ? "Kerja Bagus! 👍"
        : "Quiz Selesai";

    final String subtitleText = isGreat
        ? "Kamu menguasai materi ini dengan sangat baik."
        : isGood
        ? "Sudah bagus, sedikit lagi sempurna!"
        : "Jangan menyerah, coba lagi ya!";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Hasil Quiz"),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTrophy(100, accentColor, isGreat),

              const SizedBox(height: 16),

              _FadeInDelayed(
                delay: const Duration(milliseconds: 250),
                child: Text(
                  titleText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              _FadeInDelayed(
                delay: const Duration(milliseconds: 350),
                child: Text(
                  subtitleText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),

              const SizedBox(height: 24),

              _FadeInDelayed(
                delay: const Duration(milliseconds: 450),
                child: Text(
                  "Benar : $score / $totalSoal",
                  style: const TextStyle(fontSize: 18),
                ),
              ),

              const SizedBox(height: 10),

              _FadeInDelayed(
                delay: const Duration(milliseconds: 550),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: nilai.toDouble()),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Text(
                      "Nilai : ${value.toInt()}",
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 30),

              _FadeInDelayed(
                delay: const Duration(milliseconds: 700),
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text("Kembali"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrophy(double size, Color color, bool celebrate) {
    final double boxSize = size + 60;
    return SizedBox(
      width: boxSize,
      height: boxSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (celebrate)
            ...List.generate(6, (i) {
              final angle = (pi * 2 / 6) * i;
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  final dx = cos(angle) * 46 * value;
                  final dy = sin(angle) * 46 * value;
                  return Positioned(
                    left: boxSize / 2 + dx - 8,
                    top: boxSize / 2 + dy - 8,
                    child: Opacity(
                      opacity: (1 - value).clamp(0.0, 1.0),
                      child: Icon(Icons.star_rounded,
                          size: 16, color: Colors.amber.withOpacity(0.9)),
                    ),
                  );
                },
              );
            }),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.elasticOut,
            builder: (context, value, child) =>
                Transform.scale(scale: value, child: child),
            child: Icon(Icons.emoji_events, size: size, color: color),
          ),
        ],
      ),
    );
  }
}

// ── HELPER: FADE + SLIDE MASUK DENGAN DELAY ─────────────────
class _FadeInDelayed extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const _FadeInDelayed({required this.child, required this.delay});

  @override
  State<_FadeInDelayed> createState() => _FadeInDelayedState();
}

class _FadeInDelayedState extends State<_FadeInDelayed>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}