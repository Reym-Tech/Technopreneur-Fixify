// lib/presentation/screens/professional/earnings_handyman.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/domain/entities/entities.dart';

// ─────────────────────────────────────────────────────────────
// Data Models for Database Integration
// ─────────────────────────────────────────────────────────────

class EarningsSummary {
  final double totalEarnings;
  final double thisMonth;
  final double lastMonth;
  final double today;
  final double pending;
  final double withdrawn;
  final double available;
  final double averageRating;
  final int totalJobs;
  final double completionRate;
  final int platformFee; // percentage

  const EarningsSummary({
    required this.totalEarnings,
    required this.thisMonth,
    required this.lastMonth,
    required this.today,
    required this.pending,
    required this.withdrawn,
    required this.available,
    required this.averageRating,
    required this.totalJobs,
    required this.completionRate,
    required this.platformFee,
  });
}

class MonthlyEarning {
  final String month;
  final double amount;
  final int jobs;
  final DateTime date; // For sorting

  const MonthlyEarning({
    required this.month,
    required this.amount,
    required this.jobs,
    required this.date,
  });
}

class Transaction {
  final String id;
  final String customerName;
  final String serviceType;
  final DateTime date;
  final double amount;
  final TransactionStatus status;
  final PaymentMethod paymentMethod;
  final String? bookingId;
  final String? professionalId;
  final String? customerId;

  const Transaction({
    required this.id,
    required this.customerName,
    required this.serviceType,
    required this.date,
    required this.amount,
    required this.status,
    required this.paymentMethod,
    this.bookingId,
    this.professionalId,
    this.customerId,
  });
}

enum TransactionStatus {
  completed,
  pending,
  failed,
  refunded,
}

enum PaymentMethod {
  cash,
  gcash,
  creditCard,
  paymaya,
  bankTransfer,
}

class Withdrawal {
  final String id;
  final DateTime date;
  final double amount;
  final WithdrawalMethod method;
  final String accountDetails;
  final WithdrawalStatus status;
  final String? reference;

  const Withdrawal({
    required this.id,
    required this.date,
    required this.amount,
    required this.method,
    required this.accountDetails,
    required this.status,
    this.reference,
  });
}

enum WithdrawalMethod {
  bankTransfer,
  gcash,
  paymaya,
}

enum WithdrawalStatus {
  processing,
  completed,
  failed,
}

class ServiceBreakdown {
  final String serviceType;
  final int count;
  final double amount;
  final Color color;

  const ServiceBreakdown({
    required this.serviceType,
    required this.count,
    required this.amount,
    required this.color,
  });
}

// ─────────────────────────────────────────────────────────────
// Screen with Database-Ready Structure
// ─────────────────────────────────────────────────────────────

class EarningsHandymanScreen extends StatefulWidget {
  final String? professionalId;
  final VoidCallback? onBack;
  final Function(DateTimeRange)? onDateRangeSelected;
  final Future<void> Function(double amount, WithdrawalMethod method)?
      onWithdraw;
  final Future<void> Function(Map<String, dynamic> method)? onAddPaymentMethod;
  final Function(int)? onNavTap;
  final int currentNavIndex;

  const EarningsHandymanScreen({
    super.key,
    this.professionalId,
    this.onBack,
    this.onDateRangeSelected,
    this.onWithdraw,
    this.onAddPaymentMethod,
    this.onNavTap,
    this.currentNavIndex = 2,
  });

  @override
  State<EarningsHandymanScreen> createState() => _EarningsHandymanScreenState();
}

