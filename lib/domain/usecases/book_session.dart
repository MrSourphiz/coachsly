import 'package:coachsly/core/exceptions/app_exception.dart';
import 'package:coachsly/domain/entities/schedule.dart';
import 'package:coachsly/domain/repositories/schedule_repository.dart';
import 'package:coachsly/domain/usecases/use_case.dart';

class BookSession implements UseCase<void, Schedule> {
  final ScheduleRepository repository;

  BookSession(this.repository);

  @override
  Future<String> execute(Schedule schedule) async {
    try {
      final newId = await repository.addSchedule(schedule);
      return newId;
    } catch (e) {
      throw DataException('Ошибка при бронировании: $e');
    }
  }
}