# Fixify — On-Demand Home Repair Platform

## Flutter + Supabase MVP Documentation

---

## 🏗️ Project Overview

**Fixify** is a mobile platform that connects homeowners with verified home repair professionals (plumbers, electricians, appliance technicians). Built with Flutter and Supabase, using Clean Architecture and a premium Glassmorphism design system.

---

## 📁 Folder Structure

```
fixify/
├── lib/
│   ├── main.dart                          # App entry, routing, auth state
│   ├── app.dart                           # (embedded in main.dart)
│   │
│   ├── core/
│   │   ├── constants/
│   │   │   └── supabase_config.dart       # Supabase URL, keys, table names, SQL schema
│   │   ├── theme/
│   │   │   └── app_theme.dart             # AppColors, AppTheme (Glassmorphism palette)
│   │   └── utils/                         # (extend as needed)
│   │
│   ├── domain/
│   │   └── entities/
│   │       └── entities.dart              # UserEntity, ProfessionalEntity,
│   │                                      # BookingEntity, ReviewEntity
│   │
│   ├── data/
│   │   ├── models/
│   │   │   └── models.dart                # UserModel, ProfessionalModel,
│   │   │                                  # BookingModel, ReviewModel (JSON)
│   │   └── datasources/
│   │       └── supabase_datasource.dart   # All Supabase API calls + Realtime
│   │
│   └── presentation/
│       ├── screens/
│       │   ├── shared/
│       │   │   └── splash_screen.dart     # Animated splash with gradient
│       │   ├── auth/
│       │   │   └── auth_screens.dart      # LoginScreen + RegisterScreen
│       │   ├── customer/
│       │   │   ├── home_screen.dart       # Home with categories, professionals
│       │   │   ├── booking_screens.dart   # ProfessionalProfileScreen + BookingScreen
│       │   │   └── status_review_screens.dart # BookingStatusScreen + ReviewScreen
│       │   └── professional/
│       │       └── professional_dashboard.dart # Dashboard + job management
│       └── widgets/
│           └── shared_widgets.dart        # GlassCard, StatusBadge, VerifiedBadge,
│                                          # RatingStars, ProfessionalCard, BottomNav, etc.
│
├── assets/
│   ├── images/
│   └── icons/
│
└── pubspec.yaml
```

---

## 🎨 Design System — Glassmorphism

### Color Palette

```dart
// Primary
AppColors.primary       = Color(0xFF0F3D2E)   // Deep Noble Green
AppColors.primaryLight  = Color(0xFF1A5C43)
AppColors.primaryDark   = Color(0xFF082218)
AppColors.primaryAccent = Color(0xFF2E7D5E)

// Secondary
AppColors.secondary     = Color(0xFFF5F5F3)   // Dirty White
AppColors.white         = Color(0xFFFFFFFF)

// Status
AppColors.statusPending    = Color(0xFFFF9500)  // Orange
AppColors.statusAccepted   = Color(0xFF007AFF)  // Blue
AppColors.statusInProgress = Color(0xFF5856D6)  // Purple
AppColors.statusCompleted  = Color(0xFF34C759)  // Green
AppColors.error            = Color(0xFFFF3B30)
```

### Glass Card Usage

```dart
// White glass card (default)
GlassCard(
  padding: EdgeInsets.all(20),
  borderRadius: 20,
  blur: 10,
  child: YourContent(),
)

// Dark glass card (on dark backgrounds)
PrimaryGlassCard(
  padding: EdgeInsets.all(20),
  child: YourContent(),
)
```

---

## 🗄️ Database Schema (Supabase)

### Tables

```sql
-- 1. users
CREATE TABLE public.users (
  id          UUID PRIMARY KEY REFERENCES auth.users(id),
  name        TEXT NOT NULL,
  email       TEXT NOT NULL UNIQUE,
  role        TEXT NOT NULL CHECK (role IN ('customer', 'professional')),
  phone       TEXT,
  avatar_url  TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 2. professionals
CREATE TABLE public.professionals (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL REFERENCES public.users(id),
  skills           TEXT[] NOT NULL DEFAULT '{}',
  verified         BOOLEAN DEFAULT FALSE,
  rating           DECIMAL(3,2) DEFAULT 0.0,
  review_count     INTEGER DEFAULT 0,
  price_range      TEXT,
  price_min        DECIMAL(10,2),
  price_max        DECIMAL(10,2),
  city             TEXT,
  bio              TEXT,
  years_experience INTEGER DEFAULT 0,
  available        BOOLEAN DEFAULT TRUE,
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

-- 3. bookings
CREATE TABLE public.bookings (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id     UUID NOT NULL REFERENCES public.users(id),
  professional_id UUID NOT NULL REFERENCES public.professionals(id),
  service_type    TEXT NOT NULL,
  description     TEXT,
  price_estimate  DECIMAL(10,2),
  status          TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending','accepted','in_progress','completed','cancelled')),
  scheduled_date  TIMESTAMPTZ NOT NULL,
  address         TEXT,
  notes           TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Realtime on bookings
ALTER PUBLICATION supabase_realtime ADD TABLE public.bookings;

-- 4. reviews
CREATE TABLE public.reviews (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id      UUID NOT NULL UNIQUE REFERENCES public.bookings(id),
  customer_id     UUID NOT NULL REFERENCES public.users(id),
  professional_id UUID NOT NULL REFERENCES public.professionals(id),
  rating          INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment         TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);
```

