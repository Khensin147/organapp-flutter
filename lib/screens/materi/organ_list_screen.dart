import 'package:flutter/material.dart';
import 'package:organappfr/models/organ_models.dart';
import 'package:organappfr/service/organ_service.dart';
import 'package:organappfr/service/quiz_service.dart';
import 'package:organappfr/screens/quiz/soalscreen.dart';
import 'detailorgan.dart';

class OrganListScreen extends StatefulWidget {
  final int pertemuanId;
  final String judulPertemuan;

  const OrganListScreen({
    super.key,
    required this.pertemuanId,
    required this.judulPertemuan,
  });

  @override
  State<OrganListScreen> createState() => _OrganListScreenState();
}

class _OrganListScreenState extends State<OrganListScreen>
    with TickerProviderStateMixin {
  final OrganService _service = OrganService();
  final QuizService _quizService = QuizService();
  List<OrganModel> _organList = [];
  List<String> _sudahDilihat = []; // organ_id yang sudah dilihat
  bool _isLoading = false;
  bool _isStartingQuiz = false;

  // Warna utama (brand)
  static const Color _tema = Color(0xFF1B3F9E);

  // Animasi untuk kartu grid muncul satu-satu (staggered)
  late final AnimationController _listController;

  // Animasi tombol "Mulai Quiz" berdenyut pelan biar menarik perhatian
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _loadAll();
  }

  @override
  void dispose() {
    _listController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final data = await _service.getOrganByPertemuan(widget.pertemuanId);
      final sudah = await _service.getOrganSudahDilihat();
      setState(() {
        _organList = data.map((e) => OrganModel.fromJson(e)).toList();
        _sudahDilihat = sudah;
      });
      _listController.forward(from: 0);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _mulaiQuiz() async {
    setState(() => _isStartingQuiz = true);
    try {
      // FIX: pakai judul pertemuan (bukan organ.sistemOrgan) sebagai kata
      // kunci pencarian kategori quiz. Judul pertemuan lebih bisa
      // diandalkan karena tidak tergantung organ mana yang kebetulan
      // pertama muncul di list (yang datanya bisa saja tidak konsisten,
      // misal organ "mata" punya sistem_organ = "mata" padahal masuk
      // pertemuan "sistem pernapasan").
      final judulPencarian = widget.judulPertemuan;

      final kategori =
      await _quizService.getKategoriBySistemOrgan(judulPencarian);

      if (!mounted) return;

      if (kategori == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Quiz untuk '$judulPencarian' belum tersedia."),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SoalScreen(
            kategoriId: kategori['id'] as String,
            judulKategori: kategori['judul'] as String,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal memuat quiz: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isStartingQuiz = false);
    }
  }

  // ================= WARNA & ICON PER SISTEM/ORGAN =================
  // Palet warna-warni supaya tiap organ terasa beda dan lebih "hidup"
  // di mata anak SMP, meski tetap dalam keluarga warna yang serasi.

  Color _getColor(String sistem) {
    switch (sistem.toLowerCase()) {
      case "sistem peredaran darah":
      case "kardiovaskular":
        return const Color(0xFFE0364B);
      case "sistem pernapasan":
      case "pernapasan":
        return const Color(0xFF1E88E5);
      case "sistem pencernaan":
      case "pencernaan":
        return const Color(0xFFE68A1E);
      default:
        return const Color(0xFF16A085);
    }
  }

  Color _getBgColor(String sistem) {
    switch (sistem.toLowerCase()) {
      case "sistem peredaran darah":
      case "kardiovaskular":
        return const Color(0xFFFDE7E9);
      case "sistem pernapasan":
      case "pernapasan":
        return const Color(0xFFE3F1FD);
      case "sistem pencernaan":
      case "pencernaan":
        return const Color(0xFFFCEEDA);
      default:
        return const Color(0xFFDFF6EE);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _organList.length;
    final dilihat = _sudahDilihat
        .where((id) => _organList.any((o) => o.id == id))
        .length;
    final progress = total == 0 ? 0.0 : dilihat / total;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: Text(
          widget.judulPertemuan,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _organList.isEmpty
          ? const Center(
        child: Text(
          "Belum ada organ untuk pertemuan ini.",
          style: TextStyle(color: Colors.grey),
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header dengan progress bar animasi
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_tema, Color(0xFF3A63C9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _tema.withOpacity(0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Yuk, pilih organ! 🔎",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TweenAnimationBuilder<int>(
                        tween: IntTween(begin: 0, end: dilihat),
                        duration: const Duration(milliseconds: 700),
                        builder: (context, value, _) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.22),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              "$value/$total",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) {
                        return LinearProgressIndicator(
                          value: value,
                          minHeight: 9,
                          backgroundColor: Colors.white.withOpacity(0.25),
                          valueColor: const AlwaysStoppedAnimation(
                              Color(0xFFFFD54F)),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Grid organ dengan animasi masuk satu-satu
            Expanded(
              child: GridView.builder(
                itemCount: _organList.length,
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.95,
                ),
                itemBuilder: (context, index) {
                  final organ = _organList[index];
                  final warna = _getColor(organ.sistemOrgan);
                  final bgWarna = _getBgColor(organ.sistemOrgan);
                  final sudahDilihat = _sudahDilihat.contains(organ.id);

                  // Interval animasi masuk per index -> efek staggered
                  final start =
                  (index / _organList.length * 0.6).clamp(0.0, 1.0);
                  final end = (start + 0.4).clamp(0.0, 1.0);
                  final animasi = CurvedAnimation(
                    parent: _listController,
                    curve: Interval(start, end, curve: Curves.easeOutBack),
                  );

                  return AnimatedBuilder(
                    animation: animasi,
                    builder: (context, child) {
                      final v = animasi.value.clamp(0.0, 1.0);
                      return Opacity(
                        opacity: v,
                        child: Transform.translate(
                          offset: Offset(0, 30 * (1 - v)),
                          child: Transform.scale(
                            scale: 0.85 + (0.15 * v),
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: _OrganCard(
                      organ: organ,
                      warna: warna,
                      bgWarna: bgWarna,
                      sudahDilihat: sudahDilihat,
                      onTap: () async {
                        await _service.tandaiSudahDilihat(organ.id);
                        if (!_sudahDilihat.contains(organ.id)) {
                          setState(() => _sudahDilihat.add(organ.id));
                        }
                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OrganDetailScreen(
                                nama: organ.nama,
                                modelPath: organ.modelUrl ?? '',
                                fungsi: organ.fungsi,
                                deskripsi: organ.deskripsi,
                                fakta: organ.faktaMenarik,
                                sistem: organ.sistemOrgan,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _organList.isEmpty
          ? null
          : SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: SizedBox(
            width: double.infinity,
            child: ScaleTransition(
              scale: Tween(begin: 1.0, end: 1.035).animate(
                CurvedAnimation(
                  parent: _pulseController,
                  curve: Curves.easeInOut,
                ),
              ),
              child: ElevatedButton.icon(
                onPressed: _isStartingQuiz ? null : _mulaiQuiz,
                icon: _isStartingQuiz
                    ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.rocket_launch_rounded,
                    color: Colors.white, size: 20),
                label: Text(
                  _isStartingQuiz ? "Menyiapkan..." : "Mulai Quiz",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _tema,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                  shadowColor: _tema.withOpacity(0.5),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================= KARTU ORGAN DENGAN ANIMASI TEKAN =================
class _OrganCard extends StatefulWidget {
  final OrganModel organ;
  final Color warna;
  final Color bgWarna;
  final bool sudahDilihat;
  final VoidCallback onTap;

  const _OrganCard({
    required this.organ,
    required this.warna,
    required this.bgWarna,
    required this.sudahDilihat,
    required this.onTap,
  });

  @override
  State<_OrganCard> createState() => _OrganCardState();
}

class _OrganCardState extends State<_OrganCard> {
  double _scale = 1.0;

  void _setScale(double s) => setState(() => _scale = s);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setScale(0.94),
      onTapUp: (_) => _setScale(1.0),
      onTapCancel: () => _setScale(1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: widget.sudahDilihat
                    ? widget.warna.withOpacity(0.25)
                    : Colors.grey.withOpacity(0.12),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
            border: widget.sudahDilihat
                ? Border.all(color: widget.warna, width: 1.6)
                : Border.all(color: Colors.grey.shade100, width: 1),
          ),
          child: Stack(
            children: [
              // Nama organ di tengah kartu
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.organ.nama,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.bgWarna,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.organ.sistemOrgan,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: widget.warna,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Badge centang di pojok kanan atas kalau sudah dilihat
              if (widget.sudahDilihat)
                Positioned(
                  top: 0,
                  right: 0,
                  child: AnimatedScale(
                    scale: widget.sudahDilihat ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.elasticOut,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF16A085),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                    ),
                  ),
                ),

              // Status di pojok kanan bawah
              Positioned(
                bottom: 0,
                right: 0,
                child: Text(
                  widget.sudahDilihat ? "Sudah dilihat" : "Lihat",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: widget.sudahDilihat
                        ? widget.warna
                        : Colors.grey.shade400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}