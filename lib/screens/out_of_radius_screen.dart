import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/attendance/attendance_bloc.dart';
import '../bloc/attendance/attendance_event.dart';

class OutOfRadiusScreen extends StatelessWidget {
  const OutOfRadiusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AttendanceBloc>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilihan Absensi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => bloc.add(ChangeView('dashboard')),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Anda berada di luar radius kantor. Pilih jenis absensi:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => bloc.add(ChangeView('ijin')),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 60),
                backgroundColor: Colors.orange,
              ),
              child: const Text(
                'IJIN',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => bloc.add(ChangeView('sakit')),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 60),
                backgroundColor: Colors.red,
              ),
              child: const Text(
                'SAKIT',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}