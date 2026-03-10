import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:coachsly/core/exceptions/app_exception.dart';
import 'package:coachsly/domain/entities/schedule.dart';
import 'package:coachsly/domain/usecases/get_schedules.dart';
import 'package:coachsly/domain/usecases/book_session.dart';

abstract class ScheduleEvent {}

class FetchSchedules extends ScheduleEvent {
  final String userId;
  FetchSchedules(this.userId);
}

class BookSchedule extends ScheduleEvent {
  final String userId;
  final Schedule schedule;
  BookSchedule(this.userId, this.schedule);
}

abstract class ScheduleState {}

class ScheduleInitial extends ScheduleState {}

class ScheduleLoading extends ScheduleState {}

class ScheduleSuccess extends ScheduleState {
  final List<Schedule> schedules;
  ScheduleSuccess(this.schedules);
}

class ScheduleAddedSuccess extends ScheduleState {
  final Schedule schedule;
  ScheduleAddedSuccess(this.schedule);
}

class ScheduleError extends ScheduleState {
  final String message;
  ScheduleError(this.message);
}

class ScheduleBloc extends Bloc<ScheduleEvent, ScheduleState> {
  final GetSchedules getSchedules;
  final BookSession bookSession;

  ScheduleBloc({
    required this.getSchedules,
    required this.bookSession,
  }) : super(ScheduleInitial()) {
    on<FetchSchedules>(_onFetchSchedules);
    on<BookSchedule>(_onBookSchedule);
  }

  @override
  Future<void> _onFetchSchedules(FetchSchedules event, Emitter<ScheduleState> emit) async {
    emit(ScheduleLoading());
    try {
      final schedules = await getSchedules.execute(event.userId);
      emit(ScheduleSuccess(schedules));
    } catch (e) {
      emit(ScheduleError('Ошибка загрузки расписания: $e'));
    }
  }

  @override
  Future<void> _onBookSchedule(BookSchedule event, Emitter<ScheduleState> emit) async {
    emit(ScheduleLoading());
    try {
      final newId = await bookSession.execute(event.schedule);
      final newSchedule = event.schedule.copyWith(id: newId);

      emit(ScheduleAddedSuccess(newSchedule));

      final schedules = await getSchedules.execute(event.userId);
      emit(ScheduleSuccess(schedules));
    } catch (e) {
      emit(ScheduleError('Ошибка бронирования: $e'));
    }
  }
}