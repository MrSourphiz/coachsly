import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:coachsly/core/service/payment_service.dart';


class TrainerSettingsScreen extends StatefulWidget {
  @override
  _TrainerSettingsScreenState createState() => _TrainerSettingsScreenState();
}

class _TrainerSettingsScreenState extends State<TrainerSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bankController = TextEditingController();
  final _requisitesController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPaymentDetails();
  }

  Future<void> _loadPaymentDetails() async {
    final details = await PaymentService().getTrainerPaymentDetails();
    if (details != null) {
      setState(() {
        _bankController.text = details.bankName;
        _requisitesController.text = details.requisites;
        _phoneController.text = details.phoneNumber ?? '';
      });
    }
  }

  Future<void> _savePaymentDetails() async {
    if (_formKey.currentState!.validate()) {
      try {
        await PaymentService().saveTrainerPaymentDetails(
          bankName: _bankController.text,
          requisites: _requisitesController.text,
          phoneNumber: _phoneController.text.isNotEmpty
              ? _phoneController.text
              : null,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Реквизиты успешно сохранены')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Настройки оплаты'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(
                'Платежные реквизиты',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: _bankController,
                decoration: InputDecoration(
                  labelText: 'Банк',
                  border: OutlineInputBorder(),
                  hintText: 'Сбербанк, Тинькофф и т.д.',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Укажите банк';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _requisitesController,
                decoration: InputDecoration(
                  labelText: 'Реквизиты для оплаты',
                  border: OutlineInputBorder(),
                  hintText: 'Номер карты или расчетный счет',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Укажите реквизиты';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Номер телефона (опционально)',
                  border: OutlineInputBorder(),
                  hintText: '+7 (999) 123-45-67',
                ),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _savePaymentDetails,
                child: Text('Сохранить реквизиты'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
              SizedBox(height: 32),
              Text(
                'Как это работает?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                '1. Сохраните свои реквизиты\n'
                    '2. После тренировки бот отправит клиенту ваши реквизиты\n'
                    '3. Клиент оплатит и отправит чек в Telegram\n'
                    '4. Вы получите уведомление в приложении',
              ),
            ],
          ),
        ),
      ),
    );
  }
}