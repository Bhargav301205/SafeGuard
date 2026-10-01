import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../models/contact.dart';

/// Local-first CRUD for emergency contacts using SQLite (on mobile)
/// and SharedPreferences/in-memory (on Web).
/// Synchronizes to the FastAPI backend.
class ContactsRepository extends ChangeNotifier {
  Database? _db;
  List<Contact> _contacts = [];
  final List<Map<String, dynamic>> _localIncidents = [];

  List<Contact> get contacts => List.unmodifiable(_contacts);

  // ── Init ────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (kIsWeb) {
      await _loadFromWebStorage();
      syncFromBackend();
      return;
    }
    try {
      final dbPath = p.join(await getDatabasesPath(), AppConstants.dbName);
      _db = await openDatabase(
        dbPath,
        version: 3, // supports both email (alerts) and phone (AI voice calls)
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE contacts (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              email TEXT NOT NULL,
              phone TEXT NOT NULL DEFAULT '',
              relation TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE incidents (
              id TEXT PRIMARY KEY,
              timestamp TEXT NOT NULL,
              lat REAL NOT NULL,
              lng REAL NOT NULL,
              address TEXT NOT NULL,
              status TEXT NOT NULL,
              sensor_snapshot TEXT NOT NULL,
              contacts_notified TEXT NOT NULL,
              emergency_call_placed INTEGER NOT NULL DEFAULT 0
            )
          ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('ALTER TABLE contacts ADD COLUMN email TEXT NOT NULL DEFAULT ""');
          }
          if (oldVersion < 3) {
            try {
              await db.execute('ALTER TABLE contacts ADD COLUMN phone TEXT NOT NULL DEFAULT ""');
            } catch (_) {}
          }
        },
      );
      await _loadFromDb();
      syncFromBackend();
    } catch (e) {
      debugPrint('[ContactsRepo] SQLite init failed (falling back to web/prefs storage): $e');
      await _loadFromWebStorage();
      syncFromBackend();
    }
  }

  // ── Contacts CRUD ────────────────────────────────────────────────────────

  Future<void> _loadFromDb() async {
    if (_db == null) return;
    final rows = await _db!.query('contacts');
    _contacts = rows.map(Contact.fromMap).toList();
    notifyListeners();
  }

  Future<void> _loadFromWebStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('local_contacts');
      if (jsonStr != null) {
        final list = jsonDecode(jsonStr) as List;
        _contacts = list.map((e) => Contact.fromMap(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[ContactsRepo] Error loading web storage: $e');
    }
    notifyListeners();
  }

  Future<void> _saveToWebStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_contacts.map((c) => c.toMap()).toList());
      await prefs.setString('local_contacts', jsonStr);
    } catch (e) {
      debugPrint('[ContactsRepo] Error saving web storage: $e');
    }
  }

  Future<void> addContact(Contact contact) async {
    if (_db != null) {
      await _db!.insert('contacts', contact.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    if (!_contacts.any((c) => c.id == contact.id)) {
      _contacts.add(contact);
    }
    notifyListeners();
    _saveToWebStorage();
    _syncContactToBackend(contact);
  }

  Future<void> updateContact(Contact contact) async {
    if (_db != null) {
      await _db!.update(
        'contacts',
        contact.toMap(),
        where: 'id = ?',
        whereArgs: [contact.id],
      );
    }
    final idx = _contacts.indexWhere((c) => c.id == contact.id);
    if (idx != -1) _contacts[idx] = contact;
    notifyListeners();
    _saveToWebStorage();
    _syncContactToBackend(contact);
  }

  Future<void> deleteContact(String id) async {
    if (_db != null) {
      await _db!.delete('contacts', where: 'id = ?', whereArgs: [id]);
    }
    _contacts.removeWhere((c) => c.id == id);
    notifyListeners();
    _saveToWebStorage();
    _deleteContactOnBackend(id);
  }

  // ── Incident Logging ────────────────────────────────────────────────────

  Future<void> logIncident(Map<String, dynamic> incidentMap) async {
    final row = {
      'id': incidentMap['id'],
      'timestamp': incidentMap['timestamp'],
      'lat': incidentMap['lat'],
      'lng': incidentMap['lng'],
      'address': incidentMap['address'],
      'status': incidentMap['status'],
      'sensor_snapshot': jsonEncode(incidentMap['sensorSnapshot']),
      'contacts_notified': jsonEncode(incidentMap['contactsNotified']),
      'emergency_call_placed': (incidentMap['emergencyCallPlaced'] == true || incidentMap['emergencyCallPlaced'] == 1) ? 1 : 0,
    };
    _localIncidents.insert(0, {
      ...incidentMap,
      'emergencyCallPlaced': incidentMap['emergencyCallPlaced'] == true || incidentMap['emergencyCallPlaced'] == 1,
    });
    if (_db != null) {
      await _db!.insert('incidents', row,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<List<Map<String, dynamic>>> getIncidents() async {
    if (_db != null) {
      try {
        final rows = await _db!.query('incidents', orderBy: 'timestamp DESC');
        return rows.map((r) {
          return {
            ...r,
            'sensorSnapshot': jsonDecode(r['sensor_snapshot'] as String),
            'contactsNotified': jsonDecode(r['contacts_notified'] as String),
            'emergencyCallPlaced': r['emergency_call_placed'] == 1 || r['emergency_call_placed'] == true,
          };
        }).toList();
      } catch (e) {
        debugPrint('[ContactsRepo] Error querying SQLite incidents: $e');
      }
    }
    // Web / cloud fallback: fetch from backend
    try {
      final base = await _baseUrl;
      final headers = await _authHeaders;
      final res = await http.get(Uri.parse('$base/incidents'), headers: headers).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body) as List;
        return list.map((i) => Map<String, dynamic>.from(i as Map)).toList();
      }
    } catch (e) {
      debugPrint('[ContactsRepo] Failed to fetch incidents from backend: $e');
    }
    return _localIncidents;
  }

  Future<void> syncFromBackend() async {
    try {
      final base = await _baseUrl;
      final res = await http.get(Uri.parse('$base/contacts')).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body) as List;
        final fetched = data.map((item) => Contact.fromMap(item as Map<String, dynamic>)).toList();
        if (_db != null) {
          for (final c in fetched) {
            await _db!.insert('contacts', c.toMap(),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await _loadFromDb();
        } else {
          _contacts = fetched;
          _saveToWebStorage();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[ContactsRepo] syncFromBackend error: $e');
    }
  }

  // ── Backend Sync (best-effort, fire-and-forget) ──────────────────────────

  Future<String> get _baseUrl async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(AppConstants.prefKeyBackendUrl);
    if (saved != null && saved.isNotEmpty) return saved;
    return AppConstants.resolveBackendUrl();
  }

  /// Returns auth headers for backend requests.
  /// In DEBUG mode the backend bypasses auth, but sending the header is harmless.
  Future<Map<String, String>> get _authHeaders async {
    return {
      'Content-Type': 'application/json',
      'X-API-Key': 'changeme-dev-key',
    };
  }

  void _syncContactToBackend(Contact contact) async {
    try {
      final base = await _baseUrl;
      final headers = await _authHeaders;
      await http
          .post(
            Uri.parse('$base/contacts'),
            headers: headers,
            body: jsonEncode(contact.toMap()),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[ContactsRepo] Backend sync failed (non-critical): $e');
    }
  }

  void _deleteContactOnBackend(String id) async {
    try {
      final base = await _baseUrl;
      final headers = await _authHeaders;
      await http
          .delete(Uri.parse('$base/contacts/$id'), headers: headers)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[ContactsRepo] Backend delete failed (non-critical): $e');
    }
  }

  void syncIncidentToBackend(Map<String, dynamic> incident) async {
    try {
      final base = await _baseUrl;
      final headers = await _authHeaders;
      final payload = Map<String, dynamic>.from(incident);
      payload['emergencyCallPlaced'] =
          payload['emergencyCallPlaced'] == true || payload['emergencyCallPlaced'] == 1;
      await http
          .post(
            Uri.parse('$base/incidents'),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[ContactsRepo] Incident sync failed (non-critical): $e');
    }
  }
}
