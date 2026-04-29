import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsScreen extends StatefulWidget {
  final SupabaseClient supabase;
  const SettingsScreen({super.key, required this.supabase});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isLoading = false;
  List<User> list = [];
  Future<List<User>> start() async {
    final supabase = SupabaseClient(
      'https://yqyjnwclewpmlpvmjnzq.supabase.co',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlxeWpud2NsZXdwbWxwdm1qbnpxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcyMTg3ODE4NywiZXhwIjoyMDM3NDU0MTg3fQ.nF7O8DV6FflLsYvU1UTjQiNqly2tQvpfehIE8cI_o2o',
    );
    final users = await supabase.auth.admin.listUsers();
    print(users.toList().toString());
    return users;
  }

  void update(String uid, DateTime date) async {
    final supabase = SupabaseClient(
      'https://yqyjnwclewpmlpvmjnzq.supabase.co',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlxeWpud2NsZXdwbWxwdm1qbnpxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcyMTg3ODE4NywiZXhwIjoyMDM3NDU0MTg3fQ.nF7O8DV6FflLsYvU1UTjQiNqly2tQvpfehIE8cI_o2o',
    );
    try {
      await supabase.auth.admin.updateUserById(
        uid,
        attributes: AdminUserAttributes(banDuration: '1200000h'),
      );
    } catch (e) {
      print(e.toString());
    }
  }

  void buka() async {
    await start().then((v) {
      setState(() {
        isLoading = true;
      });
      if (v.isNotEmpty) {
        setState(() {
          list = v;
          isLoading = false;
        });
      }
      setState(() {
        isLoading = false;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    buka();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pengaturan Aplikasi',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: list.length,
                      itemBuilder: (_, i) => Column(
                        children: [
                          InkWell(
                            onTap: () => update(list[i].id, DateTime.now()),
                            child: Text(list[i].id.toString()),
                          ),
                          Text(list[i].email.toString()),
                          Text(list[i].userMetadata?.toString() ?? ""),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
