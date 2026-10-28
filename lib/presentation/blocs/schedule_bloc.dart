import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:formeo/domain/entities/schedule.dart';
import 'package:formeo/domain/usecases/get_schedules.dart';
import 'package:formeo/domain/usecases/book_session.dart';
import 'package:formeo/data/sources/supabase_data_source.dart';

// ───── События ─────
abstract class ScheduleEvent {}

class FetchSchedules extends ScheduleEvent {
  final String userId;
  FetchSchedules(this.userId);
}

class SubscribeSchedules extends ScheduleEvent {
  final String trainerId;
  SubscribeSchedules(this.trainerId);
}

// Тихая переподписка при возврате из фона — без ScheduleLoading на экране
class ResubscribeSchedules extends ScheduleEvent {
  final String trainerId;
  ResubscribeSchedules(this.trainerId);
}

class BookSchedule extends ScheduleEvent {
  final String userId;
  final Schedule schedule;
  BookSchedule(this.userId, this.schedule);
}

class CancelSchedule extends ScheduleEvent {
  final String bookingId;
  final String trainerId;
  CancelSchedule(this.bookingId, this.trainerId);
}

class DeleteSchedule extends ScheduleEvent {
  final String scheduleId;
  DeleteSchedule(this.scheduleId);
}

class RescheduleSchedule extends ScheduleEvent {
  final Schedule oldSchedule;
  final DateTime newScheduledAt;
  final String trainerId;
  RescheduleSchedule({
    required this.oldSchedule,
    required this.newScheduledAt,
    required this.trainerId,
  });
}

// ───── Состояния ─────
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

// ───── Блок ─────
class ScheduleBloc extends Bloc<ScheduleEvent, ScheduleState> {
  final GetSchedules getSchedules;
  final BookSession bookSession;

  bool _subscriptionActive = false;
  String? _subscribedTrainerId;

  ScheduleBloc({
    required this.getSchedules,
    required this.bookSession,
  }) : super(ScheduleInitial()) {
    on<FetchSchedules>(_onFetchSchedules);
    on<SubscribeSchedules>(_onSubscribeSchedules);
    on<ResubscribeSchedules>(_onResubscribeSchedules);
    on<BookSchedule>(_onBookSchedule);
    on<CancelSchedule>(_onCancelSchedule);
    on<DeleteSchedule>(_onDeleteSchedule);
    on<RescheduleSchedule>(_onRescheduleSchedule);
  }

  Future<void> _onFetchSchedules(
      FetchSchedules event,
      Emitter<ScheduleState> emit,
      ) async {
    debugPrint('_onFetchSchedules called, userId: ${event.userId}');
    emit(ScheduleLoading());
    try {
      final schedules = await getSchedules.execute(event.userId);
      debugPrint('Schedules loaded: ${schedules.length}');
      emit(ScheduleSuccess(schedules));
    } catch (e) {
      debugPrint('ScheduleError: $e');
      emit(ScheduleError('Ошибка загрузки расписания: $e'));
    }
  }

  Future<void> _onSubscribeSchedules(
      SubscribeSchedules event,
      Emitter<ScheduleState> emit,
      ) async {
    if (_subscriptionActive && _subscribedTrainerId == event.trainerId) {
      debugPrint(
          'SubscribeSchedules: already active for ${event.trainerId}, skipping');
      return;
    }

    _subscriptionActive = true;
    _subscribedTrainerId = event.trainerId;

    if (state is! ScheduleSuccess) {
      emit(ScheduleLoading());
    }

    const maxRetries = 3;
    int attempt = 0;

    // Оборачиваем весь retry-цикл в try/finally,
    // чтобы флаг сбрасывался ВСЕГДА — включая return внутри catch.
    try {
      while (!emit.isDone) {
        try {
          await emit.forEach(
            GetIt.instance<SupabaseDataSource>()
                .subscribeSchedules(event.trainerId),
            onData: (List<Map<String, dynamic>> rows) {
              final schedules = _parseSchedules(rows);
              attempt = 0;
              debugPrint('SubscribeSchedules update: ${schedules.length}');
              return ScheduleSuccess(schedules);
            },
            onError: (error, stackTrace) {
              debugPrint('SubscribeSchedules stream error: $error');
              return state is ScheduleSuccess
                  ? state as ScheduleSuccess
                  : ScheduleLoading();
            },
          );
          // emit.forEach завершился без исключения — выходим из цикла
          break;
        } catch (e) {
          attempt++;
          debugPrint('SubscribeSchedules catch attempt $attempt: $e');

          if (attempt >= maxRetries) {
            debugPrint('SubscribeSchedules: max retries reached');
            if (!emit.isDone) {
              emit(ScheduleError('Ошибка подписки на расписание: $e'));
            }
            // Выходим из метода через finally — флаг будет сброшен там
            return;
          }

          final delay = Duration(seconds: attempt * 2);
          debugPrint('SubscribeSchedules: retry in ${delay.inSeconds}s');
          await Future.delayed(delay);

          if (!emit.isDone && state is! ScheduleSuccess) {
            emit(ScheduleLoading());
          }
        }
      }
    } finally {
      // Сброс флага гарантирован при любом пути выхода из метода:
      // нормальное завершение, return после maxRetries, исключение.
      _subscriptionActive = false;
      _subscribedTrainerId = null;
      debugPrint('SubscribeSchedules: subscription ended, flag reset');
    }
  }

