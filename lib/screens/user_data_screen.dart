import 'package:absen/main.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';

class UserDataScreen extends StatefulWidget {
  final String userId;
  const UserDataScreen({super.key, required this.userId});

  @override
  State<UserDataScreen> createState() => _UserDataScreenState();
}

class _UserDataScreenState extends State<UserDataScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _alamatController = TextEditingController();
  final _startController = TextEditingController();
  final _endController = TextEditingController();
  final _start2Controller = TextEditingController();
  final _end2Controller = TextEditingController();

  final supabase = Supabase.instance.client;
  bool _isLoading = false;
  bool isData = false;
  
  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day $month ${date.year}';
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selectedDate != null) {
      controller.text = _formatDate(selectedDate);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      isData = false;
    });

    final response = await supabase
        .from('user')
        .select()
        .eq('userid', widget.userId)
        .maybeSingle();

    if (response != null) {
      final data = response;
      _namaController.text = data['nama'] ?? '';
      _alamatController.text = data['alamatsekolah'] ?? '';
      _startController.text = data['start1'] ?? '';
      _endController.text = data['end1'] ?? '';
      _start2Controller.text = data['start2'] ?? '';
      _end2Controller.text = data['end2'] ?? '';
      if (mounted) setState(() => isData = true);
    }
    await SharedPreferences.getInstance().then((prefs) {
      prefs.setString('userid', widget.userId);
    });
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveUserData() async {
    if (isData) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
        );
      }
    } else {
      if (!_formKey.currentState!.validate()) return;

      setState(() => _isLoading = true);

      try {
        await supabase.from('user').insert({
          'userid': widget.userId.toString(),
          'nama': _namaController.text.trim(),
          'alamatsekolah': _alamatController.text.trim(),
          'start1': _startController.text.trim(),
          'end1': _endController.text.trim(),
          'start2': _start2Controller.text.trim(),
          'end2': _end2Controller.text.trim(),
        });

        Fluttertoast.showToast(
          msg: "Data tersimpan",
          toastLength: Toast.LENGTH_LONG,
        );

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AuthWrapper()),
          );
        }
      } catch (e) {
        Fluttertoast.showToast(
          msg: "Gagal menyimpan data: $e",
          toastLength: Toast.LENGTH_LONG,
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Lengkapi Data")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: widget.userId,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: "ID User",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _namaController,
                  decoration: const InputDecoration(
                    labelText: "Nama",
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? "Nama wajib diisi"
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _alamatController,
                  decoration: const InputDecoration(
                    labelText: "Alamat Sekolah",
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? "Alamat sekolah wajib diisi"
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _startController,
                  onTap: () => _pickDate(_startController),
                  decoration: const InputDecoration(
                    labelText: "Start 1",
                    hintText: "dd mm yyyy",
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? "Start 1 wajib diisi"
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _endController,
                  onTap: () => _pickDate(_endController),
                  decoration: const InputDecoration(
                    labelText: "End 1",
                    hintText: "dd mm yyyy",

                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? "End 1 wajib diisi"
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _start2Controller,
                  onTap: () => _pickDate(_start2Controller),
                  decoration: const InputDecoration(
                    labelText: "Start 2",
                    hintText: "dd mm yyyy",
                    border: OutlineInputBorder(),
                  ),
                  // validator: (value) => value == null || value.isEmpty
                  //     ? "Start 2 wajib diisi"
                  //     : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _end2Controller,
                  onTap: () => _pickDate(_end2Controller),
                  decoration: const InputDecoration(
                    labelText: "End 2",
                    hintText: "dd mm yyyy",
                    border: OutlineInputBorder(),
                  ),
                  // validator: (value) => value == null || value.isEmpty
                  //     ? "End 2 wajib diisi"
                  //     : null,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveUserData,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Simpan Data"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _namaController.dispose();
    _alamatController.dispose();
    _startController.dispose();
    _endController.dispose();
    _start2Controller.dispose();
    _end2Controller.dispose();
    super.dispose();
  }
}
