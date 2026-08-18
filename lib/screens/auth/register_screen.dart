import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Tambahan untuk memblokir spasi
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isPasswordHidden = true;
  bool _isLoading = false;

  final Color bgColor = const Color(0xFFE8F5E9);
  final Color darkColor = const Color(0xFF353B48);
  final supabase = Supabase.instance.client;

  Future<void> _signUp() async {
    final name = nameController.text.trim();
    final usernameInput = usernameController.text.trim().toLowerCase();
    final password = passwordController.text.trim();

    if (name.isEmpty || usernameInput.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Semua field wajib diisi"), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // --- Trik Dummy Email ---
    final dummyEmail = '$usernameInput@organapp.com';

    try {
      await supabase.auth.signUp(
        email: dummyEmail,
        password: password,
        data: {
          'full_name': name,
          'username': usernameInput,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pendaftaran berhasil! Silakan login.'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message), backgroundColor: Colors.red),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Terjadi kesalahan tak terduga'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: Icon(Icons.close, color: darkColor, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: SizedBox(
                  height: 140,
                  child: Icon(Icons.school_rounded, size: 90, color: darkColor.withOpacity(0.8)),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Create\nAccount",
                style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  color: Colors.black.withOpacity(0.12),
                  height: 1.1,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: nameController,
                style: TextStyle(color: darkColor),
                decoration: InputDecoration(
                  hintText: "Full Name",
                  hintStyle: TextStyle(color: darkColor.withOpacity(0.7), fontSize: 15),
                  suffixIcon: Icon(Icons.person_outline_rounded, color: darkColor),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: darkColor.withOpacity(0.5))),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: darkColor, width: 2)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: usernameController,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')), // Memblokir spasi
                ],
                style: TextStyle(color: darkColor),
                decoration: InputDecoration(
                  hintText: "Username (tanpa spasi)",
                  hintStyle: TextStyle(color: darkColor.withOpacity(0.7), fontSize: 15),
                  suffixIcon: Icon(Icons.alternate_email_rounded, color: darkColor),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: darkColor.withOpacity(0.5))),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: darkColor, width: 2)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: passwordController,
                obscureText: isPasswordHidden,
                style: TextStyle(color: darkColor),
                decoration: InputDecoration(
                  hintText: "Password",
                  hintStyle: TextStyle(color: darkColor.withOpacity(0.7), fontSize: 15),
                  suffixIcon: IconButton(
                    icon: Icon(
                      isPasswordHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: darkColor,
                    ),
                    onPressed: () {
                      setState(() {
                        isPasswordHidden = !isPasswordHidden;
                      });
                    },
                  ),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: darkColor.withOpacity(0.5))),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: darkColor, width: 2)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: darkColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Daftar", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Sudah punya akun? ", style: TextStyle(color: darkColor.withOpacity(0.8), fontSize: 14)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text("Login", style: TextStyle(color: darkColor, fontSize: 14, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}