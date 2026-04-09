import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
  String? selectedDay;
  Set<String> availableDays = {};
  Map<String, Color> dateColors = {};
  String? selectedMonth;
  String? selectedName;
  List<String> availableNames = [];
  List<String> availableMonths = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    availableMonths = List.generate(
      12,
      (i) => '${now.year}-${(i + 1).toString().padLeft(2, '0')}',
    );
    selectedMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    if (selectedMonth == null) return;
    setState(() => _isLoading = true);

    final parts = selectedMonth!.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 0);

    try {
      final response = await supabase
          .from('attendance')
          .select('*, user(nama, alamatsekolah)')
          .gte('created_at', DateFormat('yyyy-MM-dd').format(startOfMonth))
          .lte('created_at', DateFormat('yyyy-MM-dd').format(endOfMonth))
          .order('created_at', ascending: false);
      print('Fetched reports: $response');
      setState(() {
        _reports = List<Map<String, dynamic>>.from(response);
        availableDays = _reports.map((r) => r['date'] as String).toSet();
        availableNames = _reports
            .map((r) => r['user']['nama'] as String)
            .toSet()
            .toList();
        final sortedDays = availableDays.toList()..sort();
        dateColors = {};
        for (int i = 0; i < sortedDays.length; i++) {
          dateColors[sortedDays[i]] = i % 2 == 0
              ? Colors.blue.shade50
              : Colors.grey[100]!;
        }
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

  Color _getRowColor(String? status, String? date) {
    if (status == 'ijin') return Colors.yellow.shade100;
    if (status == 'sakit') return Colors.red.shade100;
    return dateColors[date] ?? Colors.white;
  }

  Future<void> _generatePDF() async {
    final filteredReports = selectedName == null
        ? _reports
        : _reports.where((r) => r['user']['nama'] == selectedName).toList();

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Text(
                'Laporan Absensi Bulan $selectedMonth',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: ['Tanggal', 'Clock In', 'Clock Out', 'Note'],
                data: filteredReports
                    .map(
                      (report) => [
                        report['date'] ?? '-',
                        report['clock_in'] != null
                            ? DateFormat(
                                'HH:mm',
                              ).format(DateTime.parse(report['clock_in']))
                            : '-',
                        report['clock_out'] != null
                            ? DateFormat(
                                'HH:mm',
                              ).format(DateTime.parse(report['clock_out']))
                            : '-',
                        report['note'] ?? '-',
                      ],
                    )
                    .toList(),
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Laporan_Absensi_$selectedName-$selectedMonth.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredReports = selectedDay == null
        ? _reports
        : _reports.where((r) => r['date'] == selectedDay).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Laporan Absen Bulanan')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButton<String>(
                          value: selectedMonth,
                          hint: const Text('Pilih Bulan'),
                          items: availableMonths.map((month) {
                            return DropdownMenuItem<String>(
                              value: month,
                              child: Text(month),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedMonth = value;
                              selectedName = null;
                              selectedDay = null;
                            });
                            _fetchReports();
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButton<String>(
                          value: selectedName,
                          hint: const Text('Pilih Nama'),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('Semua'),
                            ),
                            ...availableNames.map((name) {
                              return DropdownMenuItem<String>(
                                value: name,
                                child: Text(name),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setState(() {
                              selectedName = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _generatePDF,
                        child: const Text('Generate PDF'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    spacing: 16,
                    children: [
                      Text('Filter berdasarkan tanggal : '),
                      DropdownButton<String>(
                        value: selectedDay,
                        hint: const Text('Pilih Tanggal'),
                        borderRadius: BorderRadius.circular(8),
                        dropdownColor: Colors.white,
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Semua'),
                          ),
                          ...availableDays.map((day) {
                            return DropdownMenuItem<String>(
                              value: day,
                              child: Text(day),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedDay = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
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
                      ],
                      rows: filteredReports.map((report) {
                        final profile = report['user'] as Map<String, dynamic>?;
                        return DataRow(
                          color: WidgetStatePropertyAll(
                            _getRowColor(report['status'], report['date']),
                          ),
                          cells: [
                            DataCell(Text(report['status'] ?? '-')),
                            DataCell(Text(profile?['nama'] ?? '-')),
                            DataCell(Text(profile?['alamatsekolah'] ?? '-')),
                            DataCell(Text(report['date'] ?? '-')),
                            DataCell(
                              Text(
                                report['clock_in'] != null
                                    ? DateFormat('HH:mm').format(
                                        DateTime.parse(report['clock_in']),
                                      )
                                    : '-',
                              ),
                            ),
                            DataCell(
                              Text(
                                report['clock_out'] != null
                                    ? DateFormat('HH:mm').format(
                                        DateTime.parse(report['clock_out']),
                                      )
                                    : '-',
                              ),
                            ),
                            DataCell(
                              (fileExists[report['note']] ?? false)
                                  ? IconButton(
                                      icon: const Icon(Icons.download),
                                      onPressed: () =>
                                          _downloadFile(report['note']),
                                    )
                                  : const Text('-'),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
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
