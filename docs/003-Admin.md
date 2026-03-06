# Fixify Screen API Reference

> **Convention:** Screen files are named `{role}_{screen}.dart`  
> e.g. `dashboard_customer.dart`, `profile_customer.dart`, `dashboard_professional.dart`

---

## Customer Screens

### `dashboard_customer.dart` — `CustomerDashboardScreen`

Home screen for the Homeowner (Customer) role.

#### Props

| Prop                | Type                            | Required | Description                                                                                  |
| ------------------- | ------------------------------- | -------- | -------------------------------------------------------------------------------------------- |
| `user`              | `UserEntity?`                   | No       | Logged-in user. Used for greeting and avatar initials.                                       |
| `professionals`     | `List<ProfessionalEntity>`      | No       | List of available professionals. Shown in bottom card list. Default `[]`.                    |
| `recentBookings`    | `List<BookingEntity>`           | No       | Customer's recent bookings. Shown as horizontal mini cards. Max 5 shown. Default `[]`.       |
| `onRequestService`  | `VoidCallback?`                 | No       | Called when "Request Service" CTA is tapped. Typically navigates to professional browse.     |
| `onViewBookings`    | `VoidCallback?`                 | No       | Called when "See All" is tapped on the bookings section.                                     |
| `onFilterBySkill`   | `Function(String skill)?`       | No       | Called when a service category chip is tapped. Passes the label e.g. `'Plumbing'`, `'All'`.  |
| `onProfessionalTap` | `Function(ProfessionalEntity)?` | No       | Called when a professional card is tapped. Passes the entity for profile/booking navigation. |
| `onNavTap`          | `Function(int)?`                | No       | Bottom nav tap. Index: `0=Home, 1=Bookings, 2=Support, 3=Profile`.                           |
| `currentNavIndex`   | `int`                           | No       | Active bottom nav tab. Default `0`.                                                          |

#### Internal State

- `_selectedSkill` — tracks which category chip is highlighted.

#### Service Categories (hardcoded)

`All`, `Plumbing`, `Electrical`, `Appliances`, `Carpentry`, `Painting`

---

### `profile_customer.dart` — `CustomerProfileScreen`

Profile screen for the Homeowner (Customer) role.

#### Props

| Prop               | Type            | Required | Description                                                                                                          |
| ------------------ | --------------- | -------- | -------------------------------------------------------------------------------------------------------------------- |
| `user`             | `UserEntity?`   | No       | Logged-in user. Displays name, email, phone. Avatar uses first 2 initials.                                           |
| `onBack`           | `VoidCallback?` | No       | Back button. Falls back to `Navigator.maybePop()` if null.                                                           |
| `onEditProfile`    | `VoidCallback?` | No       | Pencil icon in header. Should navigate to an edit form.                                                              |
| `onChangePassword` | `VoidCallback?` | No       | "Change Password" row tap.                                                                                           |
| `onPrivacyPolicy`  | `VoidCallback?` | No       | "Privacy Policy" row tap. Should open a webview or modal.                                                            |
| `onLogout`         | `VoidCallback?` | No       | Called after user confirms logout in the confirmation dialog. Should call `Supabase.instance.client.auth.signOut()`. |

#### Sections shown

1. **Header** — gradient, avatar with initials, name, "Homeowner" badge, back + edit buttons
2. **Account Information** — Full Name, Email, Mobile Number (from `UserEntity`)
3. **Actions** — Change Password, Privacy Policy
4. **Logout** — Red button with confirmation dialog

#### Excluded (intentionally)

- ~~Confirm Password~~ — redundant, removed per MVP spec.

---

## Shared Entities (from `entities.dart`)

### `UserEntity`

| Field            | Type            | Notes                            |
| ---------------- | --------------- | -------------------------------- |
| `id`             | `String`        | Supabase UUID                    |
| `name`           | `String`        | Display name                     |
| `email`          | `String`        | Auth email                       |
| `role`           | `String`        | `'customer'` or `'professional'` |
| `phone`          | `String?`       | Optional                         |
| `avatarUrl`      | `String?`       | Optional storage URL             |
| `createdAt`      | `DateTime`      | Account creation date            |
| `isCustomer`     | `bool` (getter) | `role == 'customer'`             |
| `isProfessional` | `bool` (getter) | `role == 'professional'`         |

