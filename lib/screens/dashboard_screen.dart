import 'package:absen/bloc/attendance/attendance_bloc.dart';
import 'package:absen/bloc/attendance/attendance_state.dart';
import 'package:absen/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../bloc/attendance/attendance_event.dart';
import 'package:url_launcher/url_launcher.dart';

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
      body: BlocConsumer<AttendanceBloc, AttendanceState>(
        // LISTENER: Tempat memicu dialog/pop-up alasan bolos
        listenWhen: (previous, current) =>
            current.missingAttendanceDates != null &&
            current.missingAttendanceDates!.isNotEmpty,
        listener: (context, state) {
          // Ambil tanggal pertama yang terlewat untuk dimintai alasan
          final missingDate = state.missingAttendanceDates!.first;

          // Tampilkan dialog alasan
          _showMissingAttendanceDialog(context, missingDate);
        },

        // BUILDER: Tempat merender UI utama Anda (tetap seperti kode Anda sebelumnya)
        builder: (context, state) {
          final bloc = context.read<AttendanceBloc>();
          final dateFormat = DateFormat('EEEE, dd MMMM yyyy');

          if (state.isHoliday == true) {
            // Gunakan '== true' lebih aman daripada '!' jika property nullable
            return const Center(
              child: Text(
                "Hari ini hari libur. Anda tidak perlu melakukan absen.",
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }

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
                const Spacer(),
                InkWell(
                  onTap: () async {
                    await launchUrl(
                      Uri.parse(
                        'https://chat.whatsapp.com/JW6Kmc4hM0L0VGITCR1B0x',
                      ),
                    );
                  },
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 40,
                            width: 40,
                            child: IconButton(
                              iconSize: 40,
                              onPressed: () async {
                                await launchUrl(
                                  Uri.parse(
                                    'https://chat.whatsapp.com/JW6Kmc4hM0L0VGITCR1B0x',
                                  ),
                                );
                              },
                              icon: Image.asset('assets/wa.jpg'),
                            ),
                          ),
                          const Text('Gabung Group Whatsapp'),
                        ],
                      ),
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

  void _showMissingAttendanceDialog(BuildContext context, String date) {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false, // Wajib diisi, tidak bisa asal tutup
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text("⚠️ Absen Terlewat"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Anda terdeteksi tidak melakukan absensi pada tanggal:",
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 8),
              Text(
                date,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: "Masukkan Alasan Tidak Hadir",
                  hintText: "Contoh: Sakit, Izin, atau Lupa Absen",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                final reason = reasonController.text.trim();
                if (reason.isNotEmpty) {
                  // 1. Simpan alasan ke SharedPreferences (atau DB lokal Anda)
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('reason_$date', reason);

                  // 2. Tutup dialog
                  Navigator.pop(dialogContext);

                  // 3. Picu ulang event LoadAttendance untuk mengecek hari terlewat berikutnya (jika ada)
                  context.read<AttendanceBloc>().add(LoadAttendance());
                } else {
                  // Tampilkan pesan jika alasan kosong
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Alasan wajib diisi!")),
                  );
                }
              },
              child: const Text("Kirim Alasan"),
            ),
          ],
        );
      },
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
