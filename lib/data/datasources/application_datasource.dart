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

  // Joined fields
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
    required String label, // 'credential' or 'valid_id'
  }) async {
    final ext = file.path.split('.').last;
    final path =
        '$userId/${label}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage.from(bucket).upload(path, file);
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  // ── Submit a new application ───────────────────────────────
  //
  // Called by the professional after filling the apply form.
  // Uploads credential + valid ID files first, then inserts the row.

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

  // ── Get applications for a professional ───────────────────

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

  // ── Admin: approve an application ─────────────────────────
  //
  // 1. Updates application status → approved
  // 2. Adds the service_type to professional.skills
  // 3. Sets professional.verified = true

  Future<void> approveApplication(ApplicationModel app) async {
    // 1. Mark application approved
    await _client.from(_table).update({
      'status': 'approved',
      'reviewed_at': DateTime.now().toIso8601String(),
    }).eq('id', app.id);

    // 2. Fetch current skills, merge, update professional
    final proData = await _client
        .from('professionals')
        .select('skills')
        .eq('id', app.professionalId)
        .single();
    final currentSkills = List<String>.from(proData['skills'] as List? ?? []);
    final newSkill = app.serviceType.toLowerCase();
    if (!currentSkills.contains(newSkill)) currentSkills.add(newSkill);

    await _client.from('professionals').update({
      'skills': currentSkills,
      'verified': true,
      'years_experience': app.yearsExp,
      'price_min': app.priceMin,
      'bio': app.bio,
    }).eq('id', app.professionalId);
  }

  // ── Admin: reject an application ──────────────────────────

  Future<void> rejectApplication(ApplicationModel app, {String? note}) async {
    await _client.from(_table).update({
      'status': 'rejected',
      'admin_note': note,
      'reviewed_at': DateTime.now().toIso8601String(),
    }).eq('id', app.id);
  }

  // ── Realtime: subscribe to application status changes ─────
  // Used by the professional to know when admin acts.

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
          // BEFORE
          // filter: PostgresChangeFilter(
          //   type: FilterType.eq,
          //   column: 'professional_id',
          //   value: professionalId,
          // ),
          callback: (payload) {
            final updated = ApplicationModel.fromJson(payload.newRecord);
            onUpdate(updated);
          },
        )
        .subscribe();
  }
}
