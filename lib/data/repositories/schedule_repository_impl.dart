import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:formeo/core/exceptions/app_exception.dart';
import 'package:formeo/data/sources/supabase_data_source.dart';
import 'package:formeo/domain/entities/schedule.dart';
import 'package:formeo/domain/entities/client.dart';
import 'package:formeo/domain/repositories/schedule_repository.dart';

final logger = Logger();

class ScheduleRepositoryImpl implements ScheduleRepository {
  final SupabaseDataSource _dataSource;

  ScheduleRepositoryImpl(this._dataSource);

  @override
  Future<List<Schedule>> getSchedules(String userId) async {
    final response = await _dataSource.getSchedules(userId);
    final schedules = response.map((json) => Schedule.fromJson(json)).toList();
    debugPrint('Parsed schedules: ${schedules.length}');
    return schedules;

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
  Future<void> cancelBooking(String bookingId) async {
    try {
      await _dataSource.cancelBooking(bookingId);
    } catch (e) {
      logger.e('Не удалось отменить тренировку:', error:e );
      throw DataException('Не удалось отменить тренировку: $e');
    }
  }

  @override
  Future<List<Client>> fetchClients(String userId) async {
    final response = await _dataSource.fetchTrainerClients(userId);
    return response.map((json) => Client.fromJson(json)).toList();
  }
}
