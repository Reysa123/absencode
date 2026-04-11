import 'dart:async';

import 'package:absen/main.dart';
import 'package:absen/screens/user_data_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final StreamSubscription authSub;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isLogin = true;

  final supabase = Supabase.instance.client;

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  Future<void> _authenticate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      log_in = true;
    });

    try {
      if (_isLogin) {
        final response = await supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        final user = response.user;
        if (user != null) {
          final pref = await SharedPreferences.getInstance();
          await pref.setString('user', _emailController.text.trim());
          await pref.setString('pass', _passwordController.text.trim());
          Fluttertoast.showToast(
            msg: "Login berhasil!",
            toastLength: Toast.LENGTH_LONG,
          );
          if (mounted) _navigateToUserData(user.id);
          setState(() {
            _isLoading = false;
            log_in = false;
          });
        }
      } else {
        setState(() {
          _isLoading = true;
        });
        final response = await supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          emailRedirectTo: kIsWeb
              ? null
              : 'absen://callback', // Ganti dengan scheme app Anda
        );

        final user = response.user;
        if (user != null) {
          Fluttertoast.showToast(
            webShowClose: true,
            msg:
                "Registrasi berhasil! Silakan periksa email Anda untuk konfirmasi.",
            toastLength: Toast.LENGTH_LONG,
          );
          // late final StreamSubscription authSub;

          // Jangan save credentials atau navigate sampai confirmed
        }
      }
    } catch (e) {
      Fluttertoast.showToast(
        webShowClose: true,
        msg: "Error: ${e.toString()}",
        toastLength: Toast.LENGTH_LONG,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToUserData(String userId) async {
    final userid = await SharedPreferences.getInstance().then(
      (prefs) => prefs.getString('userid'),
    );
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              userid != null ? AuthWrapper() : UserDataScreen(userId: userId),
        ),
      );
      setState(() {
        log_in = false;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    // setState(() => _isLoading = true);

    authSub = supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final user = data.session?.user;
      print("Auth event: $event, user: ${user?.email}");
      if (event == AuthChangeEvent.signedIn && user != null) {
        authSub.cancel();
        if (mounted) _navigateToUserData(user.id);
      }
    });

    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb
            ? null
            : 'https://yqyjnwclewpmlpvmjnzq.supabase.co/auth/v1/callback',

        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
      Fluttertoast.showToast(msg: "Redirecting to Google...");
    } catch (e) {
      Fluttertoast.showToast(msg: "Google sign-in failed: $e");
      authSub.cancel();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_isValidEmail(_emailController.text.trim())) {
      Fluttertoast.showToast(msg: "Masukkan email yang valid");
      return;
    }

    try {
      await supabase.auth.resetPasswordForEmail(_emailController.text.trim());
      Fluttertoast.showToast(msg: "Email reset password dikirim!");
    } catch (e) {
      Fluttertoast.showToast(msg: "Gagal mengirim email reset: $e");
    }
  }

  bool log_in = false;
  @override
  void initState() {
    super.initState();
    authSub = supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      print(event);
      if (event == AuthChangeEvent.signedIn) {
        setState(() {
          _isLoading = false;
          log_in = false;
        });
        // Hentikan listener setelah login berhasil
        if (mounted) _navigateToUserData(data.session!.user.id);
        authSub.cancel();
        // Email is now confirmed and user is logged in
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (developerOptionsEnabled)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Developer options aktif. Fitur lokasi dan keamanan mungkin terpengaruh.',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 12),
                  const Icon(Icons.access_time, size: 80, color: Colors.blue),
                  const SizedBox(height: 12),
                  Text(
                    _isLogin ? "Login Absensi" : "Daftar Akun",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 25),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    icon: Image.asset('assets/google.jpg', height: 24),
                    label: const Text("Sign in with Google"),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "or",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: "Email",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Email wajib diisi";
                      }
                      if (!_isValidEmail(value)) {
                        return "Format email tidak valid";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Password",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Password wajib diisi";
                      }
                      if (value.length < 6) {
                        return "Password minimal 6 karakter";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _authenticate,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : log_in
                        ? const CircularProgressIndicator()
                        : Text(
                            _isLogin ? "LOGIN" : "DAFTAR",
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(
                      _isLogin
                          ? "Belum punya akun? Daftar"
                          : "Sudah punya akun? Login",
                    ),
                  ),
                  if (_isLogin)
                    TextButton(
                      onPressed: _resetPassword,
                      child: const Text("Lupa Password?"),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
