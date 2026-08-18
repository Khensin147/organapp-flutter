import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:organappfr/screens/home/home_screen.dart';
import 'package:organappfr/screens/materi/materi_screen.dart';
import 'package:organappfr/screens/leaderboard.dart';
import 'package:organappfr/screens/quiz/quiz_screen.dart';

import 'materi/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;

  // Index tujuan yang lagi "dituju" selama animasi fade berjalan.
  int? _pendingIndex;

  late final AnimationController _transitionController;

  // static const -> dijamin hanya ada SATU instance List<Widget> selama app
  // hidup, tidak akan pernah dibuat ulang meskipun _MainScreenState
  // ter-construct ulang oleh parent widget di atasnya. Ini mencegah
  // initState()/fetch data di tiap screen terpanggil dua kali.
  static const List<Widget> _pages = [
    HomeScreen(),
    MateriScreen(),
    QuizScreen(),
    LeaderboardScreen(),
    ProfileScreen(),
  ];

  final List<_NavItemData> _navItems = const [
    _NavItemData(icon: Icons.home_rounded, label: 'Beranda'),
    _NavItemData(icon: Icons.description_rounded, label: 'Materi'),
    _NavItemData(icon: Icons.menu_book_rounded, label: 'Kuis'),
    _NavItemData(icon: Icons.bar_chart_rounded, label: 'Nilai'),
    _NavItemData(icon: Icons.person_rounded, label: 'Profil'),
  ];

  @override
  void initState() {
    super.initState();
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    // Ganti konten IndexedStack tepat di titik paling pudar (tengah animasi),
    // supaya perpindahan halaman terasa mulus, bukan "loncat" tiba-tiba.
    _transitionController.addListener(() {
      if (_transitionController.value >= 0.5 && _pendingIndex != null) {
        setState(() {
          _selectedIndex = _pendingIndex!;
          _pendingIndex = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _transitionController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex || _pendingIndex != null) return;
    HapticFeedback.selectionClick();

    _pendingIndex = index;
    _transitionController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      extendBody: true,
      body: AnimatedBuilder(
        animation: _transitionController,
        builder: (context, child) {
          final double t = _transitionController.value;
          // Fade lembut: turun sedikit ke 0.55 lalu naik lagi ke 1.0.
          // Tidak pernah benar-benar hilang, jadi tidak terasa "kedip"
          // atau berat di mata — cuma sekilas lebih redup lalu jelas lagi.
          final double opacity = t <= 0.5
              ? 1.0 - (t / 0.5) * 0.45
              : 0.55 + ((t - 0.5) / 0.5) * 0.45;

          // Sedikit gerak naik-turun (4px) supaya transisinya terasa hidup
          // tanpa bikin pusing, jauh lebih kalem dibanding circle wipe.
          final double dy = t <= 0.5 ? (t / 0.5) * 4 : (1 - (t - 0.5) / 0.5) * 4;

          return Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(0, dy),
              child: child,
            ),
          );
        },
        // Semua halaman tetap "hidup" di sini — state & loading-nya
        // tidak pernah dibangun ulang tiap pindah tab.
        child: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: _buildModernNavBar(),
    );
  }

  // ── BOTTOM NAVIGATION BAR ────────────────────────────────────────────
  Widget _buildModernNavBar() {
    const double barHeight = 64;
    const double centerButtonSize = 56;
    const double centerButtonLift = 16;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SizedBox(
        height: barHeight + centerButtonLift,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: barHeight,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: _NavColors.primary.withOpacity(0.18),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _NavBarItem(
                    data: _navItems[0],
                    isSelected: _selectedIndex == 0,
                    onTap: () => _onItemTapped(0),
                  ),
                  _NavBarItem(
                    data: _navItems[1],
                    isSelected: _selectedIndex == 1,
                    onTap: () => _onItemTapped(1),
                  ),
                  SizedBox(width: centerButtonSize - 4),
                  _NavBarItem(
                    data: _navItems[3],
                    isSelected: _selectedIndex == 3,
                    onTap: () => _onItemTapped(3),
                  ),
                  _NavBarItem(
                    data: _navItems[4],
                    isSelected: _selectedIndex == 4,
                    onTap: () => _onItemTapped(4),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              child: _CenterNavButton(
                icon: _navItems[2].icon,
                size: centerButtonSize,
                isSelected: _selectedIndex == 2,
                onTap: () => _onItemTapped(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── WARNA SHARED ──────────────────────────────────────────────────────
class _NavColors {
  static const Color primary = Color(0xFF6C5CE7);
  static const Color primaryDark = Color(0xFF5B4FE0);
  static const Color primarySoft = Color(0xFFEFEAFE);
  static const Color inactive = Color(0xFF9CA3AF);
}

// ── ITEM NAVBAR — bounce elastis saat aktif ─────────────────────────────
class _NavBarItem extends StatelessWidget {
  final _NavItemData data;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.data,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? _NavColors.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(isSelected ? 16 : 14),
        ),
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 350),
          curve: Curves.elasticOut,
          tween: Tween<double>(begin: 0.8, end: isSelected ? 1.15 : 1.0),
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: Icon(
                data.icon,
                size: 22,
                color: isSelected ? _NavColors.primary : _NavColors.inactive,
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── TOMBOL TENGAH — rotasi kecil + pulse saat dipilih ───────────────────
class _CenterNavButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final bool isSelected;
  final VoidCallback onTap;

  const _CenterNavButton({
    required this.icon,
    required this.size,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 450),
        curve: Curves.elasticOut,
        tween: Tween<double>(begin: 1.0, end: isSelected ? 1.08 : 1.0),
        builder: (context, scale, child) {
          return Transform.scale(scale: scale, child: child);
        },
        child: AnimatedRotation(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          turns: isSelected ? 0.02 : 0.0,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [_NavColors.primary, _NavColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: _NavColors.primary.withOpacity(isSelected ? 0.55 : 0.4),
                  blurRadius: isSelected ? 20 : 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}

// ── DATA MODEL ───────────────────────────────────────────────────────
class _NavItemData {
  final IconData icon;
  final String label;
  const _NavItemData({required this.icon, required this.label});
}