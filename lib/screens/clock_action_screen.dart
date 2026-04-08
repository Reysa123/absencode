import 'package:absen/bloc/attendance/attendance_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../bloc/attendance/attendance_bloc.dart';
import '../bloc/attendance/attendance_event.dart';

class ClockActionScreen extends StatefulWidget {
  const ClockActionScreen({super.key});

  @override
  State<ClockActionScreen> createState() => _ClockActionScreenState();
}

class _ClockActionScreenState extends State<ClockActionScreen> {
  MapController? mapController;
  late AttendanceBloc attendanceBloc;
  @override
  void initState() {
    super.initState();
    mapController = MapController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    attendanceBloc = context.read<AttendanceBloc>();
    attendanceBloc.add(StartLocationUpdates());
  }

  @override
  void dispose() {
    attendanceBloc.add(StopLocationUpdates());
    //context.read<AttendanceBloc>().add(StopLocationUpdates());
    mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AttendanceBloc, AttendanceState>(
      builder: (context, state) {
        final bloc = context.read<AttendanceBloc>();
        final isClockIn = state.currentView == 'clock-in';
        print(state.toString());
        return Scaffold(
          appBar: AppBar(
            title: Text(isClockIn ? 'Clock In' : 'Clock Out'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => bloc.add(ChangeView('dashboard')),
            ),
          ),
          body: Stack(
            children: [
              // Flutter Map
              FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter: const LatLng(-8.641514, 115.209754),
                  initialZoom: 18.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName:
                        'com.example.absen', // Replace with your app's package name
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: const LatLng(-8.641514, 115.209754),
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                      if (state.position != null)
                        Marker(
                          point: LatLng(
                            state.position!.latitude,
                            state.position!.longitude,
                          ),
                          child: const Icon(
                            Icons.my_location,
                            color: Colors.blue,
                            size: 40,
                          ),
                        ),
                    ],
                  ),
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: const LatLng(-8.641514, 115.209754),
                        radius: 100,
                        color: Colors.green.withAlpha(38),
                        borderColor: Colors.green,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                ],
              ),

              // Bottom Info Panel
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 12),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (state.distance != null)
                        Text(
                          "Jarak dari kantor: ${state.distance!.round()} meter",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: state.isWithinRadius
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      if (state.isMockDetected)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            "⚠️ Mock Location Terdeteksi!\nAbsensi dinonaktifkan.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed:
                            (state.isWithinRadius && !state.isMockDetected)
                            ? () => bloc.add(
                                state.currentView == 'clock-in'
                                    ? ClockIn()
                                    : ClockOut(),
                              )
                            : null,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 60),
                          backgroundColor: Colors.blue[700],
                        ),
                        child: const Text(
                          "SUBMIT ABSENSI",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
