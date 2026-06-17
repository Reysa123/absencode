import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'attendance_event.dart';
import 'attendance_state.dart';
import 'package:holiday_id/holiday_id.dart';
import 'package:collection/collection.dart'; // Dibutuhkan untuk .firstOrNull

class AttendanceBloc extends Bloc<AttendanceEvent, AttendanceState> {
  Timer? _clockTimer;
  Timer? _locationTimer;
  final supabase = Supabase.instance.client;
  final double officeLat = -8.641514;
  final double officeLng = 115.209754;
  final double radiusMeters = 100.0;

  AttendanceBloc() : super(AttendanceState(currentTime: DateTime.now())) {
    on<LoadAttendance>(_onLoadAttendance);
    on<UpdateLocation>(_onUpdateLocation);
    on<StartLocationUpdates>(_onStartLocationUpdates);
    on<StopLocationUpdates>(_onStopLocationUpdates);
    on<ChangeView>(_onChangeView);
    on<ClockIn>(_onClockIn);
    on<ClockOut>(_onClockOut);
    on<PickSickFile>(_onPickSickFile);
    on<ClearSickFile>(_onClearSickFile);
    on<SubmitIjin>(_onSubmitIjin);
    on<SubmitBIB>(_onSubmitBIB);
    on<UploadSickNote>(_onUploadSickNote);
    on<UpdateTime>(_onUpdateTime);
    on<UpdateReason>(_onUpdateReason);
    _startClock();
    add(LoadAttendance());
  }

