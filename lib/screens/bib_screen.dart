import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/attendance/attendance_bloc.dart';
import '../bloc/attendance/attendance_event.dart';

class BibScreen extends StatelessWidget {
  const BibScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AttendanceBloc>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Keluar dengan BIB"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => bloc.add(ChangeView('dashboard')),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline, size: 100, color: Colors.orange),
              const SizedBox(height: 24),
              const Text(
                "Konfirmasi BIB",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                "Anda akan melakukan absensi keluar dengan status\nBekerja di Luar Kantor (BIB)",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => bloc.add(SubmitBIB()),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
                child: const Text("KONFIRMASI KELUAR BIB", style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}