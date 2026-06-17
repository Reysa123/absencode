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
        // 1. PERBAIKAN LISTENWHEN: Deteksi jika list tanggal absen kosong berubah menjadi ada,
        // atau jika isinya berbeda (untuk menangani antrean tanggal berikutnya)
        listenWhen: (previous, current) {
          if (current.missingAttendanceDates == null ||
              current.missingAttendanceDates!.isEmpty) {
            return false;
          }
          if (previous.missingAttendanceDates == null ||
              previous.missingAttendanceDates!.isEmpty) {
            return true;
          }
          // Jika tanggal pertama berbeda dari sebelumnya (artinya pindah ke antrean hari berikutnya)
          return previous.missingAttendanceDates!.first !=
              current.missingAttendanceDates!.first;
        },
        listener: (context, state) {
          // Ambil tanggal pertama yang terlewat untuk dimintai alasan
          final missingDate = state.missingAttendanceDates!.first;

          // Tampilkan dialog alasan
          _showMissingAttendanceDialog(context, missingDate);
        },
        builder: (context, state) {
          final bloc = context.read<AttendanceBloc>();
          final dateFormat = DateFormat('EEEE, dd MMMM yyyy');

          if (state.isHoliday == true) {
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
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
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
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text(" Absen Terlewat"),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow,
                foregroundColor: Colors.black,
                elevation: 5,
              ),
              onPressed: () async {
                final reason = reasonController.text.trim();
                if (reason.isNotEmpty) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('reason_$date', reason);

                  // 2. PERBAIKAN ALUR: Ambil context BLoC sebelum dialog ditutup (pop)
                  // agar terhindar dari ketidakstabilan context pasca-pop.
                  final attendanceBloc = BlocProvider.of<AttendanceBloc>(
                    context,
                  );

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }

                  // Kirim alasan. Ingat, di dalam BLoC _onUpdateReason sudah ada pemicu `add(LoadAttendance())`.
                  // Jadi di sini kita CUKUP memanggil UpdateReason saja agar tidak bentrok.
                  attendanceBloc.add(UpdateReason(reason, date, 0));
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Alasan wajib diisi!"),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
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
