import 'package:absen/bloc/attendance/attendance_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/attendance/attendance_bloc.dart';
import '../bloc/attendance/attendance_event.dart';

class IjinScreen extends StatelessWidget {
  const IjinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AttendanceBloc>();

    return BlocBuilder<AttendanceBloc, AttendanceState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text("Ijin Absensi"),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => bloc.add(ChangeView('dashboard')),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                TextField(
                  maxLines: 7,
                  decoration: const InputDecoration(
                    labelText: "Alasan Ijin",
                    border: OutlineInputBorder(),
                    hintText: "Tuliskan alasan ijin Anda...",
                  ),
                  onChanged: (value) {
                    // Untuk simplicity, kita simpan di state
                    // Bisa di-improve dengan TextEditingController
                  },
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: state.ijinReason.trim().isEmpty || state.isLoading
                      ? null
                      : () => bloc.add(SubmitIjin(state.ijinReason)),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
                  child: state.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("KIRIM PERMOHONAN IJIN", style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}