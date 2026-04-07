import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

class AttendanceState extends Equatable {
  final String currentView;
  final DateTime currentTime;
  final Position? position;
  final double? distance;
  final bool isMockDetected;
  final bool isLoading;
  final bool isWithinRadius;
  final String? clockInTime;
  final String? clockOutTime;
  final XFile? sickFile;
  final String ijinReason;

  const AttendanceState({
    this.currentView = 'dashboard',
    required this.currentTime,
    this.position,
    this.distance,
    this.isMockDetected = false,
    this.isLoading = false,
    this.isWithinRadius = false,
    this.clockInTime,
    this.clockOutTime,
    this.sickFile,
    this.ijinReason = '',
  });

  AttendanceState copyWith({
    String? currentView,
    DateTime? currentTime,
    Position? position,
    double? distance,
    bool? isMockDetected,
    bool? isLoading,
    bool? isWithinRadius,
    String? clockInTime,
    String? clockOutTime,
    XFile? sickFile,
    String? ijinReason,
  }) {
    return AttendanceState(
      currentView: currentView ?? this.currentView,
      currentTime: currentTime ?? this.currentTime,
      position: position ?? this.position,
      distance: distance ?? this.distance,
      isMockDetected: isMockDetected ?? this.isMockDetected,
      isLoading: isLoading ?? this.isLoading,
      isWithinRadius: isWithinRadius ?? this.isWithinRadius,
      clockInTime: clockInTime ?? this.clockInTime,
      clockOutTime: clockOutTime ?? this.clockOutTime,
      sickFile: sickFile ?? this.sickFile,
      ijinReason: ijinReason ?? this.ijinReason,
    );
  }

  @override
  List<Object?> get props => [
    currentView,
    currentTime,
    position,
    distance,
    isMockDetected,
    isLoading,
    isWithinRadius,
    clockInTime,
    clockOutTime,
    sickFile,
    ijinReason,
  ];
}
