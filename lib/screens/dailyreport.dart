import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class DailyReportScreen extends StatefulWidget {
  const DailyReportScreen({super.key});

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;
  Map<String, bool> fileExists = {};

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    try {
      final response = await supabase
          .from('attendance')
          .select('*, profiles(name, school)')
          .gte('date', DateFormat('yyyy-MM-dd').format(startOfMonth))
          .lte('date', DateFormat('yyyy-MM-dd').format(endOfMonth))
          .order('date', ascending: true);

      setState(() {
        _reports = List<Map<String, dynamic>>.from(response);
      });

      // Check file existence for each report with note
      List<Future> checks = [];
      for (var report in _reports) {
        if (report['note'] != null && report['note'].toString().isNotEmpty) {
          checks.add(
            _checkFileExists(report['note']).then((exists) {
              fileExists[report['note']] = exists;
            }),
          );
        }
      }
      await Future.wait(checks);
      setState(() => _isLoading = false);
    } catch (e) {
      print('Error fetching reports: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _checkFileExists(String fileName) async {
    try {
      // fileName is full path like 'userId/type_date_timestamp.ext'
      final parts = fileName.split('/');
      if (parts.length < 2) return false;
      final folder = parts[0];
      final file = parts.sublist(1).join('/');
      final files = await supabase.storage.from('absen').list(path: folder);
      return files.any((f) => f.name == file);
    } catch (e) {
      print('Error checking file existence: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan Harian Bulanan')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Absen')),
                  DataColumn(label: Text('Nama')),
                  DataColumn(label: Text('Sekolah')),
                  DataColumn(label: Text('Tanggal')),
                  DataColumn(label: Text('Clock In')),
                  DataColumn(label: Text('Clock Out')),
                  DataColumn(label: Text('Note')),
                  DataColumn(label: Text('File Upload')),
                ],
                rows: _reports.map((report) {
                  final profile = report['profiles'] as Map<String, dynamic>?;
                  return DataRow(
                    cells: [
                      DataCell(Text(report['status'] ?? '-')),
                      DataCell(Text(profile?['name'] ?? '-')),
                      DataCell(Text(profile?['school'] ?? '-')),
                      DataCell(Text(report['date'] ?? '-')),
                      DataCell(
                        Text(
                          report['clock_in'] != null
                              ? DateFormat(
                                  'HH:mm',
                                ).format(DateTime.parse(report['clock_in']))
                              : '-',
                        ),
                      ),
                      DataCell(
                        Text(
                          report['clock_out'] != null
                              ? DateFormat(
                                  'HH:mm',
                                ).format(DateTime.parse(report['clock_out']))
                              : '-',
                        ),
                      ),
                      DataCell(
                        (fileExists[report['note']] ?? false)
                            ? IconButton(
                                icon: const Icon(Icons.download),
                                onPressed: () => _downloadFile(report['note']),
                              )
                            : const Text('-'),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }

  Future<void> _downloadFile(String filePath) async {
    try {
      final url = supabase.storage.from('absen').getPublicUrl(filePath);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ImageViewScreen(imageUrl: url)),
      );
    } catch (e) {
      print('Error downloading file: $e');
    }
  }
}

class ImageViewScreen extends StatelessWidget {
  final String imageUrl;

  const ImageViewScreen({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('View Image')),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: Image.network(
            imageUrl,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
            errorBuilder: (context, error, stackTrace) {
              return const Center(child: Text('Error loading image'));
            },
          ),
        ),
      ),
    );
  }
}
