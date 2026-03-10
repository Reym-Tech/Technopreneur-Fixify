// lib/data/datasources/application_datasource.dart
//
// ApplicationDataSource — handles the professional application/verification pipeline.
//
// Supabase table: professional_applications
//   id              UUID PK
//   professional_id UUID FK → professionals.id
//   user_id         UUID FK → users.id
//   service_type    TEXT    — the single skill being applied for
//   credential_url  TEXT    — TESDA cert / diploma URL (Supabase Storage)
//   valid_id_url    TEXT    — government ID URL (Supabase Storage)
//   years_exp       INT
//   price_min       DECIMAL
//   bio             TEXT
//   status          TEXT    — 'pending' | 'approved' | 'rejected'
//   admin_note      TEXT?   — rejection reason from admin
//   submitted_at    TIMESTAMPTZ
//   reviewed_at     TIMESTAMPTZ?

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fixify/data/models/models.dart';

class ApplicationModel {
  final String id;
  final String professionalId;
  final String userId;
  final String serviceType;
  final String? credentialUrl;
  final String? validIdUrl;
  final int yearsExp;
  final double? priceMin;
  final String? bio;
  final String status; // pending | approved | rejected
  final String? adminNote;
  final DateTime submittedAt;
  final DateTime? reviewedAt;

  // Joined fields (from users table)
  final String? applicantName;
  final String? applicantEmail;

  const ApplicationModel({
    required this.id,
    required this.professionalId,
    required this.userId,
    required this.serviceType,
    this.credentialUrl,
    this.validIdUrl,
    required this.yearsExp,
    this.priceMin,
    this.bio,
    required this.status,
    this.adminNote,
    required this.submittedAt,
    this.reviewedAt,
    this.applicantName,
    this.applicantEmail,
  });

  factory ApplicationModel.fromJson(Map<String, dynamic> j) {
    final user = j['users'] as Map<String, dynamic>?;
    return ApplicationModel(
      id: j['id'] as String,
      professionalId: j['professional_id'] as String,
      userId: j['user_id'] as String,
      serviceType: j['service_type'] as String,
      credentialUrl: j['credential_url'] as String?,
      validIdUrl: j['valid_id_url'] as String?,
      yearsExp: (j['years_exp'] as int?) ?? 0,
      priceMin: (j['price_min'] as num?)?.toDouble(),
      bio: j['bio'] as String?,
      status: j['status'] as String? ?? 'pending',
      adminNote: j['admin_note'] as String?,
      submittedAt: DateTime.parse(j['submitted_at'] as String),
      reviewedAt: j['reviewed_at'] != null
          ? DateTime.parse(j['reviewed_at'] as String)
          : null,
      applicantName: user?['name'] as String?,
      applicantEmail: user?['email'] as String?,
    );
  }
}

class ApplicationDataSource {
  final SupabaseClient _client;
  static const _table = 'professional_applications';
  static const _credBucket = 'credentials';
  static const _validIdBucket = 'valid_ids';

  ApplicationDataSource(this._client);

  // ── Upload file to Supabase Storage ───────────────────────

