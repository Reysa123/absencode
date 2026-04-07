import 'package:absen/bloc/attendance/attendance_bloc.dart';
import 'package:absen/bloc/attendance/attendance_state.dart';
import 'package:absen/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../bloc/attendance/attendance_event.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard Absensi"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<AttendanceBloc, AttendanceState>(
        builder: (context, state) {
          final bloc = context.read<AttendanceBloc>();
          final dateFormat = DateFormat('EEEE, dd MMMM yyyy');

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Jam Besar
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Text(
                          DateFormat('HH:mm').format(state.currentTime),
                          style: const TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        Text(
                          dateFormat.format(state.currentTime),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Status Clock In & Out
                Row(
                  children: [
                    Expanded(
                      child: _statusCard(
                        "Clock In",
                        state.clockInTime ?? "--:--",
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statusCard(
                        "Clock Out",
                        state.clockOutTime ?? "--:--",
                      ),
                    ),
                  ],
                ),
                const Spacer(),

                // Tombol Utama
                if (state.clockInTime == null)
                  _actionButton(
                    "Clock In",
                    () => bloc.add(ChangeView('clock-in')),
                  )
                else if (state.clockOutTime == null)
                  _actionButton(
                    "Clock Out",
                    () => bloc.add(ChangeView('clock-out')),
                  )
                else
                  const Card(
                    color: Colors.green,
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        "✅ Anda telah menyelesaikan absensi hari ini",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statusCard(String label, String time) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              time,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(String text, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 60),
        backgroundColor: Colors.blue[700],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }
}
