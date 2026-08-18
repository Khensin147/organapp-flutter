import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

class OrganDetailScreen extends StatefulWidget {
  final String nama;
  final String modelPath;
  final String fungsi;
  final String deskripsi;
  final String fakta;
  final String sistem;

  const OrganDetailScreen({
    super.key,
    required this.nama,
    required this.modelPath,
    required this.fungsi,
    required this.deskripsi,
    required this.fakta,
    this.sistem = "",
  });

  @override
  State<OrganDetailScreen> createState() => _OrganDetailScreenState();
}

class _OrganDetailScreenState extends State<OrganDetailScreen>
    with SingleTickerProviderStateMixin {

  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0;

  static const double _modelHeight = 300.0;
  // Efek mundur aktif hanya 120px pertama scroll
  static const double _maxScrollEffect = 120.0;

  late AnimationController _entryController;
  late Animation<double> _entryFade;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _entryFade = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeIn,
    );
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset =
            _scrollController.offset.clamp(0.0, _maxScrollEffect);
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  double get _progress => _scrollOffset / _maxScrollEffect;

  // ── BUKA MODEL 3D DALAM MODE FULLSCREEN ──────────────
  void _openFullscreenModel(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => FullscreenModelScreen(
          modelPath: widget.modelPath,
          nama: widget.nama,
        ),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    // Card mengecil sedikit dari sisi kiri-kanan saat scroll
    // alignment bottomCenter → bagian bawah card tetap diam, atas yang "mundur"
    final cardScale = 1.0 - (_progress * 0.03);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [

          // ── MODEL 3D — DIAM TOTAL ─────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            height: _modelHeight + topPadding,
            child: FadeTransition(
              opacity: _entryFade,
              child: ModelViewer(
                src: widget.modelPath,
                alt: widget.nama,
                ar: false,
                autoRotate: true,
                cameraControls: true,
                disableZoom: false,
                backgroundColor: const Color(0xFF0A0A0A),
              ),
            ),
          ),

          // ── CARD PUTIH — mengecil sedikit saat scroll ─────
          Positioned(
            top: _modelHeight + topPadding - 28,
            left: 0, right: 0, bottom: 0,
            child: Transform.scale(
              scale: cardScale,
              alignment: Alignment.bottomCenter,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Handle bar
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 10, bottom: 10),
                          width: 36, height: 4,
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // ── NAMA + BOOKMARK ────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.nama,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  if (widget.sistem.isNotEmpty)
                                    Text(
                                      widget.sistem,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black45,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              width: 38, height: 38,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: const Icon(
                                Icons.bookmark_border_rounded,
                                color: Colors.white, size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // ── CHIPS ──────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            _InfoChip(
                              icon: Icons.category_outlined,
                              label: widget.sistem.replaceAll('Sistem ', ''),
                            ),
                            const SizedBox(width: 8),
                            const _InfoChip(
                              icon: Icons.biotech_outlined,
                              label: 'Organ',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── FUNGSI ─────────────────────────────
                      const _SectionLabel(
                        icon: Icons.lightbulb_outline_rounded,
                        label: 'Fungsi Organ',
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.black38, width: 0.5),
                          ),
                          child: Text(
                            widget.fungsi,
                            style: const TextStyle(
                              fontSize: 14, height: 1.7, color: Colors.black87,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── PENJELASAN (paragraf biasa) ────────
                      const _SectionLabel(
                        icon: Icons.menu_book_outlined,
                        label: 'Penjelasan',
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.black38, width: 0.5),
                          ),
                          child: Text(
                            widget.deskripsi,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.8,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.justify,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── FAKTA MENARIK ──────────────────────
                      const _SectionLabel(
                        icon: Icons.star_outline_rounded,
                        label: 'Fakta Menarik',
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.star_rounded,
                                  size: 18, color: Colors.white70),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  widget.fakta,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.7,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── BACK BUTTON ───────────────────────────────────
          Positioned(
            top: topPadding + 8, left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12, width: 0.5),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 16,
                ),
              ),
            ),
          ),

          // ── FULLSCREEN BUTTON ──────────────────────────────
          Positioned(
            top: topPadding + 8, right: 16,
            child: GestureDetector(
              onTap: () => _openFullscreenModel(context),
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12, width: 0.5),
                ),
                child: const Icon(
                  Icons.fullscreen_rounded,
                  color: Colors.white, size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── SCREEN MODEL 3D FULLSCREEN ────────────────────────────
class FullscreenModelScreen extends StatelessWidget {
  final String modelPath;
  final String nama;

  const FullscreenModelScreen({
    super.key,
    required this.modelPath,
    required this.nama,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Model 3D full layar, dengan zoom & rotate aktif
          Positioned.fill(
            child: ModelViewer(
              src: modelPath,
              alt: nama,
              ar: false,
              autoRotate: true,
              cameraControls: true,
              disableZoom: false,
              backgroundColor: const Color(0xFF0A0A0A),
            ),
          ),

          // Nama organ di atas
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 70,
            child: Text(
              nama,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),

          // Tombol tutup
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12, width: 0.5),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white, size: 20,
                ),
              ),
            ),
          ),

          // Petunjuk kecil di bawah
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 0,
            right: 0,
            child: const Center(
              child: Text(
                'Cubit untuk zoom • Geser untuk putar',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white54,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── HELPER: SECTION LABEL ─────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.black),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.black,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ── HELPER: INFO CHIP ─────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.black54),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}