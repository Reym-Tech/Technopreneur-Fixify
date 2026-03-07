# Fixify Session Notes

---

## Session: Service Offers Revamp + Book Now Flow

**Date:** 2026-03-07  
**Files created/changed:**

- `dashboard_customer.dart` (full rewrite)
- `lib/presentation/screens/customer/serviceoffers/service_detail_screen.dart` (new)
- `lib/presentation/screens/customer/serviceoffers/pipeleak.dart` (new)
- `lib/presentation/screens/customer/serviceoffers/draincleaning.dart` (new)
- `lib/presentation/screens/customer/serviceoffers/wiringrepair.dart` (new)
- `lib/presentation/screens/customer/serviceoffers/outlet.dart` (new)
- `lib/presentation/screens/customer/serviceoffers/washerrepair.dart` (new)
- `lib/presentation/screens/customer/serviceoffers/dryerrepair.dart` (new)
- `lib/presentation/screens/customer/serviceoffers/cabinetinstallation.dart` (new)
- `lib/presentation/screens/customer/serviceoffers/doorrepair.dart` (new)
- `lib/presentation/screens/customer/serviceoffers/wallpainting.dart` (new)
- `lib/presentation/screens/customer/serviceoffers/ceilingpainting.dart` (new)
- `requestservice_customer.dart` — added `initialServiceType` prop + `initState` jump to step 1

### Feature: Availability-Gated Service Offers

- `_availableCategories` computes the set of skill categories with at least one `verified && available` professional
- Service cards render normally when their category has a professional; if not, a dark overlay shows "Unavailable" — the card is visible but not tappable
- Category filter chips show a small red dot indicator when that category has no available pro
- If the entire selected category has no pros, a friendly "No [Category] professionals available" empty state replaces the card list (same design language as Top Professionals empty state)

### Feature: Service Detail Screen (`ServiceDetailScreen`)

Shared base widget used by all 10 service screens. Shows:

- Full-bleed hero image with gradient overlay + pinned app bar
- Price range and estimated duration chips
- Rich "About This Service" description
- "What's Included" checklist with animated items
- "Pro Tip" box (amber highlight) with actionable advice per service
- "Book Now" button fixed at bottom

All 10 service screens are thin wrappers that pass data into `ServiceDetailScreen`:

- Pipe Leak Repair, Drain Cleaning (Plumbing)
- Wiring Repair, Outlet Installation (Electrical)
- Washer Repair, Dryer Repair (Appliances)
- Cabinet Installation, Door Repair (Carpentry)
- Wall Painting, Ceiling Painting (Painting)

### Feature: Book Now → Pre-filled Request Service

- `CustomerDashboardScreen` has new prop `onRequestServiceWithType(String type)`
- Tapping "Book Now" on a service detail calls this with the service's category (e.g. `'Plumbing'`)
- `main.dart` stores this in `_preselectedServiceType` and passes it to `RequestServiceScreen` as `initialServiceType`
- `RequestServiceScreen` uses `initState()` to pre-set `_serviceType` and jump to step 1 (problem description), skipping the service type selection step
- After booking, `_preselectedServiceType` is cleared

### Service Catalogue (static, ready to connect to DB)

Each `_ServiceDef` has: `id`, `name`, `description`, `image`, `category`.  
The parallel `_serviceDetails` map (keyed by same id) has: `fullDesc`, `color`, `icon`, `priceRange`, `duration`, `includes[]`, `tip`.  
To connect to a database later, replace `_allServices` const list and `_serviceDetails` map with async fetches.

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

---

## Session: Service Offers — Availability Filtering + Book Now Pre-fill

**Date:** 2026-03-07  
**Files changed:** `main.dart`, `dashboard_customer.dart` (outputs already had improved logic; main.dart wiring added)

### Feature 1: Service offers only show when a professional is available

**Logic (dashboard_customer.dart — `_availableCategories` getter):**

- Iterates `widget.professionals` filtering to `verified == true && available == true`
- Reads each professional's `skills` list, normalises capitalisation, and collects unique category names
- `_hasProForCategory(category)` returns `true` if the category is in that set (or if `'All'` and any category has a pro)

**UI behaviour:**

- **Category chips**: each chip shows a small green dot if pros are available for that category; no dot if unavailable
- **Service cards**: if a service's category has no available professionals, the card shows a grey `Unavailable` overlay badge on top of the image — the service is still visible in the catalogue so customers know what exists, but they cannot book it
- **Selecting an unavailable category**: shows a friendly "No professionals available for [Category] right now" empty state with a suggestion to check back later
- **'All' filter**: mixes available and unavailable cards together so the full catalogue is always browsable

### Feature 2: "Book Now" pre-fills RequestServiceScreen

**Flow:**

1. Customer taps a service card → `_openServiceDetail()` opens `ServiceDetailScreen` via `Navigator.push`
2. `ServiceDetailScreen` shows rich content (price range, duration, what's included, pro tip)
3. Customer taps **Book Now** → `onBookNow(serviceType)` fires
4. `Navigator.of(context).pop()` closes the detail screen
5. `widget.onRequestServiceWithType?.call(type)` is called on `CustomerDashboardScreen`
6. `main.dart` `_home()` receives it via `onRequestServiceWithType:` callback
7. Sets `_preselectedServiceType = serviceType` then `_screen = 'request_service'`
8. `RequestServiceScreen` receives `initialServiceType: _preselectedServiceType` which pre-selects the service type dropdown and skips to step 1

**New state variable in `_MainAppState`:**

```dart
String? _preselectedServiceType; // cleared on back from RequestServiceScreen
```

**New prop in `CustomerDashboardScreen`:**

```dart
final Function(String serviceType)? onRequestServiceWithType;
```

### Enhanced ServiceDetailScreen content (service_detail_screen.dart, no code changes needed)

The `_serviceDetails` map inside `dashboard_customer.dart` has rich per-service content:

- Accurate Philippine price ranges (₱)
- Estimated job durations
- 5-item "What's Included" checklist per service
- Pro tips specific to each service type (e.g. "turn off main water valve before plumber arrives")
- Full-paragraph descriptions explaining why the service matters

### File structure recap

```
lib/presentation/screens/customer/serviceoffers/
  service_detail_screen.dart   ← base rich detail screen (no Navigator.push, uses onBookNow callback)
  pipeleak.dart                ← thin wrappers that pass static data + onBookNow prop
  draincleaning.dart
  wiringrepair.dart
  outlet.dart
  washerrepair.dart
  dryerrepair.dart
  cabinetinstallation.dart
  doorrepair.dart
  wallpainting.dart
  ceilingpainting.dart
```

All 10 service screens already have `onBookNow: Function(String)?` prop.
The dashboard opens them inline using `ServiceDetailScreen` directly (no per-screen class needed for the tap flow) but the named classes remain for any direct navigation elsewhere.
