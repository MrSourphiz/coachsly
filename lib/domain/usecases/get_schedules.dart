import 'package:coachsly/core/exceptions/app_exception.dart';
import 'package:coachsly/domain/entities/schedule.dart';
import 'package:coachsly/domain/repositories/schedule_repository.dart';
import 'package:coachsly/domain/usecases/use_case.dart';

class GetSchedules implements UseCase<List<Schedule>, String> {
  final ScheduleRepository repository;

  GetSchedules(this.repository);

  @override
  Future<List<Schedule>> execute(String userId) async {
    try {
      return await repository.getSchedules(userId);
    } catch (e) {
      throw DataException('Ошибка при получении расписаний: $e');
    }
  }
}