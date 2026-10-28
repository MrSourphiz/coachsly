import 'package:flutter/material.dart';

class SplashProgressProvider extends ChangeNotifier {
  double _progress = 0.0;
  String _statusText = 'Запуск приложения...';
  bool _isReady = false;

  // Колбэк который SplashWrapper повесит на провайдер
  VoidCallback? onReadyCallback;

  double get progress => _progress;
  String get statusText => _statusText;
  bool get isReady => _isReady;

  void setProgress(double value, String text) {
    _progress = value;
    _statusText = text;
    notifyListeners();
  }

  void setReady() {
    _progress = 1.0;
    _statusText = 'Готово!';
    _isReady = true;
    notifyListeners();
    // Вызываем колбэк чтобы SplashWrapper узнал о готовности
    onReadyCallback?.call();
  }
}
