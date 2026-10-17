import 'package:flutter/material.dart';

/// Password categories / platforms shown as filter chips and in the form.
enum PasswordCategory {
  social('Social', Icons.groups_rounded),
  email('Email', Icons.mail_rounded),
  finance('Finance', Icons.account_balance_wallet_rounded),
  work('Work', Icons.work_rounded),
  shopping('Shopping', Icons.shopping_bag_rounded),
  entertainment('Entertainment', Icons.movie_rounded),
  other('Other', Icons.key_rounded);

  const PasswordCategory(this.label, this.icon);
  final String label;
  final IconData icon;

  static PasswordCategory fromName(String? name) =>
      values.firstWhere((c) => c.name == name, orElse: () => other);
}

/// A saved credential. [encryptedPassword] is AES-GCM ciphertext — the
/// plain-text password is never stored on this model.
@immutable
class PasswordItem {
  const PasswordItem({
    required this.id,
    required this.title,
    required this.username,
    required this.encryptedPassword,
    required this.category,
    required this.updatedAt,
    this.iconPath,
  });

  final String id;
  final String title;
  final String username;
  final String encryptedPassword;
  final PasswordCategory category;

  /// Optional absolute path to a locally stored logo image.
  final String? iconPath;
  final DateTime updatedAt;

  PasswordItem copyWith({
    String? title,
    String? username,
    String? encryptedPassword,
    PasswordCategory? category,
    String? iconPath,
    bool clearIcon = false,
    DateTime? updatedAt,
  }) =>
      PasswordItem(
        id: id,
        title: title ?? this.title,
        username: username ?? this.username,
        encryptedPassword: encryptedPassword ?? this.encryptedPassword,
        category: category ?? this.category,
        iconPath: clearIcon ? null : (iconPath ?? this.iconPath),
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory PasswordItem.fromJson(Map<String, dynamic> json) => PasswordItem(
        id: json['id'] as String,
        title: json['title'] as String,
        username: json['username'] as String,
        encryptedPassword: json['encryptedPassword'] as String,
        category: PasswordCategory.fromName(json['category'] as String?),
        iconPath: json['iconPath'] as String?,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'username': username,
        'encryptedPassword': encryptedPassword,
        'category': category.name,
        'iconPath': iconPath,
        'updatedAt': updatedAt.toIso8601String(),
      };
}
