import 'package:flutter/material.dart';
import 'package:coachsly/domain/entities/user.dart';

class UserProvider with ChangeNotifier {
  User? _user;

  User? get user => _user;

  void setUser(User user) {
    _user = user;
    print('UserProvider: setUser - ${user.email}, role: ${user.role}');
    notifyListeners();
  }

  void clearUser() {
    _user = null;
    print('UserProvider: clearUser');
    notifyListeners();
  }
}