---

## ⚡ Supabase Integration

### 1. Initialize in main.dart

```dart
await Supabase.initialize(
  url: 'https://YOUR_PROJECT_ID.supabase.co',
  anonKey: 'YOUR_ANON_KEY',
);
```

### 2. Authentication

```dart
final dataSource = SupabaseDataSource(Supabase.instance.client);

// Sign up
final user = await dataSource.signUp(
  email: 'user@example.com',
  password: 'password123',
  name: 'John Doe',
  role: 'customer',
  phone: '+1234567890',
);

// Sign in
final user = await dataSource.signIn(
  email: 'user@example.com',
  password: 'password123',
);

// Listen to auth state changes
Supabase.instance.client.auth.onAuthStateChange.listen((event) {
  // Navigate based on auth state
});
```

### 3. Fetch Professionals

```dart
// All professionals
final professionals = await dataSource.getProfessionals();

// Filter by skill
final plumbers = await dataSource.getProfessionals(skill: 'plumbing');

// Filter by skill + city
final pros = await dataSource.getProfessionals(
  skill: 'electrical',
  city: 'New York',
  verified: true,
);
```

### 4. Create a Booking

```dart
final booking = await dataSource.createBooking(
  customerId: currentUser.id,
  professionalId: selectedProfessional.id,
  serviceType: 'plumbing',
  scheduledDate: DateTime(2025, 8, 15, 10, 0),
  priceEstimate: 120.0,
  address: '123 Main St, New York',
  notes: 'Kitchen sink is leaking badly',
);
```

### 5. Realtime Booking Updates

```dart
// Subscribe to a specific booking's status changes
final channel = dataSource.subscribeToBookingUpdates(
  bookingId: booking.id,
  onUpdate: (updatedBooking) {
    setState(() => _booking = updatedBooking);
    // UI automatically reflects: pending → accepted → in_progress → completed
  },
);

// Subscribe to new bookings (for professionals)
final channel = dataSource.subscribeToProfessionalBookings(
  professionalId: professional.id,
  onNewBooking: (booking) {
    setState(() => _bookings = [booking, ..._bookings]);
  },
);

// Cleanup
dataSource.unsubscribeChannel(channel);
```

### 6. Update Booking Status (Professional)

```dart
// Professional accepts a booking
await dataSource.updateBookingStatus(booking.id, BookingStatus.accepted);

// Mark job as in progress
await dataSource.updateBookingStatus(booking.id, BookingStatus.inProgress);

// Mark as completed
await dataSource.updateBookingStatus(booking.id, BookingStatus.completed);
```

### 7. Submit a Review

```dart
await dataSource.createReview(
  bookingId: completedBooking.id,
  customerId: currentUser.id,
  professionalId: completedBooking.professionalId,
  rating: 5,
  comment: 'Excellent service! Very professional and punctual.',
);
// Rating is automatically averaged via database trigger
```

---

## 📱 Screen Inventory

### Shared

| Screen   | File                 | Description                            |
| -------- | -------------------- | -------------------------------------- |
| Splash   | `splash_screen.dart` | Animated gradient + glassmorphism logo |
| Login    | `auth_screens.dart`  | Email/password + Google OAuth          |
| Register | `auth_screens.dart`  | Role selection (Customer/Professional) |

### Customer Flow

| Screen               | File                         | Description                                   |
| -------------------- | ---------------------------- | --------------------------------------------- |
| Home                 | `home_screen.dart`           | Service categories, top professionals, search |
| Professional Profile | `booking_screens.dart`       | Skills, rating, reviews, book button          |
| Booking              | `booking_screens.dart`       | Service type, date picker, price estimate     |
| Booking Status       | `status_review_screens.dart` | Realtime progress timeline                    |
| Review               | `status_review_screens.dart` | Star rating + comment                         |

