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
