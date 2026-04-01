// lib/presentation/screens/professional/booking_requests_professional.dart
//
// BookingRequestsScreen — Professional's incoming open booking requests.
//
// OPEN-BOOKING MODEL changes:
//   • "bookings" prop now contains OPEN (unassigned) requests, not all bookings.
//   • onDecline now dismisses the request from this pro's view only —
//     the booking stays open for other pros (it is NOT cancelled in the DB).
//   • onAccept calls claimBooking() via main.dart — first-accept-wins.
//   • Decline button label changed to "Skip" to reflect that the job is not
//     being cancelled, just dismissed from this pro's list.
//   • All prop names, types, and widget structure are unchanged.
//
// DESCRIPTION / NOTES FIX:
//   • booking.description holds "problemTitle\ndescription" (joined in main.dart
//     from RequestServiceResult.problemTitle + .description).
//   • booking.notes holds only the customer's optional P.S. field.
//   • The card summary now shows the problem title (first line of description)
//     as a subtitle under the service type so handymen can instantly see what
//     the job is about without expanding the card.
//   • The expanded section now shows:
//       – Problem Title  (first line of booking.description)
//       – Description    (remaining lines of booking.description, if any)
//       – Location, Preferred Schedule, Estimated Range (unchanged)
//       – Notes (P.S.)   (booking.notes — shown last, only if non-empty)

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/domain/entities/entities.dart';

// Local fallback catalog used when a booking does not include a price
// estimate or textual range. This mirrors the customer-side catalogue and
// helps display an estimated range for common offers.
const Map<String, List<Map<String, String>>> _localOfferCatalogue = {
  'Plumber': [
    {'title': 'Pipe Leak Repair', 'price': '₱500 – ₱2,500'},
    {'title': 'Drain Cleaning', 'price': '₱300 – ₱1,800'},
  ],
  'Electrician': [
    {'title': 'Wiring Repair', 'price': '₱600 – ₱3,000'},
    {'title': 'Outlet Installation', 'price': '₱400 – ₱1,500 per outlet'},
  ],
  'Technician': [
    {'title': 'Washer Repair', 'price': '₱500 – ₱3,500'},
    {'title': 'Dryer Repair', 'price': '₱500 – ₱3,000'},
  ],
  'Carpenter': [
    {'title': 'Cabinet Installation', 'price': '₱1,500 – ₱8,000'},
    {'title': 'Door Repair', 'price': '₱300 – ₱2,000'},
  ],
  'Masonry': [
    {'title': 'Wall Painting', 'price': '₱1,000 – ₱6,000 per room'},
    {'title': 'Ceiling Painting', 'price': '₱800 – ₱4,000 per room'},
  ],
};

String? _findOfferPriceRangeForBooking(BookingEntity booking) {
  final offers = _localOfferCatalogue[booking.serviceType];
  if (offers == null || offers.isEmpty) return null;

  final notesLower = (booking.notes ?? '').toLowerCase();
  final descLower = (booking.description ?? '').toLowerCase();

  // Prefer a specific matching offer title found in notes/description.
  for (final o in offers) {
    final title = (o['title'] ?? '').toLowerCase();
    if (title.isNotEmpty &&
        (notesLower.contains(title) || descLower.contains(title))) {
      return o['price'];
    }
  }

  // Fallback to the first offer's price range for the service type.
  return offers.first['price'];
}

// ── Description field helpers ─────────────────────────────────────────────
// booking.description stores "problemTitle\ndetailBody" (joined in main.dart).
// These helpers split that back into its two constituent parts.

/// Returns the first line of [description] as the Problem Title.
/// Returns null when [description] is null or empty.
String? _problemTitle(String? description) {
  if (description == null || description.trim().isEmpty) return null;
  final firstLine = description.split('\n').first.trim();
  return firstLine.isEmpty ? null : firstLine;
}

/// Returns everything after the first line of [description] as the detail body.
/// Returns null when there is no second line or it is empty.
String? _descriptionBody(String? description) {
  if (description == null || description.trim().isEmpty) return null;
  final lines = description.split('\n');
  if (lines.length < 2) return null;
  final body = lines.sublist(1).join('\n').trim();
  return body.isEmpty ? null : body;
}

/// Returns true when the booking is a custom/unlisted service request.
/// Reads the authoritative [BookingEntity.isCustomRequest] flag persisted
/// at booking-creation time — no heuristic guessing required.
bool _isCustomRequest(BookingEntity booking) => booking.isCustomRequest;

class BookingRequestsScreen extends StatefulWidget {
  final List<BookingEntity> bookings;
  final bool isAvailable;
  final Function(BookingEntity)? onAccept;
  final Function(BookingEntity)? onDecline;
  final Function(int)? onNavTap;
  final int currentNavIndex;
  final Future<void> Function()? onRefresh;

