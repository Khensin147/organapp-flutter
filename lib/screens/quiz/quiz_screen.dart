import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:organappfr/models/quiz_models.dart';
import 'package:organappfr/service/quiz_service.dart';
import 'package:organappfr/screens/quiz/soalscreen.dart';

enum _SortMode { defaultOrder, az, jumlahDesc }

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  // ── BACKEND / DATA — TIDAK DIUBAH ───────────────────────
  final QuizService _service = QuizService();
  List<QuizKategoriModel> _kategoriList = [];
  bool _isLoading = false;

  Future<void> _loadKategori() async {
    setState(() => _isLoading = true);
    try {
      final data = await _service.getKategori();
      final list = data.map((e) => QuizKategoriModel.fromJson(e)).toList();
      for (final k in list) {
        k.jumlahSoal = await _service.countSoal(k.id);
      }
      setState(() => _kategoriList = list);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  // ─────────────────────────────────────────────────────────

  // ── STATE UNTUK INTERAKSI TAMBAHAN (UI SAJA) ──────────────
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _SortMode _sortMode = _SortMode.defaultOrder;

  @override
  void initState() {
    super.initState();
    _loadKategori();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _totalSoal =>
      _kategoriList.fold<int>(0, (sum, k) => sum + k.jumlahSoal);

  List<QuizKategoriModel> get _filteredList {
    var list = _kategoriList
        .where((k) =>
        k.judul.toLowerCase().contains(_searchQuery.trim().toLowerCase()))
        .toList();

    switch (_sortMode) {
      case _SortMode.az:
        list.sort(
                (a, b) => a.judul.toLowerCase().compareTo(b.judul.toLowerCase()));
        break;
      case _SortMode.jumlahDesc:
        list.sort((a, b) => b.jumlahSoal.compareTo(a.jumlahSoal));
        break;
      case _SortMode.defaultOrder:
        break;
    }
    return list;
  }

  void _startQuiz(QuizKategoriModel k) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SoalScreen(
          kategoriId: k.id,
          judulKategori: k.judul,
        ),
      ),
    );
  }

  void _showKategoriDetail(QuizKategoriModel k) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.quiz_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(k.judul,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text(
                          '${k.jumlahSoal} soal pilihan ganda',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Batal',
                          style: TextStyle(color: Colors.black87)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _startQuiz(k);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C2C2A),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Mulai Sekarang',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Quiz Organ Tubuh",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
              "${_kategoriList.length} kategori • $_totalSoal soal",
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<_SortMode>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Urutkan',
            onSelected: (mode) {
              HapticFeedback.selectionClick();
              setState(() => _sortMode = mode);
            },
            itemBuilder: (context) => [
              _sortMenuItem(_SortMode.defaultOrder, 'Urutan Default',
                  Icons.list_rounded),
              _sortMenuItem(
                  _SortMode.az, 'Nama (A-Z)', Icons.sort_by_alpha_rounded),
              _sortMenuItem(_SortMode.jumlahDesc, 'Soal Terbanyak',
                  Icons.trending_up_rounded),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _kategoriList.isEmpty
          ? _buildEmptyState()
          : Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadKategori,
              child: _filteredList.isEmpty
                  ? ListView(
                physics:
                const AlwaysScrollableScrollPhysics(),
                children: [_buildNoResult()],
              )
                  : ListView.builder(
                padding:
                const EdgeInsets.fromLTRB(12, 4, 12, 24),
                itemCount: _filteredList.length,
                itemBuilder: (context, index) {
                  final k = _filteredList[index];
                  return _AnimatedListItem(
                    key: ValueKey(k.id),
                    index: index,
                    child: _buildKategoriCard(k, index),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<_SortMode> _sortMenuItem(
      _SortMode mode, String label, IconData icon) {
    final selected = _sortMode == mode;
    return PopupMenuItem(
      value: mode,
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: selected ? const Color(0xFF2C2C2A) : Colors.grey),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: selected ? Colors.black87 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Cari kategori quiz...',
          hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
          prefixIcon: const Icon(Icons.search_rounded,
              size: 20, color: Colors.grey),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.close_rounded,
                size: 18, color: Colors.grey),
            onPressed: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
          )
              : null,
          filled: true,
          fillColor: Colors.grey.shade100,
          contentPadding:
          const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        style: const TextStyle(fontSize: 13),
      ),
    );
  }

  Widget _buildKategoriCard(QuizKategoriModel k, int index) {
    final nomor = (index + 1).toString().padLeft(2, '0');
    final isEmpty = k.jumlahSoal == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200, width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEmpty ? null : () => _showKategoriDetail(k),
          splashColor: Colors.black.withOpacity(0.04),
          highlightColor: Colors.black.withOpacity(0.02),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(nomor,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(k.judul,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87)),
                      const SizedBox(height: 3),
                      Text(
                        "${k.jumlahSoal} soal pilihan ganda",
                        style:
                        const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Tombol mulai
                GestureDetector(
                  onTap: isEmpty
                      ? null
                      : () {
                    HapticFeedback.selectionClick();
                    _startQuiz(k);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isEmpty
                          ? Colors.grey.shade300
                          : const Color(0xFF2C2C2A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isEmpty ? "Kosong" : "Mulai",
                      style: TextStyle(
                          color: isEmpty ? Colors.grey : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.quiz_outlined, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text("Belum ada quiz tersedia.",
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _loadKategori,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Muat Ulang'),
              style: TextButton.styleFrom(foregroundColor: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResult() {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('Kategori "$_searchQuery" tidak ditemukan',
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── HELPER: ANIMASI MASUK PER ITEM (fade + slide) ──────────
class _AnimatedListItem extends StatefulWidget {
  final int index;
  final Widget child;
  const _AnimatedListItem({super.key, required this.index, required this.child});

  @override
  State<_AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<_AnimatedListItem>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    final delay = Duration(milliseconds: 40 * widget.index.clamp(0, 10));
    Future.delayed(delay, () {
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
    super.build(context);
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}