### `ProfessionalEntity`

| Field             | Type           | Notes                             |
| ----------------- | -------------- | --------------------------------- |
| `id`              | `String`       | Row UUID                          |
| `userId`          | `String`       | FK → users.id                     |
| `name`            | `String`       | From joined users table           |
| `skills`          | `List<String>` | e.g. `['plumbing', 'electrical']` |
| `verified`        | `bool`         | Fixify-verified badge             |
| `rating`          | `double`       | 0.0–5.0                           |
| `reviewCount`     | `int`          | Total reviews                     |
| `priceMin/Max`    | `double?`      | Price range                       |
| `city`            | `String?`      | Service area                      |
| `bio`             | `String?`      | Professional bio                  |
| `yearsExperience` | `int`          | Years in trade                    |
| `available`       | `bool`         | Currently taking bookings         |

### `BookingEntity`

| Field            | Type                  | Notes                 |
| ---------------- | --------------------- | --------------------- |
| `id`             | `String`              | Row UUID              |
| `customerId`     | `String`              | FK → users.id         |
| `professionalId` | `String`              | FK → professionals.id |
| `serviceType`    | `String`              | e.g. `'Plumbing'`     |
| `status`         | `BookingStatus`       | See below             |
| `scheduledDate`  | `DateTime`            | Booked datetime       |
| `priceEstimate`  | `double?`             | Quoted price          |
| `address`        | `String?`             | Job site address      |
| `notes`          | `String?`             | Customer notes        |
| `professional`   | `ProfessionalEntity?` | Joined data           |
| `customer`       | `UserEntity?`         | Joined data           |

### `BookingStatus` enum

| Value        | Meaning                            |
| ------------ | ---------------------------------- |
| `pending`    | Waiting for professional to accept |
| `accepted`   | Professional accepted              |
| `inProgress` | Job started                        |
| `completed`  | Job finished                       |
| `cancelled`  | Cancelled by either party          |

---

## Naming Convention

```
lib/presentation/screens/
  customer/
    dashboard_customer.dart   ← CustomerDashboardScreen
    profile_customer.dart     ← CustomerProfileScreen
  professional/
    dashboard_professional.dart  ← ProfessionalDashboardScreen  (coming next)
    profile_professional.dart    ← ProfessionalProfileScreen     (coming next)
  auth/
    login_screen.dart         ← LoginScreen + RegisterScreen
    splash_screen.dart        ← SplashScreen
```

---

## Supabase Auth — Logout

Call this wherever `onLogout` is wired up in `main.dart`:

```dart
await Supabase.instance.client.auth.signOut();
// StreamBuilder on onAuthStateChange will auto-redirect to AuthFlow
```

---

## Professional (Handyman) Screens

### `dashboard_professional.dart` — `ProfessionalDashboardScreen`

Home dashboard for the Handyman (Professional) role.

#### Props

| Prop                   | Type                                      | Required | Description                                                                         |
| ---------------------- | ----------------------------------------- | -------- | ----------------------------------------------------------------------------------- |
| `user`                 | `UserEntity?`                             | No       | Logged-in user. Used for header name/initials.                                      |
| `professional`         | `ProfessionalEntity?`                     | No       | Pro profile. Used for skills, rating, verified badge, availability.                 |
| `bookings`             | `List<BookingEntity>`                     | No       | All bookings for this professional. Used for stats and pending badge. Default `[]`. |
| `onUpdateStatus`       | `Function(BookingEntity, BookingStatus)?` | No       | Called when pro accepts/declines/completes a booking.                               |
| `onViewRequests`       | `VoidCallback?`                           | No       | "Booking Requests" card tap + pending banner "View" tap.                            |
| `onViewHistory`        | `VoidCallback?`                           | No       | "Booking History" card tap.                                                         |
| `onViewEarnings`       | `VoidCallback?`                           | No       | "Earnings Summary" card tap.                                                        |
| `onToggleAvailability` | `Function(bool)?`                         | No       | Called when the Online/Offline switch is toggled. Passes new value.                 |
| `onNavTap`             | `Function(int)?`                          | No       | Bottom nav tap. Index: `0=Dashboard, 1=Requests, 2=Earnings, 3=Profile`.            |
| `currentNavIndex`      | `int`                                     | No       | Active nav tab. Default `0`.                                                        |

