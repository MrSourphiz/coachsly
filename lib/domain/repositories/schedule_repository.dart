import 'package:formeo/domain/entities/schedule.dart';
import 'package:formeo/domain/entities/client.dart';

abstract class ScheduleRepository {
  Future<List<Schedule>> getSchedules(String userId);
  Future<String> addSchedule(Schedule schedule);
  Future<List<Client>> fetchClients(String userId);
  Future<void> cancelBooking(String bookingId);
}
