import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CodeVerificationScreen extends StatefulWidget {
  final String destination; // email or phone for user clarity
  const CodeVerificationScreen({super.key, required this.destination});


  @override
  State<CodeVerificationScreen> createState() => _CodeVerificationScreenState();
}


class _CodeVerificationScreenState extends State<CodeVerificationScreen> {
  final _codeController = TextEditingController();
  bool _verifying = false;
  int _secondsLeft = 45;


  @override
  void initState() {
    super.initState();
    _startTimer();
  }


  void _startTimer() {
    _secondsLeft = 45;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _secondsLeft--);
      return _secondsLeft > 0;
    });
  }


  void _verify() async {
    if (_codeController.text.trim().isEmpty) return;
    setState(() => _verifying = true);
    try {
// TODO: implement verification call with your backend / Supabase
      await Future.delayed(const Duration(milliseconds: 600));
// On success: navigate to app main screen. Let bloc handle persistent auth state.
      context.go('/');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }


  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Введите код')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text('Код отправлен на ${widget.destination}'),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Код из SMS / Email'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _verifying ? null : _verify, child: const Text('Подтвердить')),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _secondsLeft > 0
                  ? null
                  : () {
// TODO: implement resend
                _startTimer();
              },
              child: Text(_secondsLeft > 0 ? 'Отправить снова ($_secondsLeft)' : 'Отправить снова'),
            ),
          ],
        ),
      ),
    );
  }
}