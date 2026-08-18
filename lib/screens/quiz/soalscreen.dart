import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:organappfr/models/quiz_models.dart';
import 'package:organappfr/service/quiz_service.dart';
import 'package:organappfr/screens/quiz/hasilscreen.dart';

class SoalScreen extends StatefulWidget {
  final String kategoriId;
  final String judulKategori;

  const SoalScreen({
    super.key,
    required this.kategoriId,
    required this.judulKategori,
  });

  @override
  State<SoalScreen> createState() => _SoalScreenState();
}

class _SoalScreenState extends State<SoalScreen>
    with SingleTickerProviderStateMixin {
  // ── BACKEND / DATA — TIDAK DIUBAH ───────────────────────
  final QuizService _service = QuizService();
  List<QuizSoalModel> _soalList = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  int _soalIndex = 0;
  int _score = 0;

  Future<void> _loadSoal() async {
    try {
      final data = await _service.getSoalByKategori(widget.kategoriId);
      setState(() {
        _soalList = data.map((e) => QuizSoalModel.fromJson(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }
  // ─────────────────────────────────────────────────────────

  // ── STATE UNTUK ANIMASI & FEEDBACK (UI SAJA) ──────────────
  int? _selectedIndex;
  bool _answered = false;
  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _loadSoal();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  double _shakeOffset(double t) => sin(t * pi * 6) * 10 * (1 - t);

  // ── LOGIC PENJAWABAN — SAMA SEPERTI SEBELUMNYA, DITAMBAH JEDA UNTUK FEEDBACK ──
  Future<void> _pilihJawaban(int index) async {
    if (_answered || _isSubmitting) return;

    final soal = _soalList[_soalIndex];
    final benar = index == soal.indexJawabanBenar;

    setState(() {
      _selectedIndex = index;
      _answered = true;
    });

    if (benar) {
      _score++;
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.mediumImpact();
      _shakeController.forward(from: 0);
    }

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    if (_soalIndex < _soalList.length - 1) {
      setState(() {
        _soalIndex++;
        _selectedIndex = null;
        _answered = false;
      });
      return;
    }

    // Soal terakhir dijawab → simpan hasil ke Supabase
    setState(() => _isSubmitting = true);
    try {
      await _service.simpanHasilQuiz(
        kategoriId: widget.kategoriId,
        judulKategori: widget.judulKategori,
        skor: _score,
        totalSoal: _soalList.length,
      );
    } catch (e) {
      debugPrint("Gagal simpan nilai: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Nilai gagal disimpan: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HasilScreen(
          score: _score,
          totalSoal: _soalList.length,
        ),
      ),
    );
  }
  // ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    if (_soalList.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.judulKategori)),
        body: const Center(child: Text("Belum ada soal.")),
      );
    }

    final soal = _soalList[_soalIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(
            "${widget.judulKategori} • Soal ${_soalIndex + 1}/${_soalList.length}"),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProgressBar(),
                const SizedBox(height: 26),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) {
                      final slide = Tween<Offset>(
                        begin: const Offset(0.08, 0),
                        end: Offset.zero,
                      ).animate(animation);
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(position: slide, child: child),
                      );
                    },
                    child: SingleChildScrollView(
                      key: ValueKey(_soalIndex),
                      child: _buildQuestionContent(soal),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_isSubmitting,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _isSubmitting ? 1 : 0,
                child: Container(
                  color: Colors.black45,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 12),
                        Text('Menyimpan hasil...',
                            style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final target = (_soalIndex + 1) / _soalList.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: target),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
          builder: (context, value, _) => ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 9,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF2C2C2A)),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Soal ${_soalIndex + 1} dari ${_soalList.length}  •  Skor sementara: $_score',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildQuestionContent(QuizSoalModel soal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          soal.pertanyaan,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 28),
        ...List.generate(soal.pilihan.length, (index) {
          return _StaggeredEntry(
            key: ValueKey('opt_${_soalIndex}_$index'),
            index: index,
            child: _buildOptionButton(soal, index),
          );
        }),
      ],
    );
  }

  Widget _buildOptionButton(QuizSoalModel soal, int index) {
    final huruf = ['A', 'B', 'C', 'D'][index];
    final isCorrect = index == soal.indexJawabanBenar;
    final isSelected = index == _selectedIndex;
    final showResult = _answered;

    Color bgColor = Colors.white;
    Color borderColor = Colors.grey.shade300;
    Color textColor = Colors.black87;
    Widget? trailingIcon;

    if (showResult) {
      if (isCorrect) {
        bgColor = Colors.green.shade50;
        borderColor = Colors.green;
        textColor = Colors.green.shade800;
        trailingIcon = const Icon(Icons.check_circle_rounded,
            color: Colors.green, size: 20);
      } else if (isSelected) {
        bgColor = Colors.red.shade50;
        borderColor = Colors.red;
        textColor = Colors.red.shade800;
        trailingIcon =
        const Icon(Icons.cancel_rounded, color: Colors.red, size: 20);
      } else {
        bgColor = Colors.grey.shade50;
        borderColor = Colors.grey.shade200;
        textColor = Colors.black38;
      }
    }

    final isWrongSelected = showResult && isSelected && !isCorrect;

    final button = Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap:
          (_answered || _isSubmitting) ? null : () => _pilihJawaban(index),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: borderColor, width: 1.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: showResult && (isCorrect || isSelected)
                        ? borderColor.withOpacity(0.15)
                        : Colors.grey.shade100,
                  ),
                  child: Text(
                    huruf,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: textColor),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    soal.pilihan[index],
                    style: TextStyle(
                      fontSize: 15,
                      color: textColor,
                      fontWeight: (isCorrect && showResult)
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
                if (trailingIcon != null) trailingIcon,
              ],
            ),
          ),
        ),
      ),
    );

    if (isWrongSelected) {
      return AnimatedBuilder(
        animation: _shakeController,
        builder: (context, child) {
          final dx = _shakeOffset(_shakeController.value);
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: button,
      );
    }

    return button;
  }
}

// ── HELPER: OPSI MUNCUL BERTAHAP (STAGGERED) ────────────────
class _StaggeredEntry extends StatefulWidget {
  final int index;
  final Widget child;
  const _StaggeredEntry({super.key, required this.index, required this.child});

  @override
  State<_StaggeredEntry> createState() => _StaggeredEntryState();
}

class _StaggeredEntryState extends State<_StaggeredEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: 70 * widget.index), () {
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