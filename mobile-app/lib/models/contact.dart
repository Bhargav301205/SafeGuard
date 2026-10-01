import 'package:uuid/uuid.dart';

/// Represents a saved emergency contact.
/// Contacts are notified via email (with live map link) and automated AI voice calls.
class Contact {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String relation;

  const Contact({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    required this.relation,
  });

  factory Contact.create({
    required String name,
    required String email,
    String phone = '',
    required String relation,
  }) {
    return Contact(
      id: const Uuid().v4(),
      name: name,
      email: email,
      phone: phone,
      relation: relation,
    );
  }

  factory Contact.fromMap(Map<String, dynamic> map) {
    final rawEmail = (map['email'] ?? '') as String;
    final rawPhone = (map['phone'] ?? '') as String;
    final email = rawEmail.isNotEmpty
        ? rawEmail
        : (rawPhone.contains('@') ? rawPhone : '');
    final phone = rawPhone.contains('@') ? '' : rawPhone;

    return Contact(
      id: map['id'] as String,
      name: map['name'] as String,
      email: email,
      phone: phone,
      relation: map['relation'] as String,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'relation': relation,
      };

  Contact copyWith({
    String? name,
    String? email,
    String? phone,
    String? relation,
  }) {
    return Contact(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      relation: relation ?? this.relation,
    );
  }

  @override
  String toString() => 'Contact(id: $id, name: $name, email: $email, phone: $phone)';
}
