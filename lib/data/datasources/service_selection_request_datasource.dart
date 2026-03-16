// lib/data/datasources/service_selection_request_datasource.dart
//
// ServiceSelectionRequestDatasource — handles all DB interactions for the
// service selection request pipeline.
//
// A "service selection request" is submitted whenever a verified professional
// toggles a service on or off in MyServicesScreen. Instead of writing directly
// to professional_services, the change is held as a pending request until an
// admin approves or rejects it.
//
// Supabase table: service_selection_requests
//   id               uuid PK default gen_random_uuid()
//   professional_id  uuid FK → professionals.id
//   service_offer_id uuid FK → service_offers.id
//   action           text  CHECK (action IN ('select','deselect'))
//   status           text  CHECK (status IN ('pending','approved','rejected'))
//                          default 'pending'
//   admin_note       text  nullable
//   submitted_at     timestamptz default now()
//   handyman_name    text  nullable   (denormalized for admin display)
//   service_name     text  nullable   (denormalized for admin display)
//   skill_type       text  nullable   (denormalized for admin display)

import 'package:supabase_flutter/supabase_flutter.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class ServiceSelectionRequestModel {
  final String id;
  final String professionalId;
  final String serviceOfferId;

  /// 'select' or 'deselect'
  final String action;

  /// 'pending' | 'approved' | 'rejected'
  final String status;

  final String? adminNote;
  final DateTime submittedAt;

  // Denormalized fields for admin display
  final String? handymanName;
  final String? serviceName;
  final String? skillType;

  const ServiceSelectionRequestModel({
    required this.id,
    required this.professionalId,
    required this.serviceOfferId,
    required this.action,
    required this.status,
    this.adminNote,
    required this.submittedAt,
    this.handymanName,
    this.serviceName,
    this.skillType,
  });

  factory ServiceSelectionRequestModel.fromJson(Map<String, dynamic> json) =>
      ServiceSelectionRequestModel(
        id: json['id'] as String? ?? '',
        professionalId: json['professional_id'] as String? ?? '',
        serviceOfferId: json['service_offer_id'] as String? ?? '',
        action: json['action'] as String? ?? 'select',
        status: json['status'] as String? ?? 'pending',
        adminNote: json['admin_note'] as String?,
        submittedAt: json['submitted_at'] != null
            ? DateTime.parse(json['submitted_at'] as String)
            : DateTime.now(),
        handymanName: json['handyman_name'] as String?,
        serviceName: json['service_name'] as String?,
        skillType: json['skill_type'] as String?,
      );

  ServiceSelectionRequestModel copyWith({String? status, String? adminNote}) =>
      ServiceSelectionRequestModel(
        id: id,
        professionalId: professionalId,
        serviceOfferId: serviceOfferId,
        action: action,
        status: status ?? this.status,
        adminNote: adminNote ?? this.adminNote,
        submittedAt: submittedAt,
        handymanName: handymanName,
        serviceName: serviceName,
        skillType: skillType,
      );
}

// ── Datasource ────────────────────────────────────────────────────────────────

class ServiceSelectionRequestDatasource {
  final SupabaseClient _client;

  const ServiceSelectionRequestDatasource(this._client);

  static const _table = 'service_selection_requests';

  // ── Professional: submit a new request ────────────────────────────────────

  /// Submits a select or deselect request for admin review.
  /// If a pending request already exists for the same pro + service, it is
  /// replaced (e.g. pro selects, then deselects before admin acts).
  Future<ServiceSelectionRequestModel> submitRequest({
    required String professionalId,
    required String serviceOfferId,
    required String action, // 'select' | 'deselect'
    String? handymanName,
    String? serviceName,
    String? skillType,
  }) async {
    // Cancel any existing pending request for this pro + service combo.
    await _client
        .from(_table)
        .delete()
        .eq('professional_id', professionalId)
        .eq('service_offer_id', serviceOfferId)
        .eq('status', 'pending');

    final row = await _client
        .from(_table)
        .insert({
          'professional_id': professionalId,
          'service_offer_id': serviceOfferId,
          'action': action,
          'status': 'pending',
          'handyman_name': handymanName,
          'service_name': serviceName,
          'skill_type': skillType,
        })
        .select()
        .single();

    return ServiceSelectionRequestModel.fromJson(row);
  }

  /// Returns all pending requests for a given professional.
  /// Used on app init to populate the pending-state indicators in
  /// MyServicesScreen without needing a full re-fetch each toggle.
  Future<List<ServiceSelectionRequestModel>> getPendingForProfessional(
      String professionalId) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('professional_id', professionalId)
        .eq('status', 'pending')
        .order('submitted_at', ascending: false);

    return (rows as List)
        .map((r) =>
            ServiceSelectionRequestModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  // ── Admin: fetch all requests ─────────────────────────────────────────────

  Future<List<ServiceSelectionRequestModel>> getAllRequests() async {
    final rows = await _client
        .from(_table)
        .select()
        .order('submitted_at', ascending: false);

    return (rows as List)
        .map((r) =>
            ServiceSelectionRequestModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  // ── Admin: approve ────────────────────────────────────────────────────────

  /// Marks the request approved. The caller (Controller in main.dart) is
  /// responsible for then writing / removing the professional_services record.
  Future<ServiceSelectionRequestModel> approveRequest(String requestId) async {
    final row = await _client
        .from(_table)
        .update({'status': 'approved'})
        .eq('id', requestId)
        .select()
        .single();

    return ServiceSelectionRequestModel.fromJson(row);
  }

  // ── Admin: reject ─────────────────────────────────────────────────────────

  Future<ServiceSelectionRequestModel> rejectRequest(
    String requestId, {
    String? adminNote,
  }) async {
    final row = await _client
        .from(_table)
        .update({
          'status': 'rejected',
          if (adminNote != null) 'admin_note': adminNote,
        })
        .eq('id', requestId)
        .select()
        .single();

    return ServiceSelectionRequestModel.fromJson(row);
  }

  // ── Realtime: subscribe to own request updates (professional side) ─────────

  /// Listens for status changes on this professional's pending requests.
  /// Fires [onUpdate] with the updated model whenever a row changes.
  RealtimeChannel subscribeToMyRequests({
    required String professionalId,
    required void Function(ServiceSelectionRequestModel) onUpdate,
  }) {
    return _client
        .channel('service_selection_requests:pro:$professionalId')
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
            final updated = ServiceSelectionRequestModel.fromJson(
                payload.newRecord as Map<String, dynamic>);
            onUpdate(updated);
          },
        )
        .subscribe();
  }
}