  Future<String> _uploadFile({
    required String bucket,
    required String userId,
    required File file,
    required String label,
  }) async {
    final ext = file.path.split('.').last;
    final path =
        '$userId/${label}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage.from(bucket).upload(path, file);
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  // ── Submit a new application ───────────────────────────────

  Future<ApplicationModel> submitApplication({
    required String professionalId,
    required String userId,
    required String serviceType,
    required File credentialFile,
    required File validIdFile,
    required int yearsExp,
    double? priceMin,
    String? bio,
  }) async {
    final credUrl = await _uploadFile(
        bucket: _credBucket,
        userId: userId,
        file: credentialFile,
        label: 'credential');
    final idUrl = await _uploadFile(
        bucket: _validIdBucket,
        userId: userId,
        file: validIdFile,
        label: 'valid_id');

    final data = await _client
        .from(_table)
        .insert({
          'professional_id': professionalId,
          'user_id': userId,
          'service_type': serviceType,
          'credential_url': credUrl,
          'valid_id_url': idUrl,
          'years_exp': yearsExp,
          'price_min': priceMin,
          'bio': bio,
          'status': 'pending',
          'submitted_at': DateTime.now().toIso8601String(),
        })
        .select('*, users(name, email)')
        .single();

    return ApplicationModel.fromJson(data);
  }

  // ── Professional: get their own applications ──────────────

  Future<List<ApplicationModel>> getMyApplications(
      String professionalId) async {
    final data = await _client
        .from(_table)
        .select('*, users(name, email)')
        .eq('professional_id', professionalId)
        .order('submitted_at', ascending: false);
    return (data as List).map((j) => ApplicationModel.fromJson(j)).toList();
  }

  // ── Admin: get all pending applications ───────────────────

  Future<List<ApplicationModel>> getPendingApplications() async {
    final data = await _client
        .from(_table)
        .select('*, users(name, email)')
        .eq('status', 'pending')
        .order('submitted_at', ascending: false);
    return (data as List).map((j) => ApplicationModel.fromJson(j)).toList();
  }

  // ── Admin: get all applications (all statuses) ────────────

  Future<List<ApplicationModel>> getAllApplications() async {
    final data = await _client
        .from(_table)
        .select('*, users(name, email)')
        .order('submitted_at', ascending: false);
    return (data as List).map((j) => ApplicationModel.fromJson(j)).toList();
  }

  // ── Admin: approve ─────────────────────────────────────────
  //
  // Why RPC instead of a direct .update()?
  //
  // The "professionals: update own row" RLS policy checks auth.uid() = user_id,
  // so when the admin calls a direct UPDATE the admin's uid never matches the
  // professional's user_id — Supabase silently updates 0 rows.
  //
  // The SECURITY DEFINER function `approve_professional_application` runs as the
  // DB owner (postgres role), bypassing RLS entirely, so the UPDATE always lands.
  //
  // Steps:
  //   1. Fetch current skills from professionals (SELECT is allowed for all
  //      authenticated users by the existing SELECT policy).
  //   2. Merge the new skill into the skills array.
  //   3. Call the RPC to apply the UPDATE (bypasses RLS).
  //   4. Mark the application row as approved (admin UPDATE policy allows this).

  Future<void> approveApplication(ApplicationModel app) async {
    debugPrint('[approveApplication] approving app ${app.id} '
        'for professional ${app.professionalId}');

    final newSkill = app.serviceType.toLowerCase();

    // Step 1 — Fetch current skills so we can merge without losing existing ones.
    // Falls back to empty list if the row is somehow missing (handled by RPC).
    List<String> mergedSkills = [newSkill];
    try {
      final proData = await _client
          .from('professionals')
          .select('skills')
          .eq('id', app.professionalId)
          .maybeSingle();

      if (proData != null) {
        final current = List<String>.from(proData['skills'] as List? ?? []);
        if (!current.contains(newSkill)) current.add(newSkill);
        mergedSkills = current;
      }
    } catch (e) {
      debugPrint(
          '[approveApplication] could not pre-fetch skills (non-fatal): $e');
    }

    debugPrint('[approveApplication] merged skills: $mergedSkills');

    // Step 2 — Call SECURITY DEFINER RPC to update professionals row.
    // This bypasses the "update own row" RLS policy that blocks admin updates.
    await _client.rpc('approve_professional_application', params: {
      'p_professional_id': app.professionalId,
      'p_skills': mergedSkills,
      'p_verified': true,
      'p_years_exp': app.yearsExp,
      'p_price_min': app.priceMin,
      'p_bio': app.bio,
    });

    debugPrint(
        '[approveApplication] ✅ RPC executed — professionals row updated');

    // Step 3 — Mark the application itself as approved.
    // The "Admin can update application status" policy allows this.
    await _client.from(_table).update({
      'status': 'approved',
      'reviewed_at': DateTime.now().toIso8601String(),
    }).eq('id', app.id);

    debugPrint('[approveApplication] ✅ application status set to approved');
  }

  // ── Admin: reject ──────────────────────────────────────────

  Future<void> rejectApplication(ApplicationModel app, {String? note}) async {
    await _client.from(_table).update({
      'status': 'rejected',
      'admin_note': note,
      'reviewed_at': DateTime.now().toIso8601String(),
    }).eq('id', app.id);
  }

  // ── Realtime: professional gets live status updates ───────

  RealtimeChannel subscribeToMyApplications({
    required String professionalId,
    required void Function(ApplicationModel) onUpdate,
  }) {
    return _client
        .channel('applications_$professionalId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: _table,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'professional_id',
            value: professionalId,
          ),
          callback: (payload) {
            final updated = ApplicationModel.fromJson(payload.newRecord);
            onUpdate(updated);
          },
        )
        .subscribe();
  }
}
