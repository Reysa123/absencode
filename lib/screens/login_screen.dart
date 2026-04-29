import 'dart:async';

import 'package:absen/main.dart';
import 'package:absen/screens/user_data_screen.dart';
import 'package:absen/screens/verifikasiotpscreen.dart';
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
    final pref = await SharedPreferences.getInstance();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      logins = true;
    });

    try {
      if (_isLogin) {
        print('login');
        final response = await supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        final user = response.user;
        if (user != null) {
          await pref.setString('user', _emailController.text.trim());
          await pref.setString('pass', _passwordController.text.trim());

          Fluttertoast.showToast(
            msg: "Login berhasil!",
            toastLength: Toast.LENGTH_LONG,
          );
          if (mounted) _navigateToUserData(user.id);
          setState(() {
            _isLoading = false;
            logins = false;
          });
        }
      } else {
        print('daftar');
        setState(() {
          _isLoading = true;
        });
        final AuthResponse authResponse = await supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),

          // shouldCreateUser: true,   // otomatis buat user jika belum ada (default true)
          // emailRedirectTo: 'io.supabase.flutter://login-callback', // opsional untuk deep link
        );
        final Session? session = authResponse.session;
        if (session != null) {
          await pref.setString('user', _emailController.text.trim());
          await pref.setString('pass', _passwordController.text.trim());
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Akun berhasil dibuat!')),
            );

            // Pindah ke halaman verifikasi OTP
            _navigateToUserData(authResponse.user!.id);
          }
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        logins = false;
      });
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Error"),
          content: e.toString().contains('invalid_credentials')
              ? Text(
                  "Gagal ${_isLogin ? 'login' : 'daftar'}\nPastikan email dan password benar, dan periksa koneksi internet.\nAtau Daftar Akun Baru jika belum punya akun.",
                )
              : Text(
                  "Gagal ${_isLogin ? 'login' : 'daftar'} user sudah terdaftar\nError: $e",
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
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
        logins = false;
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

  bool logins = false;
  void starting() async {
    final pref = await SharedPreferences.getInstance();
    final users = pref.getString('user') ?? '';
    final pass = pref.getString('pass') ?? "";
    if (users.isNotEmpty && pass.isNotEmpty) {
      setState(() {
        _emailController.text = users;
        _passwordController.text = pass;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    starting();
  }

  Future<void> start() async {
    authSub = supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final session = data.session;

      print(session?.user.emailConfirmedAt);
      if (event == AuthChangeEvent.signedIn) {
        setState(() {
          _isLoading = false;
          logins = false;
        });
        // Hentikan listener setelah login berhasil
        if (mounted) _navigateToUserData(data.session!.user.id);
        //authSub.cancel();
        // Email is now confirmed and user is logged in
      }
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Info"),
          content: Text(
            "Link email dikirim! Silakan periksa email Anda untuk konfirmasi.\nJika sudah dikonfirmasi, klik OK untuk melanjutkan.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  authSub.cancel();
                  _isLoading = false;
                  _isLogin = true;
                });
                if (session != null) {
                  Navigator.pop(context);
                  if (mounted) _navigateToUserData(session.user.id);
                } else {
                  if (mounted) _navigateToUserData("");
                }
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
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
                    onPressed: null,
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
                    textInputAction: TextInputAction.next,
                    controller: _emailController,
                    autofocus: true,
                    keyboardType: TextInputType.emailAddress,
                    onFieldSubmitted: (_) => FocusScope.of(
                      context,
                    ).nextFocus(), // Pindah ke password
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
                    onFieldSubmitted: (value) => _authenticate(),
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
                    style: _isLogin
                        ? ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                            backgroundColor: Colors.blue[700],
                            foregroundColor: Colors.white,
                          )
                        : ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white,
                          ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : logins
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