  Future<void> _onResubscribeSchedules(
      ResubscribeSchedules event,
      Emitter<ScheduleState> emit,
      ) async {
    debugPrint(
        'ResubscribeSchedules: silent resubscribe for ${event.trainerId}');
    _subscriptionActive = false;
    _subscribedTrainerId = null;
    await _onSubscribeSchedules(SubscribeSchedules(event.trainerId), emit);
  }

  Future<void> _onBookSchedule(
      BookSchedule event,
      Emitter<ScheduleState> emit,
      ) async {
    final currentSchedules = state is ScheduleSuccess
        ? List<Schedule>.from((state as ScheduleSuccess).schedules)
        : <Schedule>[];

    try {
      final newId = await bookSession.execute(event.schedule);

      final newSchedule = event.schedule.copyWith(
        id: newId,
        createdAt: DateTime.now().toUtc(),
      );

      currentSchedules.add(newSchedule);
      currentSchedules.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      emit(ScheduleSuccess(currentSchedules));
    } catch (e) {
      emit(ScheduleError('Ошибка бронирования: $e'));
    }
  }

  Future<void> _onCancelSchedule(
      CancelSchedule event,
      Emitter<ScheduleState> emit,
      ) async {
    // Оптимистичное обновление: меняем статус мгновенно, не ждём Realtime
    if (state is ScheduleSuccess) {
      final updated = (state as ScheduleSuccess).schedules.map((s) {
        if (s.id == event.bookingId) {
          return s.copyWith(bookingState: 'canceled', status: 'canceled');
        }
        return s;
      }).toList();
      emit(ScheduleSuccess(updated));
    }

    try {
      await GetIt.instance<SupabaseDataSource>().cancelBooking(event.bookingId);
      // Realtime придёт и синхронизирует финальное состояние с БД
    } catch (e) {
      debugPrint('CancelSchedule error: $e');
      emit(ScheduleError('Ошибка отмены тренировки: $e'));
    }
  }

  Future<void> _onDeleteSchedule(
      DeleteSchedule event,
      Emitter<ScheduleState> emit,
      ) async {
    // Оптимистичное удаление: убираем запись мгновенно, не ждём Realtime
    if (state is ScheduleSuccess) {
      final updated = (state as ScheduleSuccess)
          .schedules
          .where((s) => s.id != event.scheduleId)
          .toList();
      emit(ScheduleSuccess(updated));
    }

    try {
      await GetIt.instance<SupabaseDataSource>()
          .deleteSchedule(event.scheduleId);
      // Realtime придёт и синхронизирует финальное состояние с БД
    } catch (e) {
      debugPrint('DeleteSchedule error: $e');
      emit(ScheduleError('Ошибка удаления тренировки: $e'));
    }
  }

