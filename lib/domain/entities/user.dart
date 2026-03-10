import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String email;
  final String? token;
  final String role;
  final String timezone;

  User({
    required this.id,
    required this.email,
    this.token,
    required this.role,
    required this.timezone,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    if (json['id'] == null || json['email'] == null || json['role'] == null || json['timezone'] == null) {
      throw FormatException('Invalid JSON for User: $json');
    }

    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      token: json['token'] as String?,
      role: json['role'] as String,
      timezone: json['timezone'] as String,
    );
  }

  @override
  List<Object?> get props => [id, email, token, role, timezone];
}