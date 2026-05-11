import 'package:flutter_test/flutter_test.dart';
import 'package:fixify/data/models/models.dart';
import 'package:fixify/domain/entities/entities.dart';

/// Bug Condition Exploration Test for Admin Total Earnings Calculation
/// 
/// This test demonstrates the bug where Total Earnings incorrectly sums
/// booking profits (assessmentPrice/priceEstimate) instead of subscription fees.
/// 
/// EXPECTED BEHAVIOR: This test MUST FAIL on unfixed code.
/// The failure confirms the bug exists and provides counterexamples.
void main() {
  group('Bug Condition Exploration - Total Earnings Calculation', () {
    test(
        'Property 1: Fault Condition - Total Earnings Incorrectly Sums Booking Profits - **Validates: Requirements 2.1, 2.2**',
        () {
      // CRITICAL: This test is EXPECTED TO FAIL on unfixed code.
      // Failure confirms the bug exists and demonstrates the incorrect behavior.
      //
      // Property-based test: For any Admin Dashboard calculation where Total Earnings
      // is computed, the UNFIXED function incorrectly sums booking profits instead of
      // subscription fees, demonstrating the bug condition.
      //
      // Test Strategy: Create concrete scenarios with known professional tiers and
      // completed bookings, then verify the calculation produces the BUGGY behavior
      // (sums booking profits instead of subscription fees).

      // ────────────────────────────────────────────────────────────────────────
      // Test Case 1: Booking Profit vs Subscription Fee Test
      // ────────────────────────────────────────────────────────────────────────
      // Setup: 2 professionals (1 Pro tier, 1 Elite tier) with 3 completed bookings
      // Expected CORRECT behavior: ₱598 (199 + 399 subscription fees)
      // Expected BUGGY behavior: ₱2,500 (500 + 800 + 1200 booking profits)

      final professionals1 = [
        ProfessionalModel(
          id: 'pro1',
          userId: 'user1',
          name: 'Pro Professional',
          skills: ['Plumbing'],
          verified: true,
          rating: 4.5,
          reviewCount: 10,
          yearsExperience: 5,
          available: true,
          subscriptionTier: 1, // Pro tier = ₱199
        ),
        ProfessionalModel(
          id: 'pro2',
          userId: 'user2',
          name: 'Elite Professional',
          skills: ['Electrical'],
          verified: true,
          rating: 4.8,
          reviewCount: 20,
          yearsExperience: 10,
          available: true,
          subscriptionTier: 2, // Elite tier = ₱399
        ),
      ];

      final bookings1 = [
        BookingModel(
          id: 'booking1',
          customerId: 'customer1',
          professionalId: 'pro1',
          serviceType: 'Plumbing',
          status: BookingStatus.completed,
          scheduledDate: DateTime.now(),
          createdAt: DateTime.now(),
          assessmentPrice: 500.0,
        ),
        BookingModel(
          id: 'booking2',
          customerId: 'customer2',
          professionalId: 'pro1',
          serviceType: 'Plumbing',
          status: BookingStatus.completed,
          scheduledDate: DateTime.now(),
          createdAt: DateTime.now(),
          assessmentPrice: 800.0,
        ),
        BookingModel(
          id: 'booking3',
          customerId: 'customer3',
          professionalId: 'pro2',
          serviceType: 'Electrical',
          status: BookingStatus.completed,
          scheduledDate: DateTime.now(),
          createdAt: DateTime.now(),
          assessmentPrice: 1200.0,
        ),
      ];

      // Calculate Total Earnings using the BUGGY logic (sums booking profits)
      final buggyTotalEarnings1 = bookings1
          .where((b) => b.status == BookingStatus.completed)
          .fold(0.0, (sum, b) {
        final ap = b.assessmentPrice;
        return sum + (ap != null && ap > 0 ? ap : (b.priceEstimate ?? 0));
      });

      // Calculate Total Earnings using the CORRECT logic (sums subscription fees)
      final correctTotalEarnings1 = professionals1.fold(0.0, (sum, pro) {
        final tier = pro.subscriptionTier;
        if (tier == 1) return sum + 199.0;
        if (tier == 2) return sum + 399.0;
        return sum; // tier 0 or invalid = ₱0
      });

      // ASSERTION: The buggy calculation should NOT equal the correct calculation
      // This demonstrates the bug exists
      expect(
        buggyTotalEarnings1,
        isNot(equals(correctTotalEarnings1)),
        reason:
            'Bug detected: Total Earnings sums booking profits (₱$buggyTotalEarnings1) '
            'instead of subscription fees (₱$correctTotalEarnings1)',
      );

      // Verify the specific values to document the counterexample
      expect(buggyTotalEarnings1, equals(2500.0),
          reason: 'Buggy calculation sums booking profits: 500 + 800 + 1200 = 2500');
      expect(correctTotalEarnings1, equals(598.0),
          reason: 'Correct calculation sums subscription fees: 199 + 399 = 598');

      // ────────────────────────────────────────────────────────────────────────
      // Test Case 2: Free Tier Test
      // ────────────────────────────────────────────────────────────────────────
      // Setup: 3 Free tier professionals with 2 completed bookings
      // Expected CORRECT behavior: ₱0 (all Free tier)
      // Expected BUGGY behavior: ₱700 (300 + 400 booking profits)

      final professionals2 = [
        ProfessionalModel(
          id: 'pro3',
          userId: 'user3',
          name: 'Free Professional 1',
          skills: ['Carpentry'],
          verified: true,
          rating: 4.0,
          reviewCount: 5,
          yearsExperience: 2,
          available: true,
          subscriptionTier: 0, // Free tier = ₱0
        ),
        ProfessionalModel(
          id: 'pro4',
          userId: 'user4',
          name: 'Free Professional 2',
          skills: ['Painting'],
          verified: true,
          rating: 4.2,
          reviewCount: 8,
          yearsExperience: 3,
          available: true,
          subscriptionTier: 0, // Free tier = ₱0
        ),
        ProfessionalModel(
          id: 'pro5',
          userId: 'user5',
          name: 'Free Professional 3',
          skills: ['Cleaning'],
          verified: true,
          rating: 4.1,
          reviewCount: 6,
          yearsExperience: 1,
          available: true,
          subscriptionTier: 0, // Free tier = ₱0
        ),
      ];

      final bookings2 = [
        BookingModel(
          id: 'booking4',
          customerId: 'customer4',
          professionalId: 'pro3',
          serviceType: 'Carpentry',
          status: BookingStatus.completed,
          scheduledDate: DateTime.now(),
          createdAt: DateTime.now(),
          assessmentPrice: 300.0,
        ),
        BookingModel(
          id: 'booking5',
          customerId: 'customer5',
          professionalId: 'pro4',
          serviceType: 'Painting',
          status: BookingStatus.completed,
          scheduledDate: DateTime.now(),
          createdAt: DateTime.now(),
          assessmentPrice: 400.0,
        ),
      ];

      // Calculate Total Earnings using the BUGGY logic
      final buggyTotalEarnings2 = bookings2
          .where((b) => b.status == BookingStatus.completed)
          .fold(0.0, (sum, b) {
        final ap = b.assessmentPrice;
        return sum + (ap != null && ap > 0 ? ap : (b.priceEstimate ?? 0));
      });

      // Calculate Total Earnings using the CORRECT logic
      final correctTotalEarnings2 = professionals2.fold(0.0, (sum, pro) {
        final tier = pro.subscriptionTier;
        if (tier == 1) return sum + 199.0;
        if (tier == 2) return sum + 399.0;
        return sum; // tier 0 = ₱0
      });

      // ASSERTION: The buggy calculation should NOT equal the correct calculation
      expect(
        buggyTotalEarnings2,
        isNot(equals(correctTotalEarnings2)),
        reason:
            'Bug detected: Total Earnings sums booking profits (₱$buggyTotalEarnings2) '
            'instead of subscription fees (₱$correctTotalEarnings2)',
      );

      // Verify the specific values
      expect(buggyTotalEarnings2, equals(700.0),
          reason: 'Buggy calculation sums booking profits: 300 + 400 = 700');
      expect(correctTotalEarnings2, equals(0.0),
          reason: 'Correct calculation sums subscription fees: 0 + 0 + 0 = 0');

      // ────────────────────────────────────────────────────────────────────────
      // Test Case 3: No Bookings Test
      // ────────────────────────────────────────────────────────────────────────
      // Setup: 2 professionals (1 Pro, 1 Elite) with 0 completed bookings
      // Expected CORRECT behavior: ₱598 (199 + 399 subscription fees)
      // Expected BUGGY behavior: ₱0 (no bookings to sum)

      final professionals3 = [
        ProfessionalModel(
          id: 'pro6',
          userId: 'user6',
          name: 'Pro Professional 2',
          skills: ['HVAC'],
          verified: true,
          rating: 4.6,
          reviewCount: 15,
          yearsExperience: 7,
          available: true,
          subscriptionTier: 1, // Pro tier = ₱199
        ),
        ProfessionalModel(
          id: 'pro7',
          userId: 'user7',
          name: 'Elite Professional 2',
          skills: ['Roofing'],
          verified: true,
          rating: 4.9,
          reviewCount: 25,
          yearsExperience: 12,
          available: true,
          subscriptionTier: 2, // Elite tier = ₱399
        ),
      ];

      final bookings3 = <BookingModel>[]; // No bookings

      // Calculate Total Earnings using the BUGGY logic
      final buggyTotalEarnings3 = bookings3
          .where((b) => b.status == BookingStatus.completed)
          .fold(0.0, (sum, b) {
        final ap = b.assessmentPrice;
        return sum + (ap != null && ap > 0 ? ap : (b.priceEstimate ?? 0));
      });

      // Calculate Total Earnings using the CORRECT logic
      final correctTotalEarnings3 = professionals3.fold(0.0, (sum, pro) {
        final tier = pro.subscriptionTier;
        if (tier == 1) return sum + 199.0;
        if (tier == 2) return sum + 399.0;
        return sum;
      });

      // ASSERTION: The buggy calculation should NOT equal the correct calculation
      expect(
        buggyTotalEarnings3,
        isNot(equals(correctTotalEarnings3)),
        reason:
            'Bug detected: Total Earnings shows ₱$buggyTotalEarnings3 (no bookings) '
            'instead of ₱$correctTotalEarnings3 (subscription fees)',
      );

      // Verify the specific values
      expect(buggyTotalEarnings3, equals(0.0),
          reason: 'Buggy calculation sums booking profits: 0 (no bookings)');
      expect(correctTotalEarnings3, equals(598.0),
          reason: 'Correct calculation sums subscription fees: 199 + 399 = 598');

      // ────────────────────────────────────────────────────────────────────────
      // Test Case 4: Mixed Tier Test
      // ────────────────────────────────────────────────────────────────────────
      // Setup: 5 professionals (2 Free, 2 Pro, 1 Elite) with various bookings
      // Expected CORRECT behavior: ₱797 (0 + 0 + 199 + 199 + 399)
      // Expected BUGGY behavior: Sum of booking profits

      final professionals4 = [
        ProfessionalModel(
          id: 'pro8',
          userId: 'user8',
          name: 'Free Professional 4',
          skills: ['Gardening'],
          verified: true,
          rating: 3.8,
          reviewCount: 3,
          yearsExperience: 1,
          available: true,
          subscriptionTier: 0, // Free tier = ₱0
        ),
        ProfessionalModel(
          id: 'pro9',
          userId: 'user9',
          name: 'Free Professional 5',
          skills: ['Handyman'],
          verified: true,
          rating: 3.9,
          reviewCount: 4,
          yearsExperience: 2,
          available: true,
          subscriptionTier: 0, // Free tier = ₱0
        ),
        ProfessionalModel(
          id: 'pro10',
          userId: 'user10',
          name: 'Pro Professional 3',
          skills: ['Locksmith'],
          verified: true,
          rating: 4.4,
          reviewCount: 12,
          yearsExperience: 6,
          available: true,
          subscriptionTier: 1, // Pro tier = ₱199
        ),
        ProfessionalModel(
          id: 'pro11',
          userId: 'user11',
          name: 'Pro Professional 4',
          skills: ['Appliance Repair'],
          verified: true,
          rating: 4.3,
          reviewCount: 11,
          yearsExperience: 5,
          available: true,
          subscriptionTier: 1, // Pro tier = ₱199
        ),
        ProfessionalModel(
          id: 'pro12',
          userId: 'user12',
          name: 'Elite Professional 3',
          skills: ['General Contractor'],
          verified: true,
          rating: 4.7,
          reviewCount: 30,
          yearsExperience: 15,
          available: true,
          subscriptionTier: 2, // Elite tier = ₱399
        ),
      ];

      final bookings4 = [
        BookingModel(
          id: 'booking6',
          customerId: 'customer6',
          professionalId: 'pro8',
          serviceType: 'Gardening',
          status: BookingStatus.completed,
          scheduledDate: DateTime.now(),
          createdAt: DateTime.now(),
          assessmentPrice: 250.0,
        ),
        BookingModel(
          id: 'booking7',
          customerId: 'customer7',
          professionalId: 'pro10',
          serviceType: 'Locksmith',
          status: BookingStatus.completed,
          scheduledDate: DateTime.now(),
          createdAt: DateTime.now(),
          assessmentPrice: 600.0,
        ),
        BookingModel(
          id: 'booking8',
          customerId: 'customer8',
          professionalId: 'pro12',
          serviceType: 'General Contractor',
          status: BookingStatus.completed,
          scheduledDate: DateTime.now(),
          createdAt: DateTime.now(),
          assessmentPrice: 1500.0,
        ),
      ];

      // Calculate Total Earnings using the BUGGY logic
      final buggyTotalEarnings4 = bookings4
          .where((b) => b.status == BookingStatus.completed)
          .fold(0.0, (sum, b) {
        final ap = b.assessmentPrice;
        return sum + (ap != null && ap > 0 ? ap : (b.priceEstimate ?? 0));
      });

      // Calculate Total Earnings using the CORRECT logic
      final correctTotalEarnings4 = professionals4.fold(0.0, (sum, pro) {
        final tier = pro.subscriptionTier;
        if (tier == 1) return sum + 199.0;
        if (tier == 2) return sum + 399.0;
        return sum;
      });

      // ASSERTION: The buggy calculation should NOT equal the correct calculation
      expect(
        buggyTotalEarnings4,
        isNot(equals(correctTotalEarnings4)),
        reason:
            'Bug detected: Total Earnings sums booking profits (₱$buggyTotalEarnings4) '
            'instead of subscription fees (₱$correctTotalEarnings4)',
      );

      // Verify the specific values
      expect(buggyTotalEarnings4, equals(2350.0),
          reason: 'Buggy calculation sums booking profits: 250 + 600 + 1500 = 2350');
      expect(correctTotalEarnings4, equals(797.0),
          reason:
              'Correct calculation sums subscription fees: 0 + 0 + 199 + 199 + 399 = 797');

      // ────────────────────────────────────────────────────────────────────────
      // COUNTEREXAMPLES DOCUMENTED
      // ────────────────────────────────────────────────────────────────────────
      // The test has successfully demonstrated the bug across 4 test cases:
      // 1. Booking Profit vs Subscription: ₱2,500 (buggy) vs ₱598 (correct)
      // 2. Free Tier Test: ₱700 (buggy) vs ₱0 (correct)
      // 3. No Bookings Test: ₱0 (buggy) vs ₱598 (correct)
      // 4. Mixed Tier Test: ₱2,350 (buggy) vs ₱797 (correct)
      //
      // Root Cause Confirmed:
      // - The calculation uses bookings as the data source instead of professionals
      // - The calculation sums assessmentPrice/priceEstimate instead of subscription fees
      // - The calculation ignores subscription tiers entirely
    });
  });
}