#### Internal State

- `_available` — mirrors `professional.available`, toggled by the switch.

#### Derived Stats (computed from `bookings`)

| Getter            | Description                                          |
| ----------------- | ---------------------------------------------------- |
| `_pendingCount`   | Bookings with `status == pending`                    |
| `_completedCount` | Bookings with `status == completed`                  |
| `_totalEarnings`  | Sum of `priceEstimate` for completed bookings        |
| `_completionRate` | `completed / (completed + cancelled) * 100`          |
| `_avgRating`      | From `professional.rating`                           |
| `_totalJobs`      | From `professional.reviewCount` or `_completedCount` |

---

### `profile_professional.dart` — `ProfessionalProfileScreen`

Profile screen for the Handyman (Professional) role.

#### Props

| Prop                | Type                  | Required | Description                                                                               |
| ------------------- | --------------------- | -------- | ----------------------------------------------------------------------------------------- |
| `user`              | `UserEntity?`         | No       | Logged-in user. Displays name, email, phone.                                              |
| `professional`      | `ProfessionalEntity?` | No       | Pro profile. Displays skills, experience, price range, verified status, city.             |
| `onBack`            | `VoidCallback?`       | No       | Back button. Falls back to `Navigator.maybePop()` if null.                                |
| `onEditProfile`     | `VoidCallback?`       | No       | Pencil icon in header. Navigate to edit form.                                             |
| `onChangePassword`  | `VoidCallback?`       | No       | Change Password row tap.                                                                  |
| `onServicesOffered` | `VoidCallback?`       | No       | Services Offered row tap. Should show skill management.                                   |
| `onPayoutSettings`  | `VoidCallback?`       | No       | Payout Settings row tap.                                                                  |
| `onPrivacyPolicy`   | `VoidCallback?`       | No       | Privacy Policy row tap.                                                                   |
| `onLogout`          | `VoidCallback?`       | No       | Called after user confirms logout. Should call `Supabase.instance.client.auth.signOut()`. |

#### Sections shown

1. **Header** — gradient, avatar initials, name, "Handyman" + verification badges, back + edit
2. **Personal Information** — Full Name, Mobile Number, Email, City/Address
3. **Professional Information** — Specialization, Years of Experience, Price Range, Verification Status (APPROVED/PENDING chip)
4. **Actions** — Change Password, Services Offered, Payout Settings, Privacy Policy
5. **Logout** — Red button with confirmation dialog

#### Verification Status display

- `professional.verified == true` → green **APPROVED** chip
- `professional.verified == false` → orange **PENDING** chip

---

## File Naming Convention (Full)

```
lib/presentation/screens/
  customer/
    dashboard_customer.dart     ← CustomerDashboardScreen
    profile_customer.dart       ← CustomerProfileScreen
  professional/
    dashboard_professional.dart ← ProfessionalDashboardScreen
    profile_professional.dart   ← ProfessionalProfileScreen
  admin/
    dashboard_admin.dart        ← AdminDashboardScreen       (coming next)
    profile_admin.dart          ← AdminProfileScreen          (coming next)
  auth/
    login_screen.dart           ← LoginScreen + RegisterScreen
    splash_screen.dart          ← SplashScreen
```

---

## Admin Screens

### `dashboard_admin.dart` — `AdminDashboardScreen`

Home dashboard for the Admin role.

#### Props

