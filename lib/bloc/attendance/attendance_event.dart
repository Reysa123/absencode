import 'package:equatable/equatable.dart';
import 'package:image_picker/image_picker.dart';

abstract class AttendanceEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadAttendance extends AttendanceEvent {}

class UpdateLocation extends AttendanceEvent {}

class StartLocationUpdates extends AttendanceEvent {}

class StopLocationUpdates extends AttendanceEvent {}

class ChangeView extends AttendanceEvent {
  final String view;
  ChangeView(this.view);
}
class UpdateTime extends AttendanceEvent {
  final DateTime time;
   UpdateTime(this.time);
}
class SignInWithEmail extends AttendanceEvent {
  final String email;
  final String password;
  SignInWithEmail(this.email, this.password);
}

class SignOut extends AttendanceEvent {}
class ClockIn extends AttendanceEvent {}
class ClockOut extends AttendanceEvent {}

class PickSickFile extends AttendanceEvent {
  final XFile file;
  PickSickFile(this.file);
}

class ClearSickFile extends AttendanceEvent {}

class SubmitIjin extends AttendanceEvent {
  final String reason;
  SubmitIjin(this.reason);
}

class SubmitBIB extends AttendanceEvent {}

class UploadSickNote extends AttendanceEvent {}