class _EarningsHandymanScreenState extends State<EarningsHandymanScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Loading states
  bool _isLoading = true;
  bool _isRefreshing = false;

  // Data from database
  EarningsSummary? _earningsSummary;
  List<MonthlyEarning> _monthlyEarnings = [];
  List<Transaction> _transactions = [];
  List<Withdrawal> _withdrawals = [];
  List<ServiceBreakdown> _serviceBreakdown = [];

  // Filters
  DateTimeRange? _selectedDateRange;
  TransactionStatus? _selectedTransactionStatus;
  String? _searchQuery;
  String? _expandedId; // For expandable transactions

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Data Loading Methods (to be implemented with actual database) ──

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // TODO: Replace with actual database calls
      await Future.delayed(
          const Duration(milliseconds: 800)); // Simulate loading

      // Load data from database
      await _loadEarningsSummary();
      await _loadMonthlyEarnings();
      await _loadTransactions();
      await _loadWithdrawals();
      await _loadServiceBreakdown();
    } catch (e) {
      _showErrorSnackBar('Failed to load earnings data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    await _loadData();
    setState(() => _isRefreshing = false);
  }

  Future<void> _loadEarningsSummary() async {
    // TODO: Implement database call
    _earningsSummary = EarningsSummary(
      totalEarnings: 45850.00,
      thisMonth: 12500.00,
      lastMonth: 11200.00,
      today: 2250.00,
      pending: 3450.00,
      withdrawn: 38500.00,
      available: 7350.00,
      averageRating: 4.8,
      totalJobs: 156,
      completionRate: 98,
      platformFee: 5,
    );
  }

  Future<void> _loadMonthlyEarnings() async {
    // TODO: Implement database call
    _monthlyEarnings = [
      MonthlyEarning(
          month: 'Jan', amount: 8200.00, jobs: 28, date: DateTime(2026, 1)),
      MonthlyEarning(
          month: 'Feb', amount: 9500.00, jobs: 32, date: DateTime(2026, 2)),
      MonthlyEarning(
          month: 'Mar', amount: 11200.00, jobs: 35, date: DateTime(2026, 3)),
      MonthlyEarning(
          month: 'Apr', amount: 12500.00, jobs: 40, date: DateTime(2026, 4)),
      MonthlyEarning(
          month: 'May', amount: 11800.00, jobs: 38, date: DateTime(2026, 5)),
      MonthlyEarning(
          month: 'Jun', amount: 14200.00, jobs: 45, date: DateTime(2026, 6)),
      MonthlyEarning(
          month: 'Jul', amount: 13500.00, jobs: 42, date: DateTime(2026, 7)),
      MonthlyEarning(
          month: 'Aug', amount: 12800.00, jobs: 41, date: DateTime(2026, 8)),
      MonthlyEarning(
          month: 'Sep', amount: 11900.00, jobs: 37, date: DateTime(2026, 9)),
      MonthlyEarning(
          month: 'Oct', amount: 13200.00, jobs: 43, date: DateTime(2026, 10)),
      MonthlyEarning(
          month: 'Nov', amount: 14500.00, jobs: 46, date: DateTime(2026, 11)),
      MonthlyEarning(
          month: 'Dec', amount: 15800.00, jobs: 50, date: DateTime(2026, 12)),
    ];
  }

  Future<void> _loadTransactions() async {
    // TODO: Implement database call
    _transactions = [
      Transaction(
        id: 'TRX-001',
        customerName: 'Maria Santos',
        serviceType: 'Electrical',
        date: DateTime(2026, 3, 1, 14, 30),
        amount: 850.00,
        status: TransactionStatus.completed,
        paymentMethod: PaymentMethod.cash,
      ),
      Transaction(
        id: 'TRX-002',
        customerName: 'Juan Dela Cruz',
        serviceType: 'Plumbing',
        date: DateTime(2026, 2, 28, 10, 15),
        amount: 1200.00,
        status: TransactionStatus.completed,
        paymentMethod: PaymentMethod.gcash,
      ),
      Transaction(
        id: 'TRX-003',
        customerName: 'Pedro Reyes',
        serviceType: 'Carpentry',
        date: DateTime(2026, 2, 27, 16, 0),
        amount: 950.00,
        status: TransactionStatus.pending,
        paymentMethod: PaymentMethod.cash,
      ),
      Transaction(
        id: 'TRX-004',
        customerName: 'Ana Garcia',
        serviceType: 'Aircon Repair',
        date: DateTime(2026, 2, 26, 9, 30),
        amount: 1500.00,
        status: TransactionStatus.completed,
        paymentMethod: PaymentMethod.creditCard,
      ),
      Transaction(
        id: 'TRX-005',
        customerName: 'Jose Mercado',
        serviceType: 'Electrical',
        date: DateTime(2026, 2, 25, 13, 45),
        amount: 750.00,
        status: TransactionStatus.completed,
        paymentMethod: PaymentMethod.cash,
      ),
    ];
  }

  Future<void> _loadWithdrawals() async {
    // TODO: Implement database call
    _withdrawals = [
      Withdrawal(
        id: 'WTH-001',
        date: DateTime(2026, 2, 20),
        amount: 5000.00,
        method: WithdrawalMethod.bankTransfer,
        accountDetails: 'BDO - ****1234',
        status: WithdrawalStatus.completed,
      ),
      Withdrawal(
        id: 'WTH-002',
        date: DateTime(2026, 2, 10),
        amount: 7500.00,
        method: WithdrawalMethod.gcash,
        accountDetails: '****5678',
        status: WithdrawalStatus.completed,
      ),
      Withdrawal(
        id: 'WTH-003',
        date: DateTime(2026, 1, 28),
        amount: 3000.00,
        method: WithdrawalMethod.bankTransfer,
        accountDetails: 'BPI - ****9012',
        status: WithdrawalStatus.completed,
      ),
      Withdrawal(
        id: 'WTH-004',
        date: DateTime(2026, 1, 15),
        amount: 4500.00,
        method: WithdrawalMethod.gcash,
        accountDetails: '****5678',
        status: WithdrawalStatus.processing,
      ),
    ];
  }

  Future<void> _loadServiceBreakdown() async {
    // TODO: Implement database call
    _serviceBreakdown = [
      ServiceBreakdown(
        serviceType: 'Electrical',
        count: 48,
        amount: 38400.00,
        color: Colors.amber,
      ),
      ServiceBreakdown(
        serviceType: 'Plumbing',
        count: 42,
        amount: 33600.00,
        color: Colors.blue,
      ),
      ServiceBreakdown(
        serviceType: 'Carpentry',
        count: 35,
        amount: 29750.00,
        color: Colors.brown,
      ),
      ServiceBreakdown(
        serviceType: 'Aircon',
        count: 31,
        amount: 40300.00,
        color: Colors.teal,
      ),
    ];
  }

  // ── Helper Methods ──

  String _formatCurrency(double amount) {
    return '₱${amount.toStringAsFixed(2)}';
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.month}/${date.day}/${date.year} ${hour}:$minute $ampm';
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt).abs();
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Color _getTransactionStatusColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.completed:
        return Colors.green;
      case TransactionStatus.pending:
        return Colors.orange;
      case TransactionStatus.failed:
        return Colors.red;
      case TransactionStatus.refunded:
        return Colors.purple;
    }
  }

  String _getTransactionStatusText(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.completed:
        return 'Completed';
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.failed:
        return 'Failed';
      case TransactionStatus.refunded:
        return 'Refunded';
    }
  }

  Color _getWithdrawalStatusColor(WithdrawalStatus status) {
    switch (status) {
      case WithdrawalStatus.completed:
        return Colors.green;
      case WithdrawalStatus.processing:
        return Colors.orange;
      case WithdrawalStatus.failed:
        return Colors.red;
    }
  }

  String _getWithdrawalStatusText(WithdrawalStatus status) {
    switch (status) {
      case WithdrawalStatus.completed:
        return 'Completed';
      case WithdrawalStatus.processing:
        return 'Processing';
      case WithdrawalStatus.failed:
        return 'Failed';
    }
  }

  String _getPaymentMethodIcon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.gcash:
        return 'GCash';
      case PaymentMethod.creditCard:
        return 'Credit Card';
      case PaymentMethod.paymaya:
        return 'PayMaya';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
    }
  }

  IconData _getPaymentMethodIconData(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return Icons.money;
      case PaymentMethod.gcash:
      case PaymentMethod.paymaya:
        return Icons.account_balance_wallet;
      case PaymentMethod.creditCard:
        return Icons.credit_card;
      case PaymentMethod.bankTransfer:
        return Icons.account_balance;
    }
  }

  IconData _getWithdrawalMethodIcon(WithdrawalMethod method) {
    switch (method) {
      case WithdrawalMethod.bankTransfer:
        return Icons.account_balance;
      case WithdrawalMethod.gcash:
      case WithdrawalMethod.paymaya:
        return Icons.account_balance_wallet;
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Filter Methods ──

  List<Transaction> _getFilteredTransactions() {
    return _transactions.where((t) {
      if (_selectedDateRange != null) {
        if (t.date.isBefore(_selectedDateRange!.start) ||
            t.date.isAfter(_selectedDateRange!.end)) {
          return false;
        }
      }
      if (_selectedTransactionStatus != null &&
          t.status != _selectedTransactionStatus) {
        return false;
      }
      if (_searchQuery != null && _searchQuery!.isNotEmpty) {
        final query = _searchQuery!.toLowerCase();
        return t.customerName.toLowerCase().contains(query) ||
            t.serviceType.toLowerCase().contains(query) ||
            t.id.toLowerCase().contains(query);
      }
      return true;
    }).toList();
  }

  // ── Build Methods ──

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onNavTap?.call(0); // back → Dashboard
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _refreshData,
                      color: AppColors.primary,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildOverviewTab(),
                          _buildTransactionsTab(),
                          _buildWithdrawTab(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
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
          child: Row(
            children: [
              GestureDetector(
                onTap: () => widget.onNavTap?.call(0),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Earnings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Track your income and withdrawals',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.calendar_today, color: Colors.white),
                onPressed: _showDateRangePicker,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textLight,
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Transactions'),
          Tab(text: 'Withdraw'),
        ],
      ),
    );
  }

  // Overview Tab
  Widget _buildOverviewTab() {
    if (_earningsSummary == null) {
      return const Center(child: Text('No earnings data available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total Earnings Card
          _buildTotalEarningsCard(),
          const SizedBox(height: 20),

          // Stats Row
          _buildStatsRow(),
          const SizedBox(height: 20),

          // Available Balance Card
          _buildAvailableBalanceCard(),
          const SizedBox(height: 20),

          // Monthly Earnings Chart
          _buildMonthlyEarningsCard(),
          const SizedBox(height: 20),

          // Service Breakdown
          _buildServiceBreakdownCard(),
          const SizedBox(height: 20),

          // Recent Transactions
          _buildRecentTransactionsCard(),
        ],
      ),
    );
  }

  Widget _buildTotalEarningsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A7F6E), Color(0xFF1E5F4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2A7F6E).withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Earnings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatCurrency(_earningsSummary!.totalEarnings),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This Month',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrency(_earningsSummary!.thisMonth),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.trending_up,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '+${((_earningsSummary!.thisMonth / _earningsSummary!.lastMonth - 1) * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Today',
            value: _formatCurrency(_earningsSummary!.today),
            icon: Icons.today,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'This Month',
            value: _formatCurrency(_earningsSummary!.thisMonth),
            icon: Icons.calendar_month,
            color: const Color(0xFF2A7F6E),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Pending',
            value: _formatCurrency(_earningsSummary!.pending),
            icon: Icons.pending_actions,
            color: Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E5F4B),
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available Balance',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrency(_earningsSummary!.available),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E5F4B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A7F6E).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Color(0xFF2A7F6E),
                  size: 30,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    _tabController.animateTo(2);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2A7F6E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Withdraw Now'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _showWithdrawHistory,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2A7F6E),
                    side: const BorderSide(color: Color(0xFF2A7F6E)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('History'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyEarningsCard() {
    final recentMonths = _monthlyEarnings.length > 6
        ? _monthlyEarnings.sublist(_monthlyEarnings.length - 6)
        : _monthlyEarnings;

    final maxAmount =
        recentMonths.map((e) => e.amount).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Monthly Earnings',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E5F4B),
                ),
              ),
              TextButton(
                onPressed: _showDetailedChart,
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: recentMonths.map((month) {
                final barHeight = (month.amount / maxAmount) * 120;

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: barHeight,
                        width: 20,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2A7F6E), Color(0xFF1E5F4B)],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        month.month,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                icon: Icons.work,
                value: '${_earningsSummary!.totalJobs}',
                label: 'Total Jobs',
              ),
              _buildSummaryItem(
                icon: Icons.star,
                value: _earningsSummary!.averageRating.toStringAsFixed(1),
                label: 'Avg. Rating',
              ),
              _buildSummaryItem(
                icon: Icons.check_circle,
                value:
                    '${_earningsSummary!.completionRate.toStringAsFixed(0)}%',
                label: 'Completion',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF2A7F6E)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E5F4B),
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildServiceBreakdownCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Earnings by Service',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E5F4B),
            ),
          ),
          const SizedBox(height: 16),
          ..._serviceBreakdown.map((service) {
            final total = _serviceBreakdown.fold<double>(
              0,
              (sum, item) => sum + item.amount,
            );
            final percentage = (service.amount / total) * 100;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: service.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: Text(
                          service.serviceType,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          '${service.count} jobs',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          _formatCurrency(service.amount),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E5F4B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(service.color),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsCard() {
    final recent =
        _transactions.length > 3 ? _transactions.sublist(0, 3) : _transactions;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Transactions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E5F4B),
                ),
              ),
              TextButton(
                onPressed: () {
                  _tabController.animateTo(1);
                },
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...recent
              .map((transaction) => _buildTransactionTile(transaction))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(Transaction transaction) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[100]!, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2A7F6E).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getPaymentMethodIconData(transaction.paymentMethod),
              color: const Color(0xFF2A7F6E),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.customerName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1E5F4B),
                  ),
                ),
                Text(
                  '${transaction.serviceType} • ${_timeAgo(transaction.date)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatCurrency(transaction.amount),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E5F4B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getTransactionStatusColor(transaction.status)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getTransactionStatusText(transaction.status),
                  style: TextStyle(
                    fontSize: 9,
                    color: _getTransactionStatusColor(transaction.status),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Transactions Tab
  Widget _buildTransactionsTab() {
    final filteredTransactions = _getFilteredTransactions();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'All Transactions',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              Row(
                children: [
                  _buildFilterChip(
                    label: 'Filter',
                    icon: Icons.filter_list,
                    onTap: _showFilterDialog,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: 'Search',
                    icon: Icons.search,
                    onTap: _showSearchDialog,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_selectedDateRange != null || _selectedTransactionStatus != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[50],
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (_selectedDateRange != null)
                    _buildFilterChip(
                      label:
                          '${_formatDate(_selectedDateRange!.start)} - ${_formatDate(_selectedDateRange!.end)}',
                      icon: Icons.calendar_today,
                      onTap: () {
                        setState(() {
                          _selectedDateRange = null;
                          _loadTransactions();
                        });
                      },
                    ),
                  if (_selectedTransactionStatus != null)
                    _buildFilterChip(
                      label: _getTransactionStatusText(
                          _selectedTransactionStatus!),
                      icon: Icons.filter_list,
                      onTap: () {
                        setState(() {
                          _selectedTransactionStatus = null;
                          _loadTransactions();
                        });
                      },
                    ),
                ],
              ),
            ),
          ),
        Expanded(
          child: filteredTransactions.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.07),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.receipt_long,
                            size: 52,
                            color: AppColors.primary.withOpacity(0.4),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No transactions found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your completed jobs and earnings will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textLight,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredTransactions.length,
                  itemBuilder: (context, index) {
                    final transaction = filteredTransactions[index];
                    final expanded = _expandedId == transaction.id;
                    return _TransactionCard(
                      transaction: transaction,
                      expanded: expanded,
                      onTap: () => setState(() {
                        _expandedId = expanded ? null : transaction.id;
                      }),
                    )
                        .animate()
                        .fadeIn(delay: (index * 60).ms)
                        .slideY(begin: 0.06, end: 0);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.grey[700]),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Withdraw Tab
  Widget _buildWithdrawTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWithdrawBalanceCard(),
          const SizedBox(height: 20),
          const Text(
            'Withdrawal Methods',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E5F4B),
            ),
          ),
          const SizedBox(height: 12),
          _buildWithdrawMethodCard(
            icon: Icons.account_balance,
            title: 'Bank Transfer',
            subtitle: 'BDO •••• 1234',
            isDefault: true,
          ),
          const SizedBox(height: 8),
          _buildWithdrawMethodCard(
            icon: Icons.account_balance_wallet,
            title: 'GCash',
            subtitle: '•••• 5678',
            isDefault: false,
          ),
          const SizedBox(height: 8),
          _buildWithdrawMethodCard(
            icon: Icons.credit_card,
            title: 'PayMaya',
            subtitle: 'Not linked',
            isDefault: false,
            isLinked: false,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _showAddMethodDialog,
            icon: const Icon(Icons.add, color: Color(0xFF2A7F6E)),
            label: const Text('Add Withdrawal Method'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2A7F6E),
              side: const BorderSide(color: Color(0xFF2A7F6E)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size(double.infinity, 0),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Withdrawals',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E5F4B),
                ),
              ),
              TextButton(
                onPressed: _showWithdrawHistory,
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._withdrawals.map((withdrawal) {
            return _WithdrawalTile(withdrawal: withdrawal);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildWithdrawBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A7F6E), Color(0xFF1E5F4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Available for Withdrawal',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatCurrency(_earningsSummary!.available),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _showWithdrawDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1E5F4B),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Withdraw Now'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawMethodCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDefault,
    bool isLinked = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDefault ? const Color(0xFF2A7F6E) : Colors.grey[200]!,
          width: isDefault ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2A7F6E).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF2A7F6E), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A7F6E).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Default',
                          style: TextStyle(
                            fontSize: 9,
                            color: Color(0xFF2A7F6E),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isLinked ? Colors.grey[600] : Colors.red[300],
                  ),
                ),
              ],
            ),
          ),
          if (isLinked)
            IconButton(
              onPressed: () {},
              icon: Icon(Icons.more_vert, color: Colors.grey[400], size: 20),
            ),
        ],
      ),
    );
  }

  // ── Dialog Methods ──

  void _showDateRangePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Date Range',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E5F4B),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.today, color: Color(0xFF2A7F6E)),
                title: const Text('Today'),
                onTap: () {
                  final now = DateTime.now();
                  setState(() {
                    _selectedDateRange = DateTimeRange(
                      start: DateTime(now.year, now.month, now.day),
                      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
                    );
                    _loadTransactions();
                  });
                  widget.onDateRangeSelected?.call(_selectedDateRange!);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.date_range, color: Color(0xFF2A7F6E)),
                title: const Text('This Week'),
                onTap: () {
                  final now = DateTime.now();
                  final start = now.subtract(Duration(days: now.weekday - 1));
                  setState(() {
                    _selectedDateRange = DateTimeRange(
                      start: DateTime(start.year, start.month, start.day),
                      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
                    );
                    _loadTransactions();
                  });
                  widget.onDateRangeSelected?.call(_selectedDateRange!);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.calendar_month, color: Color(0xFF2A7F6E)),
                title: const Text('This Month'),
                onTap: () {
                  final now = DateTime.now();
                  setState(() {
                    _selectedDateRange = DateTimeRange(
                      start: DateTime(now.year, now.month, 1),
                      end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
                    );
                    _loadTransactions();
                  });
                  widget.onDateRangeSelected?.call(_selectedDateRange!);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Filter Transactions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E5F4B),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Status',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: TransactionStatus.values.map((status) {
                  final isSelected = _selectedTransactionStatus == status;
                  return FilterChip(
                    label: Text(_getTransactionStatusText(status)),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedTransactionStatus = selected ? status : null;
                        _loadTransactions();
                      });
                      Navigator.pop(context);
                    },
                    backgroundColor: Colors.grey[100],
                    selectedColor:
                        _getTransactionStatusColor(status).withOpacity(0.2),
                    checkmarkColor: _getTransactionStatusColor(status),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? _getTransactionStatusColor(status)
                          : Colors.grey[700],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSearchDialog() {
    final searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Transactions'),
        content: TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: 'Search by customer, service, or ID...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
              _loadTransactions();
            });
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _searchQuery = null;
                _loadTransactions();
              });
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _searchQuery = searchController.text;
                _loadTransactions();
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2A7F6E),
              foregroundColor: Colors.white,
            ),
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _showWithdrawDialog() {
    final amountController = TextEditingController();
    WithdrawalMethod? selectedMethod;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw Earnings'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Available Balance: ${_formatCurrency(_earningsSummary!.available)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E5F4B),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₱ ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<WithdrawalMethod>(
                  value: selectedMethod,
                  hint: const Text('Select Withdrawal Method'),
                  items: WithdrawalMethod.values.map((method) {
                    return DropdownMenuItem(
                      value: method,
                      child: Text(method.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedMethod = value;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Withdrawal Method',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                _showErrorSnackBar('Please enter a valid amount');
                return;
              }
              if (amount > _earningsSummary!.available) {
                _showErrorSnackBar('Insufficient balance');
                return;
              }
              if (selectedMethod == null) {
                _showErrorSnackBar('Please select a withdrawal method');
                return;
              }

              Navigator.pop(context);

              if (widget.onWithdraw != null) {
                await widget.onWithdraw!(amount, selectedMethod!);
              } else {
                _showSuccessSnackBar('Withdrawal request submitted!');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2A7F6E),
              foregroundColor: Colors.white,
            ),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
  }

  void _showAddMethodDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Withdrawal Method'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.account_balance, color: Color(0xFF2A7F6E)),
              title: const Text('Bank Transfer'),
              onTap: () {
                Navigator.pop(context);
                _showAddBankAccountDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet,
                  color: Color(0xFF2A7F6E)),
              title: const Text('GCash'),
              onTap: () {
                Navigator.pop(context);
                _showAddGCashDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.credit_card, color: Color(0xFF2A7F6E)),
              title: const Text('PayMaya'),
              onTap: () {
                Navigator.pop(context);
                _showAddPayMayaDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showAddBankAccountDialog() {
    final bankController = TextEditingController();
    final accountController = TextEditingController();
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Bank Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField(
              value: 'BDO',
              items: ['BDO', 'BPI', 'Metrobank', 'PNB', 'Security Bank']
                  .map((bank) =>
                      DropdownMenuItem(value: bank, child: Text(bank)))
                  .toList(),
              onChanged: (value) {},
              decoration: InputDecoration(
                labelText: 'Bank',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: accountController,
              decoration: InputDecoration(
                labelText: 'Account Number',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Account Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (widget.onAddPaymentMethod != null) {
                widget.onAddPaymentMethod!({
                  'method': 'bank_transfer',
                  'bank': bankController.text,
                  'account': accountController.text,
                  'name': nameController.text,
                });
              }
              _showSuccessSnackBar('Bank account added successfully!');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2A7F6E),
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddGCashDialog() {
    final numberController = TextEditingController();
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add GCash'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: numberController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'GCash Number',
                hintText: '09xxxxxxxxx',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Account Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (widget.onAddPaymentMethod != null) {
                widget.onAddPaymentMethod!({
                  'method': 'gcash',
                  'number': numberController.text,
                  'name': nameController.text,
                });
              }
              _showSuccessSnackBar('GCash account added successfully!');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2A7F6E),
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddPayMayaDialog() {
    final numberController = TextEditingController();
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add PayMaya'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: numberController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'PayMaya Number',
                hintText: '09xxxxxxxxx',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Account Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (widget.onAddPaymentMethod != null) {
                widget.onAddPaymentMethod!({
                  'method': 'paymaya',
                  'number': numberController.text,
                  'name': nameController.text,
                });
              }
              _showSuccessSnackBar('PayMaya account added successfully!');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2A7F6E),
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showDetailedChart() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Monthly Earnings Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E5F4B),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: _monthlyEarnings.length,
                      itemBuilder: (context, index) {
                        final month = _monthlyEarnings[index];
                        final maxAmount = _monthlyEarnings
                            .map((e) => e.amount)
                            .reduce((a, b) => a > b ? a : b);

                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey[100]!),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF2A7F6E).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    month.month,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2A7F6E),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${month.jobs} jobs completed',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: month.amount / maxAmount,
                                        backgroundColor: Colors.grey[200],
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                          Color(0xFF2A7F6E),
                                        ),
                                        minHeight: 6,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                _formatCurrency(month.amount),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E5F4B),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showWithdrawHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Withdrawal History',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E5F4B),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: _withdrawals.length,
                      itemBuilder: (context, index) {
                        return _WithdrawalTile(withdrawal: _withdrawals[index]);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

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
              offset: const Offset(0, -4)),
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
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primary.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(items[i]['icon'] as IconData,
                          color:
                              active ? AppColors.primary : AppColors.textLight,
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
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ── Transaction Card (expandable) ──────────────────────────────────

class _TransactionCard extends StatelessWidget {
  final Transaction transaction;
  final bool expanded;
  final VoidCallback? onTap;

  const _TransactionCard({
    required this.transaction,
    required this.expanded,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 250.ms,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: expanded
                ? AppColors.primary.withOpacity(0.3)
                : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: expanded
                  ? AppColors.primary.withOpacity(0.1)
                  : Colors.black.withOpacity(0.06),
              blurRadius: expanded ? 16 : 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary row
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A7F6E).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      _getPaymentMethodIconData(transaction.paymentMethod),
                      color: const Color(0xFF2A7F6E),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.customerName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${transaction.serviceType} • ${_timeAgo(transaction.date)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatCurrency(transaction.amount),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E5F4B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getTransactionStatusColor(transaction.status)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getTransactionStatusText(transaction.status),
                          style: TextStyle(
                            fontSize: 9,
                            color:
                                _getTransactionStatusColor(transaction.status),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Expanded details
            if (expanded) ...[
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detailRow(
                      Icons.calendar_today_outlined,
                      'Date & Time',
                      _formatDateTime(transaction.date),
                    ),
                    _detailRow(
                      Icons.payments_outlined,
                      'Payment Method',
                      _getPaymentMethodIcon(transaction.paymentMethod),
                    ),
                    _detailRow(
                      Icons.receipt_long_outlined,
                      'Transaction ID',
                      transaction.id,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: AppColors.textLight),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt).abs();
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _formatCurrency(double amount) {
    return '₱${amount.toStringAsFixed(2)}';
  }

  String _formatDateTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.month}/${date.day}/${date.year} ${hour}:$minute $ampm';
  }

  IconData _getPaymentMethodIconData(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return Icons.money;
      case PaymentMethod.gcash:
      case PaymentMethod.paymaya:
        return Icons.account_balance_wallet;
      case PaymentMethod.creditCard:
        return Icons.credit_card;
      case PaymentMethod.bankTransfer:
        return Icons.account_balance;
    }
  }

  Color _getTransactionStatusColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.completed:
        return Colors.green;
      case TransactionStatus.pending:
        return Colors.orange;
      case TransactionStatus.failed:
        return Colors.red;
      case TransactionStatus.refunded:
        return Colors.purple;
    }
  }

  String _getTransactionStatusText(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.completed:
        return 'Completed';
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.failed:
        return 'Failed';
      case TransactionStatus.refunded:
        return 'Refunded';
    }
  }

  String _getPaymentMethodIcon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.gcash:
        return 'GCash';
      case PaymentMethod.creditCard:
        return 'Credit Card';
      case PaymentMethod.paymaya:
        return 'PayMaya';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
    }
  }
}

