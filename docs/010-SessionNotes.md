# Fixify Session Notes

---

## Session: Booking Requests Fix + Back Button Interception

**Date:** 2026-03-06  
**Files changed:** `main.dart`, `booking_requests_professional.dart`, `booking_history_professional.dart`, `bookings_customer.dart`

### Bug Fix: Booking Requests not showing after customer submits

**Root cause:** When a professional navigates to the Requests tab (navIndex=1), the bookings list was stale — loaded once at app init and never refreshed when switching tabs. A newly submitted customer booking was stored in Supabase but the professional's in-memory `_bookings` list was never reloaded on tab switch.

**Fix (main.dart):**

- `onNavTap` in `BookingRequestsScreen` now calls `_refreshBookings()` when tapping index 1
- `onViewRequests` callback from the dashboard now calls `_refreshBookings()` after setting navIndex=1
- `ProfessionalDashboardScreen`'s `onNavTap` also calls `_refreshBookings()` when `i == 1`
- `_refreshBookings()` re-queries `getProfessionalBookings(_pro!.id)` from Supabase

### Feature: Back button no longer exits the app immediately

**Strategy:** `PopScope(canPop: false, onPopInvokedWithResult: ...)` added to every screen.

**`_MainAppState.build` (main.dart):**

- Wraps `_buildContent()` in a `PopScope`
- If `_screen != 'home'` → sets `_screen = 'home'` (navigates back within app)
- If `_navIndex != 0` → resets to home dashboard
- If already at root home → shows "Press back again to exit" SnackBar; second press within 2s calls `SystemNavigator.pop()` (double-tap to exit)

**`BookingRequestsScreen` (booking_requests_professional.dart):**

- `PopScope` wraps Scaffold; back → calls `onNavTap(0)` to go to Dashboard

**`BookingHistoryScreen` (booking_history_professional.dart):**

- `PopScope` wraps Scaffold; back → calls `onBack()` to return to Dashboard

**`CustomerBookingsScreen` (bookings_customer.dart):**

- `PopScope` wraps Scaffold; back → calls `onNavTap(0)` to go to Home

---

## Previous Session: Booking Screens + Navigation Wiring

**Date:** 2026-03-06  
**Files created/changed:** `bookings_customer.dart`, `booking_requests_professional.dart`, `booking_history_professional.dart`, `main.dart`, `dashboard_customer.dart`

### New Screens

- **CustomerBookingsScreen** — tabbed list (All/Active/Pending/Completed), tap → BookingStatusScreen
- **BookingRequestsScreen** — pending-only list for professional, Accept/Decline with expandable cards
- **BookingHistoryScreen** — accepted/ongoing/completed/cancelled for professional with Start Job / Mark Complete actions

### Navigation Wiring (main.dart)

- Customer navIndex=1 → CustomerBookingsScreen; booking card tap → BookingStatusScreen
- Professional navIndex=1 → BookingRequestsScreen
- Professional "Booking History" dashboard card → BookingHistoryScreen via `_screen='booking_history'`
- `onViewBookings` on CustomerDashboard → navIndex=1
- `onBookingTap` on CustomerDashboard mini cards → BookingStatusScreen

### Status Flow

`pending` → (accept) → `accepted` → (start) → `inProgress` → (complete) → `completed`  
`pending` → (decline) → `cancelled`  
`pending/active` → (customer cancel) → `cancelled`

---

## Previous Session: Map + Permission Crash Fix

**Date:** 2026-03-06  
**Files changed:** `requestservice_customer.dart`, `AndroidManifest.xml`, `build.gradle.kts`

- Fixed double-dialog race condition on location permission
- Deferred GoogleMap widget render until permission resolved
- Sequential permission flow with `_permCheckDone` guard
