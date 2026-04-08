import 'package:absen/bloc/attendance/attendance_state.dart';
import 'package:absen/screens/bib_screen.dart';
import 'package:absen/screens/clock_action_screen.dart';
import 'package:absen/screens/ijin_screen.dart';
import 'package:absen/screens/login_screen.dart';
import 'package:absen/screens/sakit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bloc/attendance/attendance_bloc.dart';
import 'screens/dashboard_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

late SharedPreferences pref;
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  pref = await SharedPreferences.getInstance();
  await Supabase.initialize(
    url: 'https://yqyjnwclewpmlpvmjnzq.supabase.co', // Ganti dengan URL Anda
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlxeWpud2NsZXdwbWxwdm1qbnpxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjE4NzgxODcsImV4cCI6MjAzNzQ1NDE4N30.dzkB1TgaWGk9fDZv2OhKmBsgje5xhUhNwwFXOtlStKo', // Ganti dengan anon key Anda
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Online Attendance',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = pref.getString('user') ?? '';
    final pass = pref.getString('pass') ?? "";
    if (user.isNotEmpty && pass.isNotEmpty) {
      return FutureBuilder(
        future: Supabase.instance.client.auth.signInWithPassword(
          email: user,
          password: pass,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasError || snapshot.data?.user == null) {
            return BlocProvider(
              create: (_) => AttendanceBloc(),
              child: const LoginScreen(),
            );
          } else {
            return BlocProvider(
              create: (_) => AttendanceBloc(),
              child: AttendanceHome(),
            );
          }
        },
      );
    } else {
      return const LoginScreen();
    }
  }
}

class AttendanceHome extends StatelessWidget {
  const AttendanceHome({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AttendanceBloc, AttendanceState>(
      builder: (context, state) {
        Widget currentScreen;

        switch (state.currentView) {
          case 'clock-in':
          case 'clock-out':
            currentScreen = const ClockActionScreen();
            break;
          case 'sakit':
            currentScreen = const SakitScreen();
            break;
          case 'ijin':
            currentScreen = const IjinScreen();
            break;
          case 'keluar-bib':
            currentScreen = const BibScreen();
            break;
          default:
            currentScreen = const DashboardScreen();
        }

        return Scaffold(body: SafeArea(child: currentScreen));
      },
    );
  }
}