  void _startClock() {
    DateTime lastEmittedTime = state.currentTime;
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      if (now.minute != lastEmittedTime.minute) {
        lastEmittedTime = now;
        add(UpdateTime(now));
      }
    });
  }

  void _onUpdateTime(UpdateTime event, Emitter<AttendanceState> emit) {
    emit(state.copyWith(currentTime: event.time));
  }

  Future<void> _onLoadAttendance(
    LoadAttendance event,
    Emitter<AttendanceState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = supabase.auth.currentUser;
      if (user == null) {
        emit(state.copyWith(isLoading: false));
        return;
      }

      List<String> missingDates = [];
      List<String> holidayNama = [];
      final formatter = DateFormat('yyyy-MM-dd');
      final now = DateTime.now();

      var holidaysInyear = HolidayId().getHolidays(
        filterType: HolidayType.holiday,
        filterYear: now.year,
      );

      final todayHoliday = holidaysInyear.firstWhereOrNull(
        (v) => formatter.format(v.date) == formatter.format(now),
      );
      bool isTodayHoliday =
          now.weekday == DateTime.sunday ||
          (todayHoliday?.type == HolidayType.holiday);

      // 1. OPTIMASI: Ambil data user satu kali saja
      final userData = await supabase
          .from('user')
          .select('start1')
          .eq('userid', user.id)
          .maybeSingle();
      DateTime? tglStart;
      if (userData != null && userData['start1'] != null) {
        final startuser = userData['start1'].toString();
        final parts = startuser.split(" ");
        if (parts.length >= 3) {
          tglStart = DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        }
      }

      // 2. OPTIMASI: Ambil data absen 7 hari ke belakang sekaligus (mengurangi request internet)
      final sevenDaysAgoStr = formatter.format(
        now.subtract(const Duration(days: 7)),
      );
      final yesterdayStr = formatter.format(
        now.subtract(const Duration(days: 1)),
      );

      final attendanceRecords = await supabase
          .from('attendance')
          .select('date, clock_in, clock_out, note')
          .eq('userid', user.id)
          .gte('date', sevenDaysAgoStr)
          .lte('date', yesterdayStr);

      // Loop untuk mengecek 7 hari ke belakang
      for (int i = 1; i <= 7; i++) {
        final checkDate = now.subtract(Duration(days: i));
        final checkDateStr = formatter.format(checkDate);

        final d = holidaysInyear.firstWhereOrNull(
          (v) => formatter.format(v.date) == checkDateStr,
        );

        if (checkDate.weekday == DateTime.sunday ||
            (d != null && d.type == HolidayType.holiday)) {
          holidayNama.add(d?.name.isEmpty ?? true ? "Minggu" : d!.name);
          continue;
        }
        print(
          'hari yg dicek :$checkDate dan tgl start : $tglStart  ${tglStart?.isAfter(checkDate)}',
        );
        if (tglStart != null && tglStart.isAfter(checkDate)) {
          continue;
        }

        // Cari record dari data yang sudah di-fetch di awal
        final record = attendanceRecords.firstWhereOrNull(
          (r) => r['date'] == checkDateStr,
        );

        final savedClockIn = record?['clock_in'];
        final savedClockOut = record?['clock_out'];
        final hasReason = record?['note'] != null;

        if ((savedClockIn == null && !hasReason) ||
            (savedClockOut == null && !hasReason)) {
          missingDates.add(checkDateStr);
        }
      }
      missingDates.sort((a, b) => a.compareTo(b));
      final todayStr = formatter.format(now);
      final clockIn = prefs.getString('clockIn_$todayStr');
      final clockOut = prefs.getString('clockOut_$todayStr');

      emit(
        state.copyWith(
          clockInTime: clockIn,
          clockOutTime: clockOut,
          isHoliday: isTodayHoliday,
          missingAttendanceDates: missingDates,
          isLoading: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false));
      Fluttertoast.showToast(msg: "Gagal memuat data absensi: $e");
    }
  }

  Future<void> _saveAttendance() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (state.clockInTime != null) {
      await prefs.setString('clockIn_$today', state.clockInTime!);
    }
    if (state.clockOutTime != null) {
      await prefs.setString('clockOut_$today', state.clockOutTime!);
    }
  }

  Future<void> _onUpdateReason(
    UpdateReason event,
    Emitter<AttendanceState> emit,
  ) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final q = await supabase
          .from('attendance')
          .update({'note': event.note})
          .eq('date', event.date)
          .eq('userid', user.id)
          .select();

      if (q.isEmpty) {
        await supabase.from('attendance').insert({
          'userid': user.id,
          'date': event.date,
          'clock_in': state.clockInTime ?? "null",
          'clock_out': state.clockOutTime ?? "null",
          'status': state.clockInTime ?? "",
          'latitude': null,
          'longitude': null,
          'distance_meters': "",
          'note': event.note,
          'radin': true,
          'radout': true,
        });
      }
      add(LoadAttendance());
    } catch (e) {
      Fluttertoast.showToast(msg: "Gagal menyimpan ke server: $e");
    }
  }

  Future<int> _insertAttendanceToSupabase({
    required String status,
    int? attendanceId,
    String? note,
    double? lat,
    double? lng,
    double? distance,
    bool? radin,
    bool? radout,
  }) async {
    List<Map<String, dynamic>> result = [];
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("User belum login");

      final now = DateTime.now();
      if (attendanceId != null && attendanceId != 0) {
        await supabase
            .from('attendance')
            .update({
              'clock_out': now.toIso8601String(),
              'status': 'hadir',
              'latitude': lat?.toString(),
              'longitude': lng?.toString(),
              'distance_meters': distance?.toString(),
              'radin': radin ?? true,
              'radout': radout ?? true,
            })
            .eq('id', attendanceId);
        return attendanceId;
      }

      result = await supabase.from('attendance').insert({
        'userid': user.id,
        'date': DateFormat('yyyy-MM-dd').format(now),
        'clock_in': status == 'clock-in' ? now.toIso8601String() : null,
        'clock_out': status == 'clock-out' ? now.toIso8601String() : null,
        'status': status == 'clock-in' || status == 'clock-out'
            ? 'hadir'
            : status,
        'latitude': lat?.toString(),
        'longitude': lng?.toString(),
        'distance_meters': distance?.toString(),
        'note': note,
        'radin': radin ?? true,
        'radout': radout ?? true,
      }).select();

      Fluttertoast.showToast(msg: "Data berhasil disimpan ke Supabase");
    } catch (e) {
      Fluttertoast.showToast(msg: "Gagal menyimpan ke server: $e");
    }
    return result.isNotEmpty ? (result.first['id'] as int) : 0;
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371e3; // metres
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final deltaPhi = (lat2 - lat1) * math.pi / 180;
    final deltaLambda = (lon2 - lon1) * math.pi / 180;

    final a =
        math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
        math.cos(phi1) *
            math.cos(phi2) *
            math.sin(deltaLambda / 2) *
            math.sin(deltaLambda / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  Future<void> _onUpdateLocation(
    UpdateLocation event,
    Emitter<AttendanceState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Fluttertoast.showToast(msg: "Layanan lokasi dinonaktifkan");
        emit(state.copyWith(isLoading: false));
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Fluttertoast.showToast(msg: "Izin lokasi ditolak");
          emit(state.copyWith(isLoading: false));
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        Fluttertoast.showToast(msg: "Izin lokasi ditolak permanen");
        emit(state.copyWith(isLoading: false));
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final dist = _calculateDistance(
        pos.latitude,
        pos.longitude,
        officeLat,
        officeLng,
      );
      final withinRadius = dist <= radiusMeters;

      emit(
        state.copyWith(
          position: pos,
          distance: dist,
          isMockDetected: false,
          isWithinRadius: withinRadius,
          isLoading: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false));
      Fluttertoast.showToast(msg: "Gagal mendapatkan lokasi: $e");
    }
  }

  void _onStartLocationUpdates(
    StartLocationUpdates event,
    Emitter<AttendanceState> emit,
  ) {
    _locationTimer?.cancel();
    add(UpdateLocation());
    _locationTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => add(UpdateLocation()),
    );
    emit(state.copyWith(isLoading: true));
  }

  void _onStopLocationUpdates(
    StopLocationUpdates event,
    Emitter<AttendanceState> emit,
  ) {
    _locationTimer?.cancel();
    emit(state.copyWith(isLoading: false));
  }

  void _onChangeView(ChangeView event, Emitter<AttendanceState> emit) {
    emit(state.copyWith(currentView: event.view));
  }

  Future<void> _onClockIn(ClockIn event, Emitter<AttendanceState> emit) async {
    if (state.isMockDetected || !state.isWithinRadius) {
      final pref = await SharedPreferences.getInstance();
      await pref.setInt('keluar', 2);
      Fluttertoast.showToast(msg: "Anda di luar radius kantor!");
      return;
    }
    final pref = await SharedPreferences.getInstance();
    await pref.setInt('keluar', 0);

    final timeStr = DateFormat('HH:mm').format(state.currentTime);
    emit(state.copyWith(clockInTime: timeStr));
    await _saveAttendance();

    int a = await _insertAttendanceToSupabase(
      status: 'clock-in',
      lat: state.position?.latitude,
      lng: state.position?.longitude,
      distance: state.distance,
    );

    await pref.setInt('attendanceId', a);
    Fluttertoast.showToast(msg: "Clock In berhasil!");
    add(ChangeView('dashboard'));
  }

  Future<void> _onClockOut(
    ClockOut event,
    Emitter<AttendanceState> emit,
  ) async {
    if (state.isMockDetected || !state.isWithinRadius) {
      final pref = await SharedPreferences.getInstance();
      await pref.setInt('keluar', 1);
      Fluttertoast.showToast(msg: "Anda di luar radius kantor!");
      return;
    }
    final pref = await SharedPreferences.getInstance();
    await pref.setInt('keluar', 0);

    final attendanceId = pref.getInt('attendanceId') ?? 0;
    final timeStr = DateFormat('HH:mm').format(state.currentTime);
    emit(state.copyWith(clockOutTime: timeStr));
    await _saveAttendance();

    await _insertAttendanceToSupabase(
      attendanceId: attendanceId,
      status: 'clock-out',
      lat: state.position?.latitude,
      lng: state.position?.longitude,
      distance: state.distance,
    );
    Fluttertoast.showToast(msg: "Clock Out berhasil!");
    add(ChangeView('dashboard'));
  }

  void _onPickSickFile(PickSickFile event, Emitter<AttendanceState> emit) {
    emit(state.copyWith(sickFile: event.file));
  }

  void _onClearSickFile(ClearSickFile event, Emitter<AttendanceState> emit) {
    emit(state.copyWith(sickFile: null));
  }

  Future<void> _onSubmitIjin(
    SubmitIjin event,
    Emitter<AttendanceState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("User belum login");

      final pref = await SharedPreferences.getInstance();
      final keluar = pref.getInt('keluar') ?? 0;
      final now = DateTime.now();

      //final success = await _uploadToServer("ijin", reason: event.reason);

      if (keluar != 0) {
        final attendanceId = pref.getInt('attendanceId') ?? 0;
        final timeStr = DateFormat('HH:mm').format(state.currentTime);

        keluar == 1
            ? emit(state.copyWith(clockOutTime: timeStr))
            : emit(state.copyWith(clockInTime: timeStr));

        await _saveAttendance();
        await _insertAttendanceToSupabase(
          attendanceId: attendanceId,
          status: keluar == 1 ? 'clock-out' : 'clock-in',
          lat: state.position?.latitude,
          lng: state.position?.longitude,
          distance: state.distance,
          note: event.reason,
          radin: keluar == 2 ? false : true,
          radout: keluar == 1 ? false : true,
        );
        await pref.setInt('keluar', 0);
      }

      final success = await supabase.from('attendance').insert({
        'userid': user.id,
        'date': DateFormat('yyyy-MM-dd').format(now),
        'status': 'ijin',
        'note': event.reason,
        'clock_in': now.toIso8601String(),
        'clock_out': now.toIso8601String(),
        'latitude': state.position?.latitude.toString(),
        'longitude': state.position?.longitude.toString(),
        'distance_meters': state.distance.toString(),
      });

      final timeStr = DateFormat('HH:mm').format(state.currentTime);
      emit(
        state.copyWith(
          clockInTime: timeStr,
          clockOutTime: timeStr,
          isLoading: false,
        ),
      );
      await _saveAttendance();

      if (success) {
        Fluttertoast.showToast(msg: "Permohonan ijin berhasil dikirim!");
        emit(state.copyWith(ijinReason: '', currentView: 'dashboard'));
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false));
      Fluttertoast.showToast(msg: "Gagal submit izin: $e");
    }
  }

  Future<void> _onSubmitBIB(
    SubmitBIB event,
    Emitter<AttendanceState> emit,
  ) async {
    Fluttertoast.showToast(msg: "Absensi BIB berhasil!");
    add(ChangeView('dashboard'));
  }

  Future<void> _onUploadSickNote(
    UploadSickNote event,
    Emitter<AttendanceState> emit,
  ) async {
    if (state.sickFile == null) return;
    emit(state.copyWith(isLoading: true));

    final success = await _uploadToServer("sakit", file: state.sickFile);

    final timeStr = DateFormat('HH:mm').format(state.currentTime);
    emit(
      state.copyWith(
        clockInTime: timeStr,
        clockOutTime: timeStr,
        isLoading: false,
      ),
    );
    await _saveAttendance();

    if (success) {
      Fluttertoast.showToast(msg: "Surat sakit berhasil dikirim!");
      add(ClearSickFile());
      add(ChangeView('dashboard'));
    }
  }

  Future<bool> _uploadToServer(
    String type, {
    XFile? file,
    String? reason,
  }) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("User belum login");

      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);

      String? noteValue = reason;

      if (file != null) {
        final fileName =
            '${user.id}/${type}_${dateStr}_${now.millisecondsSinceEpoch}.${file.name.split('.').last}';
        final fileBytes = await file.readAsBytes();
        await supabase.storage
            .from('absen')
            .uploadBinary(
              fileName,
              fileBytes,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: false,
              ),
            );
        noteValue = fileName;
      }

      await supabase.from('attendance').insert({
        'userid': user.id,
        'date': dateStr,
        'status': type,
        'note': noteValue,
        'clock_in': now.toIso8601String(),
        'clock_out': now.toIso8601String(),
        'latitude': state.position?.latitude.toString(),
        'longitude': state.position?.longitude.toString(),
        'distance_meters': state.distance.toString(),
      });

      return true;
    } catch (e) {
      Fluttertoast.showToast(msg: "Gagal upload: $e");
      return false;
    }
  }

  @override
  Future<void> close() {
    _clockTimer?.cancel();
    _locationTimer?.cancel();
    return super.close();
  }
}