  const BookingRequestsScreen({
    super.key,
    this.bookings = const [],
    this.isAvailable = true,
    this.onAccept,
    this.onDecline,
    this.onNavTap,
    this.currentNavIndex = 1,
    this.onRefresh,
  });

  @override
  State<BookingRequestsScreen> createState() => _BookingRequestsScreenState();
}

class _BookingRequestsScreenState extends State<BookingRequestsScreen> {
  String? _expandedId;

  // In the open-booking model all items passed in are already pending+unassigned,
  // so we display all of them. The parent (MainApp) is responsible for
  // filtering out skipped requests centrally.
  List<BookingEntity> get _pending =>
      widget.bookings.where((b) => b.status == BookingStatus.pending).toList();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onNavTap?.call(0);
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Column(children: [
          _buildHeader(),
          if (!widget.isAvailable) _buildOfflineBanner(),
          Expanded(child: _pending.isEmpty ? _empty() : _buildList()),
        ]),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  // ── OFFLINE BANNER ────────────────────────────────────────

  Widget _buildOfflineBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B30).withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFF3B30).withOpacity(0.3)),
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFFF3B30).withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.wifi_off_rounded,
              color: Color(0xFFFF3B30), size: 22),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You\'re currently Offline',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFF3B30),
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Customers cannot find or book you. '
                'Toggle Online from your Dashboard to receive new requests.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMedium,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ]),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, end: 0);
  }

  // ── HEADER ────────────────────────────────────────────────

  Widget _buildHeader() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF082218), Color(0xFF0F3D2E)],
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Row(children: [
              GestureDetector(
                onTap: () => widget.onNavTap?.call(0),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Booking Requests',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3)),
                    Text(
                      '${_pending.length} open request${_pending.length == 1 ? '' : 's'}',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.6), fontSize: 13),
                    ),
                  ],
                ),
              ),
              Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: widget.isAvailable
                        ? const Color(0xFF34C759).withOpacity(0.18)
                        : const Color(0xFFFF3B30).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: widget.isAvailable
                          ? const Color(0xFF34C759).withOpacity(0.4)
                          : const Color(0xFFFF3B30).withOpacity(0.4),
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: widget.isAvailable
                            ? const Color(0xFF34C759)
                            : const Color(0xFFFF3B30),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      widget.isAvailable ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: widget.isAvailable
                            ? const Color(0xFF34C759)
                            : const Color(0xFFFF9090),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ]),
                ),
                if (_pending.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFFFF3B30).withOpacity(0.4)),
                    ),
                    child: Text('${_pending.length} New',
                        style: const TextStyle(
                            color: Color(0xFFFF9090),
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ]),
            ]),
          ),
        ),
      );

  Widget _buildList() => RefreshIndicator(
        onRefresh: widget.onRefresh ?? () async {},
        color: AppColors.primary,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          itemCount: _pending.length,
          itemBuilder: (ctx, i) {
            final b = _pending[i];
            final expanded = _expandedId == b.id;
            return _RequestCard(
              booking: b,
              expanded: expanded,
              isAvailable: widget.isAvailable,
              onTap: () => setState(() => _expandedId = expanded ? null : b.id),
              onAccept:
                  widget.isAvailable ? () => widget.onAccept?.call(b) : null,
              // Decline = skip/dismiss from this pro's view only (not a DB cancel)
              onDecline: () => widget.onDecline?.call(b),
            ).animate().fadeIn(delay: (i * 60).ms).slideY(begin: 0.06, end: 0);
          },
        ),
      );

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.inbox_rounded,
                  size: 52, color: AppColors.primary.withOpacity(0.4)),
            ),
            const SizedBox(height: 20),
            const Text('No open requests',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
            const SizedBox(height: 8),
            Text(
              widget.isAvailable
                  ? 'New customer requests matching your skills will appear here.'
                  : 'You\'re offline. Go online from your Dashboard to start receiving requests.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textLight, height: 1.5),
            ),
          ]),
        ),
      );

  Widget _buildBottomNav() {
    const items = [
      {'icon': Icons.dashboard_rounded, 'label': 'Dashboard'},
      {'icon': Icons.calendar_month_rounded, 'label': 'Requests'},
      {'icon': Icons.monetization_on_rounded, 'label': 'Earnings'},
      {'icon': Icons.person_rounded, 'label': 'Profile'},
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final active = i == widget.currentNavIndex;
              return GestureDetector(
                onTap: () => widget.onNavTap?.call(i),
                child: AnimatedContainer(
                  duration: 200.ms,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primary.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(items[i]['icon'] as IconData,
                        color: active ? AppColors.primary : AppColors.textLight,
                        size: 24),
                    const SizedBox(height: 4),
                    Text(items[i]['label'] as String,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w400,
                            color: active
                                ? AppColors.primary
                                : AppColors.textLight)),
                  ]),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ── Request Card (expandable) ──────────────────────────────────

class _RequestCard extends StatelessWidget {
  final BookingEntity booking;
  final bool expanded;
  final bool isAvailable;
  final VoidCallback? onTap;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  const _RequestCard({
    required this.booking,
    required this.expanded,
    required this.isAvailable,
    this.onTap,
    this.onAccept,
    this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final textualRange = _extractPriceRange(booking.notes);
    final offerRange = _findOfferPriceRangeForBooking(booking);
    final displayRange = textualRange ?? offerRange;
    final hasNumeric =
        booking.priceEstimate != null && booking.priceEstimate! > 0;
    final isCustom = _isCustomRequest(booking);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 250.ms,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: booking.isBackjob
                ? const Color(0xFF30B0C7).withOpacity(0.45)
                : isCustom
                    ? const Color(0xFFE8C060).withOpacity(0.6)
                    : expanded
                        ? AppColors.primary.withOpacity(0.3)
                        : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: booking.isBackjob
                  ? const Color(0xFF30B0C7).withOpacity(0.12)
                  : isCustom
                      ? const Color(0xFFFFB800).withOpacity(0.10)
                      : expanded
                          ? AppColors.primary.withOpacity(0.1)
                          : Colors.black.withOpacity(0.06),
              blurRadius: expanded ? 16 : 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Warranty claim banner — shown at top of card when isBackjob.
          // Immediately signals to the handyman this is a warranty request,
          // not a new paid booking, so they can prioritise and respond quickly.
          if (booking.isBackjob)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F8FB),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(children: [
                const Icon(Icons.verified_user_rounded,
                    size: 13, color: Color(0xFF1D8A9E)),
                const SizedBox(width: 7),
                const Expanded(
                  child: Text(
                    'Warranty Claim — original customer, covered at no charge',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1D8A9E)),
                  ),
                ),
              ]),
            ),
          // ── Custom / unlisted service banner — shown when the customer used
          // the free-text "Can't find what you need?" flow. Alerts the handyman
          // that this is not a catalogue service and pricing must be set on-site.
          if (!booking.isBackjob && isCustom)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF8E7),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(children: [
                const Icon(Icons.build_circle_rounded,
                    size: 13, color: Color(0xFFB07D00)),
                const SizedBox(width: 7),
                const Expanded(
                  child: Text(
                    'Custom Request — price to be assessed on-site',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB07D00)),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB800).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: const Color(0xFFE8C060), width: 1),
                  ),
                  child: const Text('Custom',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFB07D00),
                          letterSpacing: 0.2)),
                ),
              ]),
            ),
          // Summary row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.assignment_rounded,
                    color: Color(0xFFFF9500), size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // serviceTitle is the specific service (e.g. 'Drain Declogging').
                    // Fall back to serviceType if not set (older bookings).
                    Text(
                        booking.serviceTitle?.isNotEmpty == true
                            ? booking.serviceTitle!
                            : booking.serviceType,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark)),
                    const SizedBox(height: 2),
                    // Show serviceType as a secondary label when serviceTitle
                    // is present so the handyman sees both the specific service
                    // and the skill category.
                    if (booking.serviceTitle?.isNotEmpty == true) ...[
                      Text(
                        booking.serviceType,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary),
                      ),
                      const SizedBox(height: 2),
                    ] else if (_problemTitle(booking.description) != null) ...[
                      Text(
                        _problemTitle(booking.description)!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMedium),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      'Requested ${_timeAgo(booking.createdAt)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textLight),
                    ),
                  ],
                ),
              ),
              Icon(
                expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                color: AppColors.textLight,
                size: 20,
              ),
            ]),
          ),

          // Expanded details
          if (expanded) ...[
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Custom service title row ─────────────────────────────
                  // Shown when the customer used the free-text "unlisted"
                  // flow. Surfaces the exact text they typed so the handyman
                  // knows what to expect before arriving on-site.
                  if (isCustom && booking.serviceTitle != null)
                    _customServiceTitleDetailRow(booking.serviceTitle!),
                  // ── Problem Title ────────────────────────────────────────
                  // First line of booking.description (e.g. "Pipe Leak Repair").
                  if (_problemTitle(booking.description) != null)
                    _detailRow(
                      Icons.build_circle_outlined,
                      'Problem Title',
                      _problemTitle(booking.description)!,
                    ),
                  // ── Description / Detail ─────────────────────────────────
                  // Everything after the first line — the customer's free-text
                  // description of the issue from Step 2.
                  if (_descriptionBody(booking.description) != null)
                    _detailRow(
                      Icons.description_outlined,
                      'Description',
                      _descriptionBody(booking.description)!,
                    ),
                  if (booking.address != null && booking.address!.isNotEmpty)
                    _detailRow(Icons.location_on_outlined, 'Location',
                        booking.address!),
                  if (booking.notes != null && booking.notes!.isNotEmpty)
                    // Avoid showing a duplicate "Price Range" line in Notes
                    // when we already surface the estimated range/rate below.
                    _detailRow(
                      Icons.sticky_note_2_outlined,
                      'Notes (P.S.)',
                      _stripPriceRangeFromNotes(
                        booking.notes!,
                        // Hide the inline Price Range when we'll show any
                        // estimated pricing (textual range, offer fallback,
                        // or numeric rate).
                        hideIfRangeShown: displayRange != null || hasNumeric,
                      ),
                    ),
                  // Show date + time; falls back to date-only if time is midnight
                  _detailRow(
                    Icons.calendar_today_outlined,
                    'Preferred Schedule',
                    _formatSchedule(booking.scheduledDate),
                  ),
                  // Display estimated pricing: range (textual or offer) or numeric rate.
                  // For custom requests, show an on-site assessment note instead.
                  if (isCustom)
                    _detailRow(
                      Icons.payments_outlined,
                      'Pricing',
                      'To be assessed on-site — you set the price during assessment',
                    )
                  else if (displayRange != null)
                    _detailRow(Icons.payments_outlined, 'Estimated Range',
                        displayRange)
                  else if (hasNumeric)
                    _detailRow(Icons.payments_outlined, 'Estimated Rate',
                        '₱${booking.priceEstimate!.toStringAsFixed(0)}/hr'),
                ],
              ),
            ),
          ],

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(children: [
              if (!isAvailable)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFFFF3B30).withOpacity(0.2)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_off_rounded,
                            size: 13, color: Color(0xFFFF3B30)),
                        SizedBox(width: 6),
                        Text(
                          'Go Online to accept requests',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFF3B30)),
                        ),
                      ],
                    ),
                  ),
                ),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDecline,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFAAAAAA)),
                      foregroundColor: AppColors.textMedium,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    // "Skip" instead of "Decline" — this does NOT cancel the
                    // booking, it only removes it from this pro's local view.
                    child: const Text('Skip',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAvailable
                          ? (booking.isBackjob
                              ? const Color(0xFF1D8A9E)
                              : AppColors.primary)
                          : Colors.grey.shade400,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: Text(
                        booking.isBackjob ? 'Confirm Warranty' : 'Accept',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 15, color: AppColors.textLight),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textDark)),
            ),
          ]),
        ]),
      );

  /// Styled detail row for the customer's free-text custom service title.
  /// Includes an inline amber "Custom" pill so the handyman immediately
  /// sees this is not a catalogue entry, even when reading quickly.
  Widget _customServiceTitleDetailRow(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.label_important_rounded,
              size: 15, color: Color(0xFFB07D00)),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Requested Service',
                style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFFAA8800),
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark)),
              ),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB800).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE8C060), width: 1),
                ),
                child: const Text('Custom',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFB07D00),
                        letterSpacing: 0.2)),
              ),
            ]),
          ]),
        ]),
      );

  /// Formats the customer's preferred schedule as date + time.
  /// If the time is exactly midnight (00:00) it shows date only, since older
  /// bookings may not carry a meaningful time component.
  String _formatSchedule(DateTime dt) {
    final local = dt.toLocal();
    final datePart = DateFormat('MMM d, yyyy').format(local);
    if (local.hour == 0 && local.minute == 0) return datePart;
    final timePart = DateFormat('h:mm a').format(local);
    return '$datePart · $timePart';
  }

  String? _extractPriceRange(String? notes) {
    if (notes == null) return null;
    final m =
        RegExp(r'^Price Range:\s*(.+)\$', multiLine: true, caseSensitive: false)
            .firstMatch(notes);
    if (m != null) return m.group(1)?.trim();
    return null;
  }

  /// Removes an inline "Price Range: ..." line from `notes` when the
  /// estimated range/rate is shown separately to avoid duplication.
  String _stripPriceRangeFromNotes(String notes,
      {required bool hideIfRangeShown}) {
    if (!hideIfRangeShown) return notes;
    // Remove any line that contains "Price Range:" (case-insensitive).
    final cleaned = notes.replaceAll(
      RegExp(r'^.*Price Range:.*(?:\r?\n)?',
          multiLine: true, caseSensitive: false),
      '',
    );
    return cleaned.trim();
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt).abs();
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
