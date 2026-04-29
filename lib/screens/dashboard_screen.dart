import 'package:absen/bloc/attendance/attendance_bloc.dart';
import 'package:absen/bloc/attendance/attendance_state.dart';
import 'package:absen/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../bloc/attendance/attendance_event.dart';
import 'package:http/http.dart' as http;

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard Absensi"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Konfirmasi Logout'),
                    content: const Text('Apakah Anda yakin ingin logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.clear();
                          //await Supabase.instance.client.auth.signOut();

                          if (context.mounted) {
                            Navigator.of(context).pop();
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AuthWrapper(),
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'Logout',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  );
                },
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
                Spacer(),
                Card(
                  child: Column(
                    children: [
                      IconButton(
                        onPressed: () async {
                          await http.get(
                            Uri.parse(
                              'https://chat.whatsapp.com/JW6Kmc4hM0L0VGITCR1B0x',
                            ),
                          );
                        },
                        icon: Image.asset('assets/images/wa.jpg'),
                      ),
                      Text('Gabung Group Whatsapp'),
                    ],
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
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
