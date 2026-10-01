import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/contact.dart';
import '../contacts/contacts_repository.dart';

class ManageContactsScreen extends StatefulWidget {
  const ManageContactsScreen({super.key});

  @override
  State<ManageContactsScreen> createState() => _ManageContactsScreenState();
}

class _ManageContactsScreenState extends State<ManageContactsScreen> {
  void _showAddEditDialog({
    required int slotIndex,
    Contact? existing,
  }) {
    final isRequired = slotIndex < 2;
    final slotTitle = slotIndex == 0
        ? 'Primary Contact (Required)'
        : slotIndex == 1
            ? 'Secondary Contact (Required)'
            : 'Backup Contact (Optional)';

    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final relationCtrl = TextEditingController(text: existing?.relation ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isRequired
                        ? const Color(0xFFFF3B30).withOpacity(0.18)
                        : const Color(0xFF0A84FF).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isRequired
                          ? const Color(0xFFFF3B30).withOpacity(0.5)
                          : const Color(0xFF0A84FF).withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    isRequired ? 'REQUIRED' : 'OPTIONAL',
                    style: TextStyle(
                      color: isRequired
                          ? const Color(0xFFFF453A)
                          : const Color(0xFF64D2FF),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Slot ${slotIndex + 1}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 13,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              slotTitle,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A84FF).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF0A84FF).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active_outlined, color: Color(0xFF0A84FF), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Emergency alerts with live GPS location will be emailed, and automated AI voice calls will be placed to the phone number.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 11,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _field(
                  'Full Name',
                  nameCtrl,
                  TextInputType.name,
                  prefixIcon: Icons.person_outline,
                  isRequired: isRequired,
                ),
                const SizedBox(height: 12),
                _field(
                  'Email Address',
                  emailCtrl,
                  TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                  isRequired: isRequired,
                  validator: (v) {
                    final trimmed = v?.trim() ?? '';
                    if (isRequired && trimmed.isEmpty) {
                      return 'Email is required for fixed contacts';
                    }
                    if (trimmed.isNotEmpty) {
                      final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmed);
                      if (!valid) return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _field(
                  'Phone Number (Optional — for AI Voice Call)',
                  phoneCtrl,
                  TextInputType.phone,
                  prefixIcon: Icons.phone_outlined,
                  isRequired: false,
                ),
                const SizedBox(height: 12),
                _field(
                  'Relationship (e.g. Mother, Spouse, Friend)',
                  relationCtrl,
                  TextInputType.text,
                  prefixIcon: Icons.people_outline,
                  isRequired: false,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey, fontFamily: 'Inter')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A84FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final repo = context.read<ContactsRepository>();
              final name = nameCtrl.text.trim();
              final email = emailCtrl.text.trim().toLowerCase();
              final phone = phoneCtrl.text.trim();
              final relation = relationCtrl.text.trim();

              if (!isRequired && email.isEmpty && name.isEmpty && phone.isEmpty) {
                // Optional slot left empty
                if (existing != null) {
                  await repo.deleteContact(existing.id);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                return;
              }

              if (existing == null) {
                await repo.addContact(Contact.create(
                  name: name.isEmpty ? 'Emergency Contact ${slotIndex + 1}' : name,
                  email: email,
                  phone: phone,
                  relation: relation.isEmpty ? (isRequired ? 'Primary' : 'Backup') : relation,
                ));
              } else {
                await repo.updateContact(existing.copyWith(
                  name: name,
                  email: email,
                  phone: phone,
                  relation: relation,
                ));
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(existing == null ? 'Save Contact' : 'Update Contact',
                style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl,
    TextInputType type, {
    required bool isRequired,
    IconData? prefixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      validator: validator ??
          (v) {
            if (isRequired && (v?.trim().isEmpty ?? true)) {
              return 'This field is required';
            }
            return null;
          },
      style: const TextStyle(color: Colors.white, fontFamily: 'Inter'),
      decoration: InputDecoration(
        labelText: isRequired ? '$label *' : label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: Colors.white38, size: 20)
            : null,
        filled: true,
        fillColor: const Color(0xFF2C2C2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0A84FF), width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: const Text(
          'Emergency Contacts',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Consumer<ContactsRepository>(
        builder: (ctx, repo, _) {
          final contacts = repo.contacts;
          final requiredCount = contacts.length >= 2 ? 2 : contacts.length;
          final isArmed = contacts.length >= 2;

          Contact? contact1 = contacts.isNotEmpty ? contacts[0] : null;
          Contact? contact2 = contacts.length > 1 ? contacts[1] : null;
          Contact? contact3 = contacts.length > 2 ? contacts[2] : null;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              // ── System Readiness Banner ──────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isArmed
                      ? const Color(0xFF30D158).withOpacity(0.12)
                      : const Color(0xFFFF9F0A).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isArmed
                        ? const Color(0xFF30D158).withOpacity(0.35)
                        : const Color(0xFFFF9F0A).withOpacity(0.4),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isArmed ? Icons.check_circle : Icons.warning_amber_rounded,
                      color: isArmed
                          ? const Color(0xFF30D158)
                          : const Color(0xFFFF9F0A),
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isArmed
                                ? 'Auto-Emergency Response Active'
                                : 'Setup Incomplete (2 Contacts Required)',
                            style: TextStyle(
                              color: isArmed
                                  ? const Color(0xFF30D158)
                                  : const Color(0xFFFF9F0A),
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Inter',
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isArmed
                                ? 'Your 2 required contacts are configured. On crash detection, all configured contacts will receive email alerts with live GPS coordinates.'
                                : 'Please configure both Contact 1 and Contact 2 ($requiredCount/2 set). Contact 3 is optional.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontFamily: 'Inter',
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Section Title ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: Color(0xFF0A84FF), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'CONFIGURED CONTACTS (${contacts.length}/3)',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Slot 1: Primary (Required) ──────────────────────────────
              _buildSlotCard(
                slotIndex: 0,
                title: 'Contact 1 — Primary Emergency Contact',
                isRequired: true,
                contact: contact1,
                repo: repo,
              ),

              const SizedBox(height: 12),

              // ── Slot 2: Secondary (Required) ────────────────────────────
              _buildSlotCard(
                slotIndex: 1,
                title: 'Contact 2 — Secondary Emergency Contact',
                isRequired: true,
                contact: contact2,
                repo: repo,
                enabled: contact1 != null,
                disabledHint: 'Set Contact 1 first',
              ),

              const SizedBox(height: 12),

              // ── Slot 3: Tertiary (Optional) ─────────────────────────────
              _buildSlotCard(
                slotIndex: 2,
                title: 'Contact 3 — Backup Contact',
                isRequired: false,
                contact: contact3,
                repo: repo,
                enabled: contact2 != null,
                disabledHint: 'Set Contact 1 & 2 first',
              ),

              const SizedBox(height: 24),

              // ── Info Card ────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF2C2C2E)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.white38, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Emails are sent directly from your dedicated Gmail address with zero third-party tracking or costs.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 12,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSlotCard({
    required int slotIndex,
    required String title,
    required bool isRequired,
    required Contact? contact,
    required ContactsRepository repo,
    bool enabled = true,
    String? disabledHint,
  }) {
    final isConfigured = contact != null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isConfigured
              ? (isRequired
                  ? const Color(0xFF30D158).withOpacity(0.4)
                  : const Color(0xFF0A84FF).withOpacity(0.4))
              : (isRequired
                  ? const Color(0xFFFF453A).withOpacity(0.3)
                  : const Color(0xFF38383A)),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF252528),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isRequired
                        ? const Color(0xFFFF3B30).withOpacity(0.2)
                        : const Color(0xFF0A84FF).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    isRequired ? 'REQUIRED' : 'OPTIONAL',
                    style: TextStyle(
                      color: isRequired
                          ? const Color(0xFFFF453A)
                          : const Color(0xFF64D2FF),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: isConfigured
                ? Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFF0A84FF).withOpacity(0.18),
                        child: Text(
                          contact.name.isNotEmpty
                              ? contact.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Color(0xFF0A84FF),
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              contact.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                fontFamily: 'Inter',
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.email_outlined,
                                    color: Colors.white38, size: 13),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    contact.email,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.65),
                                      fontSize: 12,
                                      fontFamily: 'Inter',
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (contact.phone.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.phone_outlined,
                                      color: Color(0xFF34C759), size: 13),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      contact.phone,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.65),
                                        fontSize: 12,
                                        fontFamily: 'Inter',
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (contact.relation.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2C2C2E),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  contact.relation,
                                  style: TextStyle(
                                    color: const Color(0xFF0A84FF).withOpacity(0.9),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            color: Colors.white54, size: 20),
                        tooltip: 'Edit contact',
                        onPressed: () => _showAddEditDialog(
                          slotIndex: slotIndex,
                          existing: contact,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Color(0xFFFF453A), size: 20),
                        tooltip: 'Remove contact',
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (d) => AlertDialog(
                              backgroundColor: const Color(0xFF1C1C1E),
                              title: const Text('Remove Contact',
                                  style: TextStyle(color: Colors.white, fontFamily: 'Inter')),
                              content: Text(
                                'Remove ${contact.name} from emergency contacts?',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontFamily: 'Inter'),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(d, false),
                                  child: const Text('Cancel',
                                      style: TextStyle(color: Colors.grey)),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF3B30),
                                  ),
                                  onPressed: () => Navigator.pop(d, true),
                                  child: const Text('Remove',
                                      style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            repo.deleteContact(contact.id);
                          }
                        },
                      ),
                    ],
                  )
                : InkWell(
                    onTap: enabled
                        ? () => _showAddEditDialog(slotIndex: slotIndex)
                        : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: enabled
                            ? const Color(0xFF2C2C2E).withOpacity(0.6)
                            : const Color(0xFF242426).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: enabled
                              ? (isRequired
                                  ? const Color(0xFFFF453A).withOpacity(0.4)
                                  : const Color(0xFF0A84FF).withOpacity(0.4))
                              : Colors.white12,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            enabled ? Icons.add_circle_outline : Icons.lock_outline,
                            color: enabled
                                ? (isRequired
                                    ? const Color(0xFFFF453A)
                                    : const Color(0xFF0A84FF))
                                : Colors.white24,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            enabled
                                ? (isRequired
                                    ? 'Add Contact (Required)'
                                    : 'Add Contact (Optional)')
                                : (disabledHint ?? 'Not Available'),
                            style: TextStyle(
                              color: enabled
                                  ? Colors.white
                                  : Colors.white30,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
