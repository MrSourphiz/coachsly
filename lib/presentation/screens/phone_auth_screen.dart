import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});


  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}


class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _sending = false;


  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }


  Future<void> _sendCode() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _sending = true);
    try {
// TODO: implement sending code via Supabase or your backend.
// After sending, navigate to CodeVerificationScreen with the phone param.
      await Future.delayed(const Duration(milliseconds: 400));
      context.go('/verify-phone', extra: {'phone': _phoneController.text.trim()});
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Вход по телефону')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Номер телефона'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите номер' : null,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _sending ? null : _sendCode, child: const Text('Получить код')),
          ],
        ),
      ),
    );
  }
}