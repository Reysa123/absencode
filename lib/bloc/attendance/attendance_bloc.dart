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
    _startClock();
    add(LoadAttendance());
  }

  void _startClock() {
    DateTime lastEmittedTime = state.currentTime;
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      // Only emit if the minute has changed (to avoid unnecessary rebuilds)
      if (now.minute != lastEmittedTime.minute) {
        lastEmittedTime = now;
        add(UpdateTime(now)); // Dispatch event instead of emitting directly
      }
    });
  }

  // Add this new event handler
  void _onUpdateTime(UpdateTime event, Emitter<AttendanceState> emit) {
    emit(state.copyWith(currentTime: event.time));
  }

  Future<void> _onLoadAttendance(
    LoadAttendance event,
    Emitter<AttendanceState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final clockIn = prefs.getString('clockIn_$today');
    final clockOut = prefs.getString('clockOut_$today');

    emit(state.copyWith(clockInTime: clockIn, clockOutTime: clockOut));
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

  Future<int> _insertAttendanceToSupabase({
    required String status,
    int? attendanceId,
    String? note,
    double? lat,
    double? lng,
    double? distance,
  }) async {
    List<Map<String, dynamic>> id = [];
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("User belum login");

      final now = DateTime.now();
      if (attendanceId != null) {
        print(attendanceId);
        await supabase
            .from('attendance')
            .update({
              'clock_out': now.toIso8601String(),
              'status': 'hadir',
              'latitude': lat.toString(),
              'longitude': lng.toString(),
              'distance_meters': distance.toString(),
            })
            .eq('id', attendanceId);
        return attendanceId;
      }
      id = await supabase.from('attendance').insert({
        'userid': user.id.toString(),
        'date': DateFormat('yyyy-MM-dd').format(now),
        'clock_in': status == 'clock-in' ? now.toIso8601String() : null,
        'clock_out': status == 'clock-out' ? now.toIso8601String() : null,
        'status': status == 'clock-in' || status == 'clock-out'
            ? 'hadir'
            : status,

        'latitude': lat.toString(),
        'longitude': lng.toString(),
        'distance_meters': distance.toString(),
        'note': note,
      }).select();

      Fluttertoast.showToast(msg: "Data berhasil disimpan ke Supabase");
    } catch (e) {
      Fluttertoast.showToast(msg: "Gagal menyimpan ke server: $e");
      print(e.toString());
    }
    return id.isNotEmpty ? id.first['id'] : 0;
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371e3;
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
    emit(state.copyWith(isLoading: true, isWithinRadius: true));

    try {
      print('awal');
      bool serviceEnabled;
      LocationPermission permission;
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print('serviceEnabled: $serviceEnabled');
      if (!serviceEnabled) {
        // Location services are not enabled don't continue
        // accessing the position and request users of the
        // App to enable the location services.
        Fluttertoast.showToast(
          msg: "Location services are disabled",
          timeInSecForIosWeb: 2,
        );
        return Future.error('Location services are disabled.');
      }
      permission = await Geolocator.checkPermission();
      print('permission: $permission');
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // Permissions are denied, next time you could try
          // requesting permissions again (this is also where
          // Android's shouldShowRequestPermissionRationale
          // returned true. According to Android guidelines
          // your App should show an explanatory UI now.
          Fluttertoast.showToast(
            msg: "Location permissions are denied",
            timeInSecForIosWeb: 2,
          );
          return Future.error('Location permissions are denied');
        }
        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          // Permission granted, continue with location updates
          Fluttertoast.showToast(
            msg: "Location permissions are successfully granted",
            timeInSecForIosWeb: 2,
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Permissions are denied forever, handle appropriately.
        Fluttertoast.showToast(
          msg: "Location permissions are permanently denied",
          timeInSecForIosWeb: 2,
        );
        return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.',
        );
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: WebSettings(
          accuracy: LocationAccuracy.high,
          maximumAge: Duration(minutes: 5),
        ),
      );
      // print(pos.isMocked);
      // print(pos.longitude);
      //final isMock = await TrustLocation.isMockLocation;
      final dist = _calculateDistance(
        pos.latitude,
        pos.longitude,
        officeLat,
        officeLng,
      );
      // print('Distance to office: $dist meters');
      // print('isMock: $isMock');
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
      Fluttertoast.showToast(msg: "Gagal mendapatkan lokasi");
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
    if (state.isMockDetected || !state.isWithinRadius) return;

    final timeStr = DateFormat('HH:mm').format(state.currentTime);
    emit(state.copyWith(clockInTime: timeStr));
    await _saveAttendance();
    print(state.position?.latitude);
    int a = await _insertAttendanceToSupabase(
      status: 'clock-in',
      lat: state.position?.latitude,
      lng: state.position?.longitude,
      distance: state.distance,
    );
    await SharedPreferences.getInstance().then(
      (prefs) => prefs.setInt('attendanceId', a),
    );
    Fluttertoast.showToast(
      msg: "Clock In berhasil!",
      toastLength: Toast.LENGTH_LONG,
    );
    add(ChangeView('dashboard'));
  }

  Future<void> _onClockOut(
    ClockOut event,
    Emitter<AttendanceState> emit,
  ) async {
    if (state.isMockDetected || !state.isWithinRadius) return;
    final attendanceId = await SharedPreferences.getInstance().then(
      (prefs) => prefs.getInt('attendanceId') ?? 0,
    );
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
    Fluttertoast.showToast(
      msg: "Clock Out berhasil!",
      toastLength: Toast.LENGTH_LONG,
    );
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
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception("User belum login");

    final now = DateTime.now();
    final success = await _uploadToServer("ijin", reason: event.reason);
    // await _insertAttendanceToSupabase(status: 'ijin', note: event.reason);
    await supabase.from('attendance').insert({
      'userid': user.id.toString(),

      'date': now.toIso8601String(),
      'status': 'ijin',
      'note': event.reason,
      'clock_in': now.toIso8601String(),
      'clock_out': now.toIso8601String(),
      'latitude': state.position?.latitude.toString(),
      'longitude': state.position?.longitude.toString(),
      'distance_meters': state.distance.toString(),
    });
    emit(state.copyWith(isLoading: false));

    if (success) {
      Fluttertoast.showToast(
        msg: "Permohonan ijin berhasil dikirim!",
        toastLength: Toast.LENGTH_LONG,
      );
      emit(state.copyWith(ijinReason: '', currentView: 'dashboard'));
    }
  }

  Future<void> _onSubmitBIB(
    SubmitBIB event,
    Emitter<AttendanceState> emit,
  ) async {
    Fluttertoast.showToast(
      msg: "Absensi BIB berhasil!",
      toastLength: Toast.LENGTH_LONG,
    );
    add(ChangeView('dashboard'));
  }

  Future<void> _onUploadSickNote(
    UploadSickNote event,
    Emitter<AttendanceState> emit,
  ) async {
    if (state.sickFile == null) return;
    emit(state.copyWith(isLoading: true));

    final success = await _uploadToServer("sakit", file: state.sickFile);

    emit(state.copyWith(isLoading: false));

    if (success) {
      Fluttertoast.showToast(
        msg: "Surat sakit berhasil dikirim!",
        toastLength: Toast.LENGTH_LONG,
      );
      add(ClearSickFile());
      add(ChangeView('dashboard'));
    }
  }

  // Future<void> _signIn(
  //   SignInWithEmail event,
  //   Emitter<AttendanceState> emit,
  // ) async {
  //   try {
  //     await supabase.auth.signInWithPassword(
  //       email: event.email,
  //       password: event.password,
  //     );
  //     // Setelah login berhasil, load attendance hari ini
  //     add(LoadAttendance());
  //   } catch (e) {
  //     Fluttertoast.showToast(msg: "Login gagal: $e");
  //   }
  // }

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
      final fileName =
          '${user.id}/${type}_${dateStr}_${DateTime.now().millisecondsSinceEpoch}.${file?.name.split('.').last}';

      // Upload file ke Supabase Storage
      if (file != null) {
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
      }
      // Simpan metadata ke database
      await supabase.from('attendance').insert({
        'userid': user.id.toString(),
        'date': dateStr,
        'status': type,
        'note': file != null ? fileName : null,
        'clock_in': now.toIso8601String(),
        'clock_out': now.toIso8601String(),
        'latitude': state.position?.latitude.toString(),
        'longitude': state.position?.longitude.toString(),
        'distance_meters': state.distance.toString(),
      });

      Fluttertoast.showToast(
        msg: "Upload ke Server berhasil!",
        toastLength: Toast.LENGTH_LONG,
      );
      return true;
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Gagal upload: $e",
        toastLength: Toast.LENGTH_LONG,
      );
      // print(e.toString());
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
