import 'package:coachsly/domain/entities/schedule.dart';
import 'package:coachsly/domain/entities/client.dart';

abstract class ScheduleRepository {
  Future<List<Schedule>> getSchedules(String userId);
  Future<String> addSchedule(Schedule schedule);
  Future<List<Client>> fetchClients(String userId);
}