  Future<void> _onRescheduleSchedule(
      RescheduleSchedule event,
      Emitter<ScheduleState> emit,
      ) async {
    // Оптимистичное обновление: помечаем старую как rescheduled,
    // добавляем новую с временным id
    if (state is ScheduleSuccess) {
      final current = (state as ScheduleSuccess).schedules;
      final optimistic = current.map((s) {
        if (s.id == event.oldSchedule.id) {
          return s.copyWith(bookingState: 'rescheduled', status: 'rescheduled');
        }
        return s;
      }).toList();

      final tempNew = event.oldSchedule.copyWith(
        id: '__temp_${DateTime.now().microsecondsSinceEpoch}__',
        scheduledAt: event.newScheduledAt,
        bookingState: 'scheduled',
        confirmationState: 'pending',
        status: 'scheduled',
        createdAt: DateTime.now().toUtc(),
        bookingCreatedNotifiedAt: null,
      );
      optimistic.add(tempNew);
      optimistic.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      emit(ScheduleSuccess(optimistic));
    }

    try {
      final s = event.oldSchedule;
      await GetIt.instance<SupabaseDataSource>().rescheduleBooking(
        oldBookingId: s.id!,
        newScheduledAt: event.newScheduledAt,
        timezone: s.timezone,
        trainerId: s.trainerId,
        clientId: s.clientId,
        sessionType: s.sessionType,
        workoutPlanId: s.workoutPlanId,
        workoutDayNumber: s.workoutDayNumber,
        description: s.description,
      );
      // Realtime придёт и заменит оптимистичный список актуальным
    } catch (e) {
      debugPrint('RescheduleSchedule error: $e');
      emit(ScheduleError('Ошибка переноса тренировки: $e'));
    }
  }

  List<Schedule> _parseSchedules(List<Map<String, dynamic>> rows) {
    return rows.map((json) {
      final bookingState = json['booking_state'] as String? ?? 'scheduled';
      final confirmationState =
          json['confirmation_state'] as String? ?? 'pending';

      String status;
      if (bookingState == 'canceled') {
        status = 'canceled';
      } else if (bookingState == 'rescheduled') {
        status = 'rescheduled';
      } else if (bookingState == 'completed') {
        status = 'completed';
      } else if (confirmationState == 'confirmed') {
        status = 'confirmed';
      } else if (confirmationState == 'no_response') {
        status = 'no_response';
      } else {
        status = 'scheduled';
      }

      DateTime? createdAt;
      if (json['created_at'] != null) {
        createdAt = DateTime.tryParse(json['created_at'] as String)?.toUtc();
      }

      DateTime? bookingCreatedNotifiedAt;
      if (json['booking_created_notified_at'] != null) {
        bookingCreatedNotifiedAt =
            DateTime.tryParse(json['booking_created_notified_at'] as String)
                ?.toUtc();
      }

      DateTime? rescheduledToAt;
      if (json['rescheduled_to_at'] != null) {
        rescheduledToAt =
            DateTime.tryParse(json['rescheduled_to_at'] as String)?.toUtc();
      }

      if (bookingState == 'rescheduled') {
        debugPrint('_parseSchedules RESCHEDULED: id=${json['id']} raw=${json['rescheduled_to_at']} parsed=$rescheduledToAt');
      }

      final paymentsRaw = json['payments'];
      bool isPaid = false;
      if (paymentsRaw is List && paymentsRaw.isNotEmpty) {
        isPaid = paymentsRaw.any((p) => (p as Map)['status'] == 'paid');
      } else if (json['is_paid'] is bool) {
        isPaid = json['is_paid'] as bool;
      } else if (json['payment_state'] is String) {
        isPaid = json['payment_state'] == 'paid';
      }

      return Schedule(
        id: json['id'] as String?,
        scheduledAt: DateTime.parse(json['scheduled_at'] as String).toUtc(),
        timezone: json['timezone'] as String,
        trainerId: json['trainer_id'] as String,
        clientId: json['client_id'] as String,
        sessionType: json['session_type'] as String,
        status: status,
        bookingState: bookingState,
        confirmationState: confirmationState,
        createdAt: createdAt,
        isPaid: isPaid,
        bookingCreatedNotifiedAt: bookingCreatedNotifiedAt,
        workoutPlanId: json['workout_plan_id'] as String?,
        workoutDayNumber: json['workout_day_number'] as int?,
        description: json['description'] as String?,
        rescheduledToAt: rescheduledToAt,
        blockSessionNumber: json['block_session_number'] as int?,
        blockTotalSessions: json['block_total_sessions'] as int?,
        quickPlanId: json['quick_plan_id'] as String?,
        quickPlanDayOfWeek: json['quick_plan_day_of_week'] as int?,
      );
    }).toList();
  }
}
