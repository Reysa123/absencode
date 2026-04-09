import 'dart:io';
import 'package:absen/bloc/attendance/attendance_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../bloc/attendance/attendance_bloc.dart';
import '../bloc/attendance/attendance_event.dart';

class SakitScreen extends StatelessWidget {
  const SakitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AttendanceBloc>();
    final picker = ImagePicker();

    return BlocBuilder<AttendanceBloc, AttendanceState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text("Upload Surat Sakit"),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => bloc.add(ChangeView('dashboard')),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () async {
                    final file = await picker.pickImage(source: ImageSource.gallery);
                    if (file != null) bloc.add(PickSickFile(file));
                  },
                  child: Container(
                    height: 240,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey, style: BorderStyle.solid),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: state.sickFile == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.upload_file, size: 80, color: Colors.blue),
                              SizedBox(height: 12),
                              Text("Pilih Surat Sakit (JPG/PNG/PDF)"),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(File(state.sickFile!.path), fit: BoxFit.cover),
                          ),
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: state.sickFile == null || state.isLoading
                      ? null
                      : () => bloc.add(UploadSickNote()),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
                  child: state.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("KIRIM SURAT SAKIT", style: TextStyle(fontSize: 18,color: Colors.black)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}