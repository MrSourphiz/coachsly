import 'package:logger/logger.dart';
import 'package:coachsly/core/exceptions/app_exception.dart';
import 'package:coachsly/data/sources/supabase_data_source.dart';
import 'package:coachsly/domain/entities/schedule.dart';
import 'package:coachsly/domain/entities/client.dart';
import 'package:coachsly/domain/repositories/schedule_repository.dart';

final logger = Logger();

class ScheduleRepositoryImpl implements ScheduleRepository {
  final SupabaseDataSource _dataSource;

  ScheduleRepositoryImpl(this._dataSource);

  @override
  Future<List<Schedule>> getSchedules(String userId) async {
    final response = await _dataSource.getSchedules(userId);
    return response.map((json) => Schedule.fromJson(json)).toList();
  }

  @override
  Future<String> addSchedule(Schedule schedule) async {
    try {
      final newId = await _dataSource.addSchedule(schedule.toJson());
      return newId;
    } catch (e) {
      logger.e('Ошибка при добавлении расписания:', error:e );
      throw DataException('Ошибка при добавлении расписания: $e');
    }
  }

  @override
  Future<List<Client>> fetchClients(String userId) async {
    final response = await _dataSource.fetchTrainerClients(userId);
    return response.map((json) => Client.fromJson(json)).toList();
  }
}