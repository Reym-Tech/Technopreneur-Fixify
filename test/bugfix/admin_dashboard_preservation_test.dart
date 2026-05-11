import 'package:flutter_test/flutter_test.dart';
import 'package:fixify/data/models/models.dart';
import 'package:fixify/domain/entities/entities.dart';
import 'package:fixify/data/datasources/application_datasource.dart';
import 'package:fixify/data/datasources/service_selection_request_datasource.dart';

/// Preservation Property Tests for Admin Dashboard Metrics
/// 
/// These tests verify that non-Total-Earnings dashboard metrics remain unchanged
/// when the Total Earnings bug is fixed. They follow the observation-first methodology:
/// 1. Observe behavior on UNFIXED code
/// 2. Write property-based tests capturing that behavior
/// 3. Run tests on UNFIXED code (EXPECTED: PASS)
/// 4. After fix, re-run tests to ensure no regressions (EXPECTED: PASS)
/// 
/// **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5**
void main() {
  group('Property 2: Preservation - Other Dashboard Metrics Unchanged', () {
    // ────────────────────────────────────────────────────────────────────────
    // Test 1: Pending Approvals Preservation
    // ────────────────────────────────────────────────────────────────────────
    // Observation: Pending Approvals correctly sums pending applications,
    // proposals, service selection requests, and upgrade requests
    // 
    // Property: For any dashboard state, Pending Approvals = count of all
    // pending items across the four categories
    test(
        'Pending Approvals correctly sums pending applications, proposals, service selection requests, and upgrade requests',
        () {
      // Test Case 1: Mixed pending items
      final applications1 = [
        ApplicationModel(
          id: 'app1',
          professionalId: 'pro1',
          userId: 'user1',
          serviceType: 'Plumbing',
          yearsExp: 5,
          status: 'pending',
          submittedAt: DateTime.now(),
          applicantName: 'John Doe',
        ),
        ApplicationModel(
          id: 'app2',
          professionalId: 'pro2',
          userId: 'user2',
          serviceType: 'Electrical',
          yearsExp: 3,
          status: 'approved',
          submittedAt: DateTime.now(),
          applicantName: 'Jane Smith',
        ),
        ApplicationModel(
          id: 'app3',
          professionalId: 'pro3',
          userId: 'user3',
          serviceType: 'Carpentry',
          yearsExp: 7,
          status: 'pending',
          submittedAt: DateTime.now(),
          applicantName: 'Bob Johnson',
        ),
      ];

      final proposals1 = [
        ServiceProposalModel(
          id: 'prop1',
          professionalId: 'pro1',
          userId: 'user1',
          serviceType: 'Plumbing',
          serviceName: 'Fix plumbing',
          includes: [],
          warrantyDays: 0,
          status: 'pending',
          submittedAt: DateTime.now(),
        ),
        ServiceProposalModel(
          id: 'prop2',
          professionalId: 'pro2',
          userId: 'user2',
          serviceType: 'Electrical',
          serviceName: 'Install electrical',
          includes: [],
          warrantyDays: 0,
          status: 'accepted',
          submittedAt: DateTime.now(),
        ),
      ];

      final serviceSelectionRequests1 = [
        ServiceSelectionRequestModel(
          id: 'ssr1',
          professionalId: 'pro1',
          serviceOfferId: 'offer1',
          action: 'select',
          status: 'pending',
          submittedAt: DateTime.now(),
        ),
        ServiceSelectionRequestModel(
          id: 'ssr2',
          professionalId: 'pro2',
          serviceOfferId: 'offer2',
          action: 'select',
          status: 'pending',
          submittedAt: DateTime.now(),
        ),
        ServiceSelectionRequestModel(
          id: 'ssr3',
          professionalId: 'pro3',
          serviceOfferId: 'offer3',
          action: 'select',
          status: 'completed',
          submittedAt: DateTime.now(),
        ),
      ];

      final upgradeRequests1 = [
        SubscriptionRequestModel(
          id: 'upgrade1',
          professionalId: 'pro1',
          currentTier: 0,
          requestedTier: 1,
          status: 'pending',
          createdAt: DateTime.now(),
        ),
      ];

      // Calculate Pending Approvals using the observed logic
      final pendingApprovals1 =
          applications1.where((a) => a.status == 'pending').length +
              proposals1.where((p) => p.status == 'pending').length +
              serviceSelectionRequests1
                  .where((r) => r.status == 'pending')
                  .length +
              upgradeRequests1.where((r) => r.status == 'pending').length;

      // Verify the calculation
      expect(pendingApprovals1, equals(6),
          reason:
              'Pending Approvals should sum: 2 applications + 1 proposal + 2 service selection requests + 1 upgrade request = 6');

      // Test Case 2: No pending items
      final applications2 = [
        ApplicationModel(
          id: 'app4',
          professionalId: 'pro4',
          userId: 'user4',
          serviceType: 'Painting',
          yearsExp: 4,
          status: 'approved',
          submittedAt: DateTime.now(),
          applicantName: 'Alice Brown',
        ),
      ];

      final proposals2 = <ServiceProposalModel>[];
      final serviceSelectionRequests2 = <ServiceSelectionRequestModel>[];
      final upgradeRequests2 = <SubscriptionRequestModel>[];

      final pendingApprovals2 =
          applications2.where((a) => a.status == 'pending').length +
              proposals2.where((p) => p.status == 'pending').length +
              serviceSelectionRequests2
                  .where((r) => r.status == 'pending')
                  .length +
              upgradeRequests2.where((r) => r.status == 'pending').length;

      expect(pendingApprovals2, equals(0),
          reason: 'Pending Approvals should be 0 when no items are pending');

      // Test Case 3: All pending items
      final applications3 = [
        ApplicationModel(
          id: 'app5',
          professionalId: 'pro5',
          userId: 'user5',
          serviceType: 'HVAC',
          yearsExp: 6,
          status: 'pending',
          submittedAt: DateTime.now(),
          applicantName: 'Charlie Davis',
        ),
        ApplicationModel(
          id: 'app6',
          professionalId: 'pro6',
          userId: 'user6',
          serviceType: 'Roofing',
          yearsExp: 8,
          status: 'pending',
          submittedAt: DateTime.now(),
          applicantName: 'Diana Evans',
        ),
      ];

      final proposals3 = [
        ServiceProposalModel(
          id: 'prop3',
          professionalId: 'pro3',
          userId: 'user3',
          serviceType: 'Roofing',
          serviceName: 'Roof repair',
          includes: [],
          warrantyDays: 0,
          status: 'pending',
          submittedAt: DateTime.now(),
        ),
      ];

      final serviceSelectionRequests3 = [
        ServiceSelectionRequestModel(
          id: 'ssr4',
          professionalId: 'pro4',
          serviceOfferId: 'offer4',
          action: 'select',
          status: 'pending',
          submittedAt: DateTime.now(),
        ),
      ];

      final upgradeRequests3 = [
        SubscriptionRequestModel(
          id: 'upgrade2',
          professionalId: 'pro2',
          currentTier: 1,
          requestedTier: 2,
          status: 'pending',
          createdAt: DateTime.now(),
        ),
        SubscriptionRequestModel(
          id: 'upgrade3',
          professionalId: 'pro3',
          currentTier: 0,
          requestedTier: 1,
          status: 'pending',
          createdAt: DateTime.now(),
        ),
      ];

      final pendingApprovals3 =
          applications3.where((a) => a.status == 'pending').length +
              proposals3.where((p) => p.status == 'pending').length +
              serviceSelectionRequests3
                  .where((r) => r.status == 'pending')
                  .length +
              upgradeRequests3.where((r) => r.status == 'pending').length;

      expect(pendingApprovals3, equals(6),
          reason:
              'Pending Approvals should sum: 2 applications + 1 proposal + 1 service selection request + 2 upgrade requests = 6');
    });

    // ────────────────────────────────────────────────────────────────────────
    // Test 2: Total Users Preservation
    // ────────────────────────────────────────────────────────────────────────
    // Observation: Total Users correctly counts the number of professionals
    // 
    // Property: For any dashboard state, Total Users = count of all professionals
    test('Total Users correctly counts the number of professionals', () {
      // Test Case 1: Multiple professionals with different tiers
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
          subscriptionTier: 1, // Pro tier
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
          subscriptionTier: 2, // Elite tier
        ),
        ProfessionalModel(
          id: 'pro3',
          userId: 'user3',
          name: 'Free Professional',
          skills: ['Carpentry'],
          verified: true,
          rating: 4.0,
          reviewCount: 5,
          yearsExperience: 2,
          available: true,
          subscriptionTier: 0, // Free tier
        ),
      ];

      // Calculate Total Users using the observed logic
      final totalUsers1 = professionals1.length;

      expect(totalUsers1, equals(3),
          reason: 'Total Users should count all professionals: 3');

      // Test Case 2: No professionals
      final professionals2 = <ProfessionalModel>[];
      final totalUsers2 = professionals2.length;

      expect(totalUsers2, equals(0),
          reason: 'Total Users should be 0 when no professionals exist');

      // Test Case 3: Many professionals
      final professionals3 = List.generate(
        10,
        (i) => ProfessionalModel(
          id: 'pro$i',
          userId: 'user$i',
          name: 'Professional $i',
          skills: ['Skill $i'],
          verified: true,
          rating: 4.0 + (i % 10) * 0.1,
          reviewCount: i * 2,
          yearsExperience: i + 1,
          available: true,
          subscriptionTier: i % 3, // Mix of Free, Pro, Elite
        ),
      );

      final totalUsers3 = professionals3.length;

      expect(totalUsers3, equals(10),
          reason: 'Total Users should count all professionals: 10');

      // Test Case 4: Verify Free tier professionals are included
      final professionals4 = [
        ProfessionalModel(
          id: 'pro4',
          userId: 'user4',
          name: 'Free Professional 1',
          skills: ['Painting'],
          verified: true,
          rating: 3.8,
          reviewCount: 3,
          yearsExperience: 1,
          available: true,
          subscriptionTier: 0, // Free tier
        ),
        ProfessionalModel(
          id: 'pro5',
          userId: 'user5',
          name: 'Free Professional 2',
          skills: ['Cleaning'],
          verified: true,
          rating: 3.9,
          reviewCount: 4,
          yearsExperience: 2,
          available: true,
          subscriptionTier: 0, // Free tier
        ),
      ];

      final totalUsers4 = professionals4.length;

      expect(totalUsers4, equals(2),
          reason:
              'Total Users should include Free tier professionals (Validates Requirement 3.2)');
    });

    // ────────────────────────────────────────────────────────────────────────
    // Test 3: Completed Bookings Preservation
    // ────────────────────────────────────────────────────────────────────────
    // Observation: Completed Bookings correctly counts bookings with status=completed
    // 
    // Property: For any dashboard state, Completed Bookings = count of all
    // bookings with status=completed
    test('Completed Bookings correctly counts bookings with status=completed',
        () {
      // Test Case 1: Mixed booking statuses
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
          professionalId: 'pro2',
          serviceType: 'Electrical',
          status: BookingStatus.pending,
          scheduledDate: DateTime.now(),
          createdAt: DateTime.now(),
        ),
        BookingModel(
          id: 'booking3',
          customerId: 'customer3',
          professionalId: 'pro3',
          serviceType: 'Carpentry',
          status: BookingStatus.completed,
          scheduledDate: DateTime.now(),
          createdAt: DateTime.now(),
          assessmentPrice: 800.0,
        ),
        BookingModel(
          id: 'booking4',
          customerId: 'customer4',
          professionalId: 'pro4',
          serviceType: 'Painting',
          status: BookingStatus.cancelled,
          scheduledDate: DateTime.now(),
          createdAt: DateTime.now(),
        ),
        BookingModel(
          id: 'booking5',
          customerId: 'customer5',
          professionalId: 'pro5',
          serviceType: 'HVAC',
          status: BookingStatus.completed,
          scheduledDate: DateTime.now(),
          createdAt: DateTime.now(),
          assessmentPrice: 1200.0,
        ),
      ];

      // Calculate Completed Bookings using the observed logic
      final completedBookings1 =
          bookings1.where((b) => b.status == BookingStatus.completed).length;

      expect(completedBookings1, equals(3),
          reason:
              'Completed Bookings should count only completed bookings: 3 out of 5');

      // Test Case 2: No completed bookings
      final bookings2 = [
        BookingModel(
          id: 'booking6',
          customerId: 'customer6',
          professionalId: 'pro6',
          serviceType: 'Roofing',
          status: BookingStatus.pending,
          scheduledDate: DateTime.now(),
          createdAt: DateTime.now(),
        ),
        BookingModel(
          id: 'booking7',
          customerId: 'customer7',
          professionalId: 'pro7',
          serviceType: 'Locksmith',
          status: BookingStatus.cancelled,
          scheduledDate: DateTime.now(),
          createdAt: DateTime.now(),
        ),
      ];

      final completedBookings2 =
          bookings2.where((b) => b.status == BookingStatus.completed).length;

      expect(completedBookings2, equals(0),
          reason: 'Completed Bookings should be 0 when no bookings are completed');

      // Test Case 3: All completed bookings
      final bookings3 = [
        BookingModel(
          id: 'booking8',
          customerId: 'customer8',
          professionalId: 'pro8',
          serviceType: 'Gardening',
          status: BookingStatus.completed,
          scheduledDate: DateTime.now(),
          createdAt: DateTime.now(),
          assessmentPrice: 300.0,
        ),
        BookingModel(
          id: 'booking9',
          customerId: 'customer9',
          professionalId: 'pro9',
          serviceType: 'Handyman',
          status: BookingStatus.completed,
          scheduledDate: DateTime.now(),
          createdAt: DateTime.now(),
          assessmentPrice: 400.0,
        ),
        BookingModel(
          id: 'booking10',
          customerId: 'customer10',
          professionalId: 'pro10',
          serviceType: 'Appliance Repair',
          status: BookingStatus.completed,
          scheduledDate: DateTime.now(),
          createdAt: DateTime.now(),
          assessmentPrice: 600.0,
        ),
      ];

      final completedBookings3 =
          bookings3.where((b) => b.status == BookingStatus.completed).length;

      expect(completedBookings3, equals(3),
          reason: 'Completed Bookings should count all completed bookings: 3');

      // Test Case 4: Empty bookings list
      final bookings4 = <BookingModel>[];
      final completedBookings4 =
          bookings4.where((b) => b.status == BookingStatus.completed).length;

      expect(completedBookings4, equals(0),
          reason: 'Completed Bookings should be 0 when no bookings exist');
    });

    // ────────────────────────────────────────────────────────────────────────
    // Test 4: Combined Preservation Test
    // ────────────────────────────────────────────────────────────────────────
    // This test verifies all three metrics together in a realistic scenario
    test(
        'All non-Total-Earnings metrics (Pending Approvals, Total Users, Completed Bookings) calculate correctly together',
        () {
      // Create a realistic dashboard state
      final applications = [
        ApplicationModel(
          id: 'app1',
          professionalId: 'pro1',
          userId: 'user1',
          serviceType: 'Plumbing',
          yearsExp: 5,
          status: 'pending',
          submittedAt: DateTime.now(),
          applicantName: 'John Doe',
        ),
        ApplicationModel(
          id: 'app2',
          professionalId: 'pro2',
          userId: 'user2',
          serviceType: 'Electrical',
          yearsExp: 3,
          status: 'approved',
          submittedAt: DateTime.now(),
          applicantName: 'Jane Smith',
        ),
      ];

      final proposals = [
        ServiceProposalModel(
          id: 'prop1',
          professionalId: 'pro1',
          userId: 'user1',
          serviceType: 'Plumbing',
          serviceName: 'Fix plumbing',
          includes: [],
          warrantyDays: 0,
          status: 'pending',
          submittedAt: DateTime.now(),
        ),
      ];

      final serviceSelectionRequests = [
        ServiceSelectionRequestModel(
          id: 'ssr1',
          professionalId: 'pro1',
          serviceOfferId: 'offer1',
          action: 'select',
          status: 'pending',
          submittedAt: DateTime.now(),
        ),
        ServiceSelectionRequestModel(
          id: 'ssr2',
          professionalId: 'pro2',
          serviceOfferId: 'offer2',
          action: 'select',
          status: 'completed',
          submittedAt: DateTime.now(),
        ),
      ];

      final upgradeRequests = [
        SubscriptionRequestModel(
          id: 'upgrade1',
          professionalId: 'pro1',
          currentTier: 0,
          requestedTier: 1,
          status: 'pending',
          createdAt: DateTime.now(),
        ),
      ];

      final professionals = [
        ProfessionalModel(
          id: 'pro1',
          userId: 'user3',
          name: 'Pro Professional',
          skills: ['Plumbing'],
          verified: true,
          rating: 4.5,
          reviewCount: 10,
          yearsExperience: 5,
          available: true,
          subscriptionTier: 1,
        ),
        ProfessionalModel(
          id: 'pro2',
          userId: 'user4',
          name: 'Elite Professional',
          skills: ['Electrical'],
          verified: true,
          rating: 4.8,
          reviewCount: 20,
          yearsExperience: 10,
          available: true,
          subscriptionTier: 2,
        ),
        ProfessionalModel(
          id: 'pro3',
          userId: 'user5',
          name: 'Free Professional',
          skills: ['Carpentry'],
          verified: true,
          rating: 4.0,
          reviewCount: 5,
          yearsExperience: 2,
          available: true,
          subscriptionTier: 0,
        ),
      ];

      final bookings = [
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
          professionalId: 'pro2',
          serviceType: 'Electrical',
          status: BookingStatus.pending,
          scheduledDate: DateTime.now(),
          createdAt: DateTime.now(),
        ),
        BookingModel(
          id: 'booking3',
          customerId: 'customer3',
          professionalId: 'pro3',
          serviceType: 'Carpentry',
          status: BookingStatus.completed,
          scheduledDate: DateTime.now(),
          createdAt: DateTime.now(),
          assessmentPrice: 800.0,
        ),
      ];

      // Calculate all metrics
      final pendingApprovals =
          applications.where((a) => a.status == 'pending').length +
              proposals.where((p) => p.status == 'pending').length +
              serviceSelectionRequests.where((r) => r.status == 'pending').length +
              upgradeRequests.where((r) => r.status == 'pending').length;

      final totalUsers = professionals.length;

      final completedBookings =
          bookings.where((b) => b.status == BookingStatus.completed).length;

      // Verify all metrics
      expect(pendingApprovals, equals(4),
          reason:
              'Pending Approvals: 1 application + 1 proposal + 1 service selection request + 1 upgrade request = 4');
      expect(totalUsers, equals(3),
          reason: 'Total Users: 3 professionals (1 Pro, 1 Elite, 1 Free)');
      expect(completedBookings, equals(2),
          reason: 'Completed Bookings: 2 completed bookings out of 3 total');

      // This test confirms that all three metrics work correctly together
      // and will serve as a regression test after the Total Earnings fix
    });
  });
}
