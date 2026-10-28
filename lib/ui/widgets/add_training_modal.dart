import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AddTrainingModal extends StatefulWidget {
  final String trainerId;

  const AddTrainingModal({super.key, required this.trainerId});

  @override
  State<AddTrainingModal> createState() => _AddTrainingModalState();
}

class _AddTrainingModalState extends State<AddTrainingModal> {
  String? selectedClientId;
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  bool isRecurring = false;
  final List<int> selectedWeekdays = [];
  int repeatWeeks = 4;
  bool useProgramDuration = false;

  // TODO: Заменить на реальные данные из Supabase
  final List<Map<String, String>> mockClients = [
    {'id': '1', 'name': 'Иван Иванов'},
    {'id': '2', 'name': 'Петр Петров'},
    {'id': '3', 'name': 'Сергей Сергеев'},
  ];

  Future<void> pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(Duration(days: 365)),
    );
    if (picked != null) {
      if (!mounted) return;
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      if (!mounted) return;
      setState(() {
        selectedTime = picked;
      });
    }
  }

  List<DateTime> generateRecurringDates() {
    if (selectedDate == null || selectedTime == null) return [];

    final startDate = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      selectedTime!.hour,
      selectedTime!.minute,
    );
    final weeks = useProgramDuration ? 8 : repeatWeeks; // Пример: 8 недель по умолчанию
    final endDate = startDate.add(Duration(days: weeks * 7));

    DateTime current = startDate;
    List<DateTime> result = [];

    while (current.isBefore(endDate)) {
      if (selectedWeekdays.contains(current.weekday)) {
        result.add(current);
      }
      current = current.add(Duration(days: 1));
    }

    return result;
  }

  void submit() {
    if (selectedClientId == null || selectedDate == null || selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Пожалуйста, выберите клиента, дату и время')),
      );
      return;
    }

    final startDateTime = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      selectedTime!.hour,
      selectedTime!.minute,
    );

    final dates = isRecurring ? generateRecurringDates() : [startDateTime];

    Navigator.of(context).pop({
      'clientId': selectedClientId,
      'trainerId': widget.trainerId,
      'dates': dates,
      'durationMinutes': 60, // по умолчанию
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: MediaQuery.of(context).viewInsets.add(EdgeInsets.all(16)),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Назначить тренировку', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: 'Клиент'),
                value: selectedClientId,
                items: mockClients.map((client) {
                  return DropdownMenuItem(
                    value: client['id'],
                    child: Text(client['name']!),
                  );
                }).toList(),
                onChanged: (value) => setState(() => selectedClientId = value),
              ),

              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: pickDate,
                      icon: Icon(Icons.date_range),
                      label: Text(
                        selectedDate != null
                            ? DateFormat('dd.MM.yyyy').format(selectedDate!)
                            : 'Выбрать дату',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: pickTime,
                      icon: Icon(Icons.access_time),
                      label: Text(
                        selectedTime != null
                            ? selectedTime!.format(context)
                            : 'Время',
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              SwitchListTile(
                value: isRecurring,
                onChanged: (value) => setState(() => isRecurring = value),
                title: Text('Повторять тренировку'),
              ),

              if (isRecurring) ...[
                Wrap(
                  spacing: 8,
                  children: List.generate(7, (i) {
                    final day = i + 1;
                    const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
                    return FilterChip(
                      label: Text(days[i]),
                      selected: selectedWeekdays.contains(day),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            selectedWeekdays.add(day);
                          } else {
                            selectedWeekdays.remove(day);
                          }
                        });
                      },
                    );
                  }),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: useProgramDuration,
                  onChanged: (val) => setState(() => useProgramDuration = val ?? false),
                  title: Text('До конца программы'),
                ),
                if (!useProgramDuration)
                  Row(
                    children: [
                      Text('Длительность:'),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: repeatWeeks,
                        items: List.generate(12, (i) => i + 1)
                            .map((e) => DropdownMenuItem(value: e, child: Text('$e недель')))
                            .toList(),
                        onChanged: (val) => setState(() => repeatWeeks = val ?? 4),
                      ),
                    ],
                  ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: submit,
                  child: Text('Сохранить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