// ── Withdrawal Tile ──────────────────────────────────

class _WithdrawalTile extends StatelessWidget {
  final Withdrawal withdrawal;

  const _WithdrawalTile({required this.withdrawal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:
                  _getWithdrawalStatusColor(withdrawal.status).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getWithdrawalMethodIcon(withdrawal.method),
              color: _getWithdrawalStatusColor(withdrawal.status),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatCurrency(withdrawal.amount),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E5F4B),
                  ),
                ),
                Text(
                  '${withdrawal.method.name} • ${withdrawal.accountDetails}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatDate(withdrawal.date),
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getWithdrawalStatusColor(withdrawal.status)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getWithdrawalStatusText(withdrawal.status),
                  style: TextStyle(
                    fontSize: 9,
                    color: _getWithdrawalStatusColor(withdrawal.status),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getWithdrawalStatusColor(WithdrawalStatus status) {
    switch (status) {
      case WithdrawalStatus.completed:
        return Colors.green;
      case WithdrawalStatus.processing:
        return Colors.orange;
      case WithdrawalStatus.failed:
        return Colors.red;
    }
  }

  String _getWithdrawalStatusText(WithdrawalStatus status) {
    switch (status) {
      case WithdrawalStatus.completed:
        return 'Completed';
      case WithdrawalStatus.processing:
        return 'Processing';
      case WithdrawalStatus.failed:
        return 'Failed';
    }
  }

  IconData _getWithdrawalMethodIcon(WithdrawalMethod method) {
    switch (method) {
      case WithdrawalMethod.bankTransfer:
        return Icons.account_balance;
      case WithdrawalMethod.gcash:
      case WithdrawalMethod.paymaya:
        return Icons.account_balance_wallet;
    }
  }

  String _formatCurrency(double amount) {
    return '₱${amount.toStringAsFixed(2)}';
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