| Prop                  | Type             | Required | Description                                                                                          |
| --------------------- | ---------------- | -------- | ---------------------------------------------------------------------------------------------------- |
| `adminName`           | `String`         | No       | Admin display name. Used in greeting and avatar initials. Default `'Admin'`.                         |
| `pendingApprovals`    | `int`            | No       | Professionals awaiting verification. Shows red badge on bell + Handyman Approvals card. Default `0`. |
| `totalUsers`          | `int`            | No       | Total registered users on the platform. Default `0`.                                                 |
| `totalEarnings`       | `double`         | No       | Sum of all completed booking earnings platform-wide. Default `0`.                                    |
| `completedBookings`   | `int`            | No       | Total completed bookings platform-wide. Default `0`.                                                 |
| `onHandymanApprovals` | `VoidCallback?`  | No       | "Handyman Approvals" card tap.                                                                       |
| `onAnalytics`         | `VoidCallback?`  | No       | "Analytics" card tap.                                                                                |
| `onUserManagement`    | `VoidCallback?`  | No       | "User Management" card tap.                                                                          |
| `onBookingOverview`   | `VoidCallback?`  | No       | "Booking Overview" card tap.                                                                         |
| `onNavTap`            | `Function(int)?` | No       | Bottom nav tap. Index: `0=Dashboard, 1=Approvals, 2=Analytics, 3=Settings`.                          |
| `currentNavIndex`     | `int`            | No       | Active nav tab. Default `0`.                                                                         |

---

### `profile_admin.dart` — `AdminProfileScreen`

Profile screen for the Admin role.

#### Props

| Prop                 | Type            | Required | Description                                                                              |
| -------------------- | --------------- | -------- | ---------------------------------------------------------------------------------------- |
| `adminName`          | `String`        | No       | Admin display name. Avatar uses initials. Default `'Admin'`.                             |
| `adminEmail`         | `String`        | No       | Admin email address. Default `''`.                                                       |
| `adminPhone`         | `String?`       | No       | Optional phone number. Shows `'—'` if null.                                              |
| `accessLevel`        | `String`        | No       | Access level label e.g. `'SUPERADMIN'`, `'ADMIN'`. Default `'ADMIN'`.                    |
| `lastLogin`          | `DateTime?`     | No       | Last login timestamp. Shows formatted date+time, or `'Never'` if null.                   |
| `twoFactorEnabled`   | `bool`          | No       | Whether 2FA is active. Shows green "Enabled" or orange "Disabled". Default `false`.      |
| `onBack`             | `VoidCallback?` | No       | Back button. Falls back to `Navigator.maybePop()` if null.                               |
| `onEditProfile`      | `VoidCallback?` | No       | Pencil icon in header.                                                                   |
| `onActivityLogs`     | `VoidCallback?` | No       | Activity Logs row tap.                                                                   |
| `onSecuritySettings` | `VoidCallback?` | No       | Security Settings row tap.                                                               |
| `onLogout`           | `VoidCallback?` | No       | Called after logout confirmation. Should call `Supabase.instance.client.auth.signOut()`. |

#### Sections shown

1. **Header** — gold gradient avatar, name, "Super Administrator" role banner with ACTIVE badge
2. **Personal Information** — Full Name, Email, Mobile Number
3. **System Access** — Access Level (bold), Last Login, Two-Factor Auth status
4. **Actions** — Activity Logs, Security Settings
5. **Logout** — Red button with confirmation dialog

#### Excluded (intentionally)

- ~~Employee ID, Position, Department~~ — not stored in Supabase `users` table; hardcoded in reference app but unnecessary for MVP
- ~~IP Restrictions, Login History, Backup & Restore~~ — advanced features, not in MVP scope

---

## How Admin Account is Created

**Never via the app registration flow.** Always manually:

### Step 1 — Supabase Dashboard

1. Go to **Authentication → Users → Add User**
2. Enter email + password for the admin account
3. Copy the generated UUID

### Step 2 — Insert into `users` table

```sql
INSERT INTO users (id, name, email, role, created_at)
VALUES (
  '<UUID from step 1>',
  'Admin Name',
  'admin@yourdomain.com',
  'admin',
  NOW()
);
```

### Step 3 — Login in the app

The app checks `role == 'admin'` and routes to `AdminDashboardScreen` automatically.

---

## Full File Naming Convention

```
lib/presentation/screens/
  customer/
    dashboard_customer.dart       ← CustomerDashboardScreen
    profile_customer.dart         ← CustomerProfileScreen
  professional/
    dashboard_professional.dart   ← ProfessionalDashboardScreen
    profile_professional.dart     ← ProfessionalProfileScreen
  admin/
    dashboard_admin.dart          ← AdminDashboardScreen
    profile_admin.dart            ← AdminProfileScreen
  auth/
    login_screen.dart             ← LoginScreen + RegisterScreen
    splash_screen.dart            ← SplashScreen
```