### Professional Flow

| Screen         | File                          | Description                            |
| -------------- | ----------------------------- | -------------------------------------- |
| Dashboard      | `professional_dashboard.dart` | Stats, incoming bookings, filter chips |
| Job Management | `professional_dashboard.dart` | Accept/Decline/Start/Complete actions  |

---

## 🧩 UI Components

```dart
// Glass Card
GlassCard(child: ...)
PrimaryGlassCard(child: ...)  // Dark version

// Verified Badge (green gradient)
VerifiedBadge(isVerified: professional.verified)
VerifiedBadge(isVerified: true, small: true)

// Booking Status Badge
StatusBadge(status: booking.status)

// Rating Stars
RatingStars(rating: 4.5, size: 16, showLabel: true)

// Professional List Card
ProfessionalCard(professional: pro, onTap: () {})

// Service Category Chip
ServiceCategoryChip(
  label: 'Plumbing',
  icon: Icons.water_drop_rounded,
  selected: true,
  onTap: () {},
)

// Custom Text Field
FixifyTextField(
  hint: 'Enter email',
  label: 'Email Address',
  prefixIcon: Icons.email_outlined,
  validator: (v) => null,
)

// Custom Bottom Navigation
FixifyBottomNav(
  currentIndex: 0,
  onTap: (i) {},
  isProfessional: false,
)

// Loading Overlay
LoadingOverlay(
  isLoading: _isLoading,
  child: YourWidget(),
)
```

---

## 🚀 Setup Instructions

### 1. Create Supabase Project

1. Go to [supabase.com](https://supabase.com) → New Project
2. Note your **Project URL** and **Anon Key**

### 2. Run SQL Schema

In Supabase → SQL Editor, run the complete SQL from:
`lib/core/constants/supabase_config.dart` (the commented SQL block)

### 3. Configure App

In `lib/core/constants/supabase_config.dart`:

```dart
static const String supabaseUrl = 'https://YOUR_PROJECT_ID.supabase.co';
static const String supabaseAnonKey = 'YOUR_ANON_KEY_HERE';
```

### 4. Install Dependencies

```bash
flutter pub get
```

### 5. Run App

```bash
flutter run
```

---

## 📦 Dependencies

```yaml
supabase_flutter: ^2.3.4 # Supabase client + Auth + Realtime
flutter_bloc: ^8.1.5 # State management
go_router: ^13.2.0 # Navigation
google_fonts: ^6.2.1 # Inter font family
flutter_animate: ^4.5.0 # Smooth animations
flutter_rating_bar: ^4.0.1 # Star rating widget
cached_network_image: ^3.3.1 # Image loading + caching
shimmer: ^3.0.0 # Loading skeleton
get_it: ^7.7.0 # Dependency injection
dartz: ^0.10.1 # Functional programming (Either)
equatable: ^2.0.5 # Value equality
```

---

## 🔐 Row Level Security (RLS)

All tables have RLS enabled with these policies:

- **Users**: Can only view/update their own profile; customers visible to all
- **Professionals**: Anyone can view; only owner can update
- **Bookings**: Customers see their own; professionals see assigned bookings
- **Reviews**: Anyone can view; only customer who booked can write

---

## 🔄 Architecture Pattern

```
┌─────────────────────────────────────────────┐
│                PRESENTATION                   │
│  Screens → Widgets → BLoC/State              │
└────────────────────┬────────────────────────┘
                     │
┌────────────────────▼────────────────────────┐
│                  DOMAIN                       │
│  Entities → Use Cases → Repository Interface │
└────────────────────┬────────────────────────┘
                     │
┌────────────────────▼────────────────────────┐
│                   DATA                        │
│  Models (JSON) → SupabaseDataSource          │
│  Supabase Auth | DB | Realtime | Storage     │
└─────────────────────────────────────────────┘
```

---

## 🛣️ Extending the App

### Add Push Notifications

```dart
// Use Supabase Edge Functions + FCM
// Trigger on booking INSERT in Supabase
```

### Add Maps Integration

```dart
// Add google_maps_flutter
// Show professional location on booking screen
```

### Add Payments

```dart
// Integrate Stripe via Supabase Edge Functions
// stripe_flutter package for Flutter
```

### Add Image Upload

```dart
// Avatar upload
final url = await dataSource.uploadAvatar(userId, fileBytes, 'avatar.jpg');
await dataSource.updateUserProfile(userId: userId, avatarUrl: url);
```

---

_Built with Flutter 3.x + Supabase 2.x | Design: Glassmorphism + Noble Green_
