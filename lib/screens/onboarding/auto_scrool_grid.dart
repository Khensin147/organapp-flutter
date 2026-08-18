import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Widget grid foto yang otomatis scroll terus-menerus (looping),
/// dengan tiap kolom bisa diatur arahnya berlawanan (naik / turun).
///
/// FIX 1: sebelumnya pakai Future.delayed + jumpTo berdasarkan
/// maxScrollExtent, yang bisa "goyang" (maju-mundur) kalau tinggi
/// gambar berubah saat loading. Sekarang pakai Ticker (berbasis
/// waktu berjalan) + itemExtent tetap.
///
/// FIX 2 (PENTING): jumpTo() bisa dipanggil sebelum Scrollable
/// selesai layout (minScrollExtent/maxScrollExtent masih null),
/// yang bikin crash "Null check operator used on a null value".
/// Kalau exception itu sampai lolos ke dalam Ticker._tick tanpa
/// ditangkap, TICKER-NYA BERHENTI SELAMANYA (kode "jadwalkan tick
/// berikutnya" di dalam Ticker._tick tidak sempat jalan karena
/// keduluan exception) — makanya efeknya grid jadi diem total,
/// bukan cuma error sesaat. Makanya sekarang ada 2 lapis pengaman:
/// (a) cek hasContentDimensions sebelum jumpTo, dan (b) try-catch
/// di sekeliling jumpTo sebagai jaring pengaman kalau ada kondisi
/// tak terduga lainnya.
class AutoScrollGrid extends StatelessWidget {
  /// Tiap elemen list = 1 kolom, isinya widget-widget (misal Image) yang
  /// akan discroll berulang di kolom itu.
  final List<List<Widget>> columns;

  /// true = kolom scroll ke atas, false = kolom scroll ke bawah.
  /// Panjangnya harus sama dengan jumlah `columns`.
  final List<bool> scrollUp;

  /// Tinggi area grid (viewport yang terlihat).
  final double height;

  /// Kecepatan scroll dalam pixel PER DETIK (bukan per frame),
  /// supaya kecepatannya konsisten di HP dengan refresh rate berbeda
  /// (60Hz / 90Hz / 120Hz).
  final double speed;

  /// Tinggi tetap tiap tile/gambar. WAJIB tetap (fixed), supaya
  /// layout tidak pernah berubah saat gambar sedang loading.
  final double itemHeight;

  const AutoScrollGrid({
    super.key,
    required this.columns,
    required this.scrollUp,
    this.height = 500,
    this.speed = 30,
    this.itemHeight = 160,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(columns.length, (i) {
          return Expanded(
            child: _AutoScrollColumn(
              items: columns[i],
              scrollUp: scrollUp[i],
              speed: speed,
              itemHeight: itemHeight,
            ),
          );
        }),
      ),
    );
  }
}

class _AutoScrollColumn extends StatefulWidget {
  final List<Widget> items;
  final bool scrollUp;
  final double speed;
  final double itemHeight;

  const _AutoScrollColumn({
    required this.items,
    required this.scrollUp,
    required this.speed,
    required this.itemHeight,
  });

  @override
  State<_AutoScrollColumn> createState() => _AutoScrollColumnState();
}

class _AutoScrollColumnState extends State<_AutoScrollColumn>
    with SingleTickerProviderStateMixin {
  late final ScrollController _controller;
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    // Ticker jalan disinkron dengan refresh rate layar (bukan timer manual).
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    // try-catch DI LUAR semua logic: apapun yang terjadi di dalam,
    // fungsi ini akan selalu selesai dengan normal, sehingga Ticker
    // selalu berhasil menjadwalkan tick berikutnya dan TIDAK PERNAH
    // berhenti permanen walau ada error tak terduga.
    try {
      if (!mounted || !_controller.hasClients) return;

      // hasContentDimensions baru true setelah Scrollable selesai layout
      // pertama kali. Sebelum itu, minScrollExtent/maxScrollExtent masih
      // null, dan jumpTo() akan crash kalau dipaksa jalan lebih awal.
      if (!_controller.position.hasContentDimensions) return;

      final setLength = widget.items.length * widget.itemHeight;
      if (setLength <= 0) return;

      // Posisi virtual dihitung murni dari waktu berjalan (detik) x kecepatan,
      // sehingga selalu presisi walau frame sempat telat/lag.
      final elapsedSeconds = elapsed.inMicroseconds / 1000000;
      final travelled = elapsedSeconds * widget.speed;

      double posDalamSatuSet = travelled % setLength;
      if (!widget.scrollUp) {
        posDalamSatuSet = setLength - posDalamSatuSet;
      }

      // List dirender 3x lipat (lihat build()), kita mulai dari tengah
      // (1 set) supaya ada "ruang" scroll ke arah manapun tanpa kena
      // index negatif.
      final target = setLength + posDalamSatuSet;

      if (_controller.position.pixels != target) {
        _controller.jumpTo(target);
      }
    } catch (e) {
      // Jaring pengaman terakhir: kalau ada error tak terduga, cukup
      // dilewati untuk tick ini saja — ticker tetap lanjut di frame
      // berikutnya, tidak ikut mati.
      debugPrint('AutoScrollGrid: tick dilewati karena error -> $e');
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Item digandakan 3x supaya saat loop balik ke posisi awal,
    // secara visual masih terlihat menyambung (tidak "kosong").
    final loopedItems = [...widget.items, ...widget.items, ...widget.items];

    return ListView.builder(
      controller: _controller,
      physics: const NeverScrollableScrollPhysics(), // user tidak bisa geser manual
      itemExtent: widget.itemHeight, // FIX: tinggi tetap, layout tidak goyang
      itemCount: loopedItems.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: loopedItems[index],
      ),
    );
  }
}