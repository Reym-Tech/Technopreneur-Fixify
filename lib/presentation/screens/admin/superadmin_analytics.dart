// lib/presentation/screens/admin/super_admin_analytics.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';

class SuperAdminAnalytics extends StatefulWidget {
  final VoidCallback? onBack;
  final Function(int)? onNavTap;
  final int currentNavIndex;

  const SuperAdminAnalytics({
    super.key,
    this.onBack,
    this.onNavTap,
    this.currentNavIndex = 2,
  });

  @override
  State<SuperAdminAnalytics> createState() => _SuperAdminAnalyticsState();
}

class _SuperAdminAnalyticsState extends State<SuperAdminAnalytics>
    with TickerProviderStateMixin {
  late TabController _periodTabController;
  late TabController _chartTabController;

  // Date range selection
  String _selectedPeriod = 'This Month';
  final List<String> _periods = [
    'Today',
    'This Week',
    'This Month',
    'This Year',
    'Custom',
  ];

  // Hardcoded mock earnings data
  final Map<String, dynamic> _earningsData = {
    'totalRevenue': 458750.00,
    'platformFees': 22937.50,
    'handymanPayouts': 435812.50,
    'growth': 15.8,
    'averageOrderValue': 1250.00,
    'projectedRevenue': 525000.00,
  };

  // Hardcoded monthly earnings data for charts
  final List<Map<String, dynamic>> _monthlyEarnings = [
    {'month': 'Jan', 'revenue': 32500.0, 'bookings': 28, 'handymen': 12},
    {'month': 'Feb', 'revenue': 38900.0, 'bookings': 34, 'handymen': 14},
    {'month': 'Mar', 'revenue': 41200.0, 'bookings': 38, 'handymen': 15},
    {'month': 'Apr', 'revenue': 45600.0, 'bookings': 42, 'handymen': 16},
    {'month': 'May', 'revenue': 48900.0, 'bookings': 45, 'handymen': 18},
    {'month': 'Jun', 'revenue': 52300.0, 'bookings': 48, 'handymen': 19},
    {'month': 'Jul', 'revenue': 55800.0, 'bookings': 52, 'handymen': 20},
    {'month': 'Aug', 'revenue': 59200.0, 'bookings': 55, 'handymen': 22},
    {'month': 'Sep', 'revenue': 62700.0, 'bookings': 58, 'handymen': 23},
    {'month': 'Oct', 'revenue': 66100.0, 'bookings': 62, 'handymen': 25},
    {'month': 'Nov', 'revenue': 69500.0, 'bookings': 65, 'handymen': 26},
    {'month': 'Dec', 'revenue': 72900.0, 'bookings': 68, 'handymen': 28},
  ];

  // Hardcoded service category breakdown
  final List<Map<String, dynamic>> _serviceBreakdown = [
    {
      'service': 'Electrical',
      'revenue': 142500,
      'percentage': 31,
      'color': Colors.amber,
      'bookings': 120,
    },
    {
      'service': 'Plumbing',
      'revenue': 98500,
      'percentage': 21,
      'color': Colors.blue,
      'bookings': 85,
    },
    {
      'service': 'Carpentry',
      'revenue': 87650,
      'percentage': 19,
      'color': Colors.brown,
      'bookings': 72,
    },
    {
      'service': 'Aircon',
      'revenue': 76500,
      'percentage': 17,
      'color': Colors.teal,
      'bookings': 58,
    },
    {
      'service': 'Painting',
      'revenue': 32500,
      'percentage': 7,
      'color': Colors.purple,
      'bookings': 28,
    },
    {
      'service': 'Others',
      'revenue': 20900,
      'percentage': 5,
      'color': Colors.grey,
      'bookings': 18,
    },
  ];

  // Hardcoded top handymen
  final List<Map<String, dynamic>> _topHandymen = [
    {
      'name': 'Juan Dela Cruz',
      'avatar': 'JD',
      'specialization': 'Electrician',
      'earnings': 38400,
      'bookings': 48,
      'rating': 4.8,
    },
    {
      'name': 'Maria Santos',
      'avatar': 'MS',
      'specialization': 'Plumber',
      'earnings': 33600,
      'bookings': 42,
      'rating': 4.7,
    },
    {
      'name': 'Pedro Reyes',
      'avatar': 'PR',
      'specialization': 'Carpenter',
      'earnings': 29750,
      'bookings': 35,
      'rating': 4.9,
    },
    {
      'name': 'Ana Garcia',
      'avatar': 'AG',
      'specialization': 'Aircon Tech',
      'earnings': 40300,
      'bookings': 31,
      'rating': 4.6,
    },
    {
      'name': 'Jose Mercado',
      'avatar': 'JM',
      'specialization': 'Electrician',
      'earnings': 28900,
      'bookings': 26,
      'rating': 4.5,
    },
  ];

  // Hardcoded top customers
  final List<Map<String, dynamic>> _topCustomers = [
    {
      'name': 'Maria Santos',
      'avatar': 'MS',
      'location': 'Makati',
      'spent': 8750,
      'bookings': 12,
      'lastBooking': '2 days ago',
    },
    {
      'name': 'Juan Dela Cruz',
      'avatar': 'JD',
      'location': 'Quezon City',
      'spent': 6200,
      'bookings': 8,
      'lastBooking': '5 days ago',
    },
    {
      'name': 'Ana Garcia',
      'avatar': 'AG',
      'location': 'Pasig',
      'spent': 4850,
      'bookings': 6,
      'lastBooking': '1 week ago',
    },
    {
      'name': 'Pedro Reyes',
      'avatar': 'PR',
      'location': 'Mandaluyong',
      'spent': 12300,
      'bookings': 15,
      'lastBooking': '3 days ago',
    },
  ];

  // Hardcoded location data
  final List<Map<String, dynamic>> _locationData = [
    {'city': 'Quezon City', 'bookings': 245, 'revenue': 285000},
    {'city': 'Manila', 'bookings': 198, 'revenue': 225000},
    {'city': 'Makati', 'bookings': 167, 'revenue': 195000},
    {'city': 'Pasig', 'bookings': 132, 'revenue': 152000},
    {'city': 'Taguig', 'bookings': 98, 'revenue': 112000},
    {'city': 'Mandaluyong', 'bookings': 85, 'revenue': 98000},
  ];

  @override
  void initState() {
    super.initState();
    _periodTabController = TabController(length: 2, vsync: this);
    _chartTabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _periodTabController.dispose();
    _chartTabController.dispose();
    super.dispose();
  }

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
              child: TabBarView(
                controller: _periodTabController,
                children: [_buildOverviewTab(), _buildReportsTab()],
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
          colors: [Color(0xFF082218), Color(0xFF0F3D2E), Color(0xFF1A5C43)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(0)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: widget.onBack ?? () => widget.onNavTap?.call(0),
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
                          'Analytics',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Platform insights and statistics',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedPeriod,
                        dropdownColor: const Color(0xFF1E5F4B),
                        icon: const Icon(Icons.arrow_drop_down,
                            color: Colors.white),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13),
                        items: _periods.map((period) {
                          return DropdownMenuItem(
                              value: period, child: Text(period));
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedPeriod = value;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFF0F3D2E),
      child: TabBar(
        controller: _periodTabController,
        indicatorColor: Colors.white,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Reports'),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Key Metrics Cards
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildMetricCard(
                title: 'Total Revenue',
                value: '₱${_earningsData['totalRevenue'].toStringAsFixed(0)}',
                change: '+${_earningsData['growth']}%',
                icon: Icons.attach_money,
                color: Colors.green,
                isPositive: true,
              ),
              _buildMetricCard(
                title: 'Platform Fees',
                value: '₱${_earningsData['platformFees'].toStringAsFixed(0)}',
                change: '5% fee',
                icon: Icons.account_balance,
                color: Colors.blue,
                isPositive: true,
              ),
              _buildMetricCard(
                title: 'Handyman Payouts',
                value:
                    '₱${_earningsData['handymanPayouts'].toStringAsFixed(0)}',
                change: '95% of revenue',
                icon: Icons.payment,
                color: Colors.orange,
                isPositive: true,
              ),
              _buildMetricCard(
                title: 'Avg. Order Value',
                value:
                    '₱${_earningsData['averageOrderValue'].toStringAsFixed(0)}',
                change: '+8% vs last month',
                icon: Icons.shopping_cart,
                color: Colors.purple,
                isPositive: true,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Revenue Chart Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
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
                      'Revenue Overview',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E5F4B),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TabBar(
                        controller: _chartTabController,
                        indicator: BoxDecoration(
                          color: const Color(0xFF2A7F6E),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.grey[600],
                        labelStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        unselectedLabelStyle: const TextStyle(fontSize: 11),
                        tabs: const [
                          Tab(text: 'Revenue'),
                          Tab(text: 'Bookings'),
                          Tab(text: 'Handymen'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Chart
                SizedBox(
                  height: 200,
                  child: TabBarView(
                    controller: _chartTabController,
                    children: [
                      _buildRevenueChart(),
                      _buildBookingsChart(),
                      _buildHandymenChart(),
                    ],
                  ),
                ),

                const Divider(height: 30),

                // Legend and summary
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildChartLegend(
                      color: const Color(0xFF2A7F6E),
                      label: 'Revenue',
                      value:
                          '₱${_earningsData['totalRevenue'].toStringAsFixed(0)}',
                    ),
                    _buildChartLegend(
                      color: Colors.orange,
                      label: 'Projected',
                      value:
                          '₱${_earningsData['projectedRevenue'].toStringAsFixed(0)}',
                      isProjected: true,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Service Breakdown
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
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
                      'Revenue by Service',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E5F4B),
                      ),
                    ),
                    TextButton(
                      onPressed: _showServiceDetails,
                      child: const Text('View Details'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Service breakdown bars
                ..._serviceBreakdown.map((service) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: service['color'],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  service['service'],
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '₱${service['revenue'].toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E5F4B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: service['percentage'] / 100,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              service['color'],
                            ),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${service['bookings']} bookings',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[500],
                              ),
                            ),
                            Text(
                              '${service['percentage']}%',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: service['color'],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Top Handymen and Customers
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Handymen
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
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
                            'Top Handymen',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E5F4B),
                            ),
                          ),
                          TextButton(
                            onPressed: _showAllHandymen,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('View All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._topHandymen.take(4).map((handyman) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF2A7F6E),
                                      Color(0xFF1E5F4B),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    handyman['avatar'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      handyman['name'],
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      handyman['specialization'],
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₱${handyman['earnings']}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E5F4B),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.star,
                                        size: 8,
                                        color: Colors.amber,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${handyman['rating']}',
                                        style: TextStyle(
                                          fontSize: 8,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Top Customers
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
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
                            'Top Customers',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E5F4B),
                            ),
                          ),
                          TextButton(
                            onPressed: _showAllCustomers,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('View All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._topCustomers.take(4).map((customer) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF2A7F6E),
                                      Color(0xFF1E5F4B),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    customer['avatar'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      customer['name'],
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      customer['location'],
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₱${customer['spent']}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E5F4B),
                                    ),
                                  ),
                                  Text(
                                    '${customer['bookings']} bookings',
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Geographic Distribution
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Geographic Distribution',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E5F4B),
                  ),
                ),
                const SizedBox(height: 16),

                // Location list
                ..._locationData.map((location) {
                  double percentage =
                      location['revenue'] / _earningsData['totalRevenue'] * 100;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              location['city'],
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '₱${location['revenue'].toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E5F4B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percentage / 100,
                            backgroundColor: Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF2A7F6E),
                            ),
                            minHeight: 6,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${location['bookings']} bookings',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey[500],
                              ),
                            ),
                            Text(
                              '${percentage.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2A7F6E),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Quick Reports Grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: [
            _buildReportCard(
              title: 'Revenue Report',
              description: 'Detailed revenue breakdown',
              icon: Icons.attach_money,
              color: Colors.green,
              onTap: () => _generateReport('Revenue'),
            ),
            _buildReportCard(
              title: 'Handyman Report',
              description: 'Handyman performance metrics',
              icon: Icons.handyman,
              color: Colors.blue,
              onTap: () => _generateReport('Handyman'),
            ),
            _buildReportCard(
              title: 'Customer Report',
              description: 'Customer activity analysis',
              icon: Icons.people,
              color: Colors.orange,
              onTap: () => _generateReport('Customer'),
            ),
            _buildReportCard(
              title: 'Booking Report',
              description: 'Booking trends and patterns',
              icon: Icons.calendar_today,
              color: Colors.purple,
              onTap: () => _generateReport('Booking'),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Scheduled Reports
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
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
                    'Scheduled Reports',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E5F4B),
                    ),
                  ),
                  TextButton(
                    onPressed: _scheduleReport,
                    child: const Text('+ Schedule New'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildScheduledReportItem(
                title: 'Weekly Revenue Summary',
                frequency: 'Every Monday',
                format: 'PDF',
                recipients: 'admin@ayo.com',
                enabled: true,
              ),
              const Divider(),
              _buildScheduledReportItem(
                title: 'Monthly Performance Report',
                frequency: '1st of every month',
                format: 'Excel',
                recipients: 'finance@ayo.com, admin@ayo.com',
                enabled: true,
              ),
              const Divider(),
              _buildScheduledReportItem(
                title: 'Daily Booking Report',
                frequency: 'Every day at 9 AM',
                format: 'PDF',
                recipients: 'ops@ayo.com',
                enabled: false,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Export History
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recent Exports',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E5F4B),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.description,
                      color: Colors.green, size: 20),
                ),
                title: const Text('Revenue Report - March 2026'),
                subtitle: const Text('Exported 2 hours ago • 2.5 MB'),
                trailing: const Icon(Icons.download_done, color: Colors.green),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.table_chart,
                      color: Colors.blue, size: 20),
                ),
                title: const Text('Handyman Performance - Q1 2026'),
                subtitle: const Text('Exported yesterday • 3.1 MB'),
                trailing: const Icon(Icons.download_done, color: Colors.green),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.pie_chart,
                      color: Colors.orange, size: 20),
                ),
                title: const Text('Customer Analytics - March 2026'),
                subtitle: const Text('Exported 3 days ago • 1.8 MB'),
                trailing: const Icon(Icons.download_done, color: Colors.green),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String change,
    required IconData icon,
    required Color color,
    required bool isPositive,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isPositive
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 10,
                      color: isPositive ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      change,
                      style: TextStyle(
                        fontSize: 8,
                        color: isPositive ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E5F4B),
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChart() {
    return Container(
      height: 180,
      child: CustomPaint(painter: LineChartPainter(_monthlyEarnings)),
    );
  }

  Widget _buildBookingsChart() {
    return Container(
      height: 180,
      child: Center(
        child: Text(
          'Bookings chart visualization',
          style: TextStyle(color: Colors.grey[400]),
        ),
      ),
    );
  }

  Widget _buildHandymenChart() {
    return Container(
      height: 180,
      child: Center(
        child: Text(
          'Handymen growth chart',
          style: TextStyle(color: Colors.grey[400]),
        ),
      ),
    );
  }

  Widget _buildChartLegend({
    required Color color,
    required String label,
    required String value,
    bool isProjected = false,
  }) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isProjected ? Colors.grey : const Color(0xFF1E5F4B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReportCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E5F4B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduledReportItem({
    required String title,
    required String frequency,
    required String format,
    required String recipients,
    required bool enabled,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: enabled ? const Color(0xFF1E5F4B) : Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$frequency • $format',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
                const SizedBox(height: 2),
                Text(
                  recipients,
                  style: TextStyle(fontSize: 9, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: (value) {},
            activeColor: const Color(0xFF2A7F6E),
          ),
        ],
      ),
    );
  }

  void _showServiceDetails() {
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
                    'Service Category Details',
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
                      itemCount: _serviceBreakdown.length,
                      itemBuilder: (context, index) {
                        final service = _serviceBreakdown[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: service['color'].withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${service['percentage']}%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: service['color'],
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
                                      service['service'],
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E5F4B),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${service['bookings']} bookings',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₱${service['revenue']}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E5F4B),
                                    ),
                                  ),
                                  Text(
                                    '${service['percentage']}% of total',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: service['color'],
                                    ),
                                  ),
                                ],
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

  void _showAllHandymen() {
    _showComingSoon('All Handymen List');
  }

  void _showAllCustomers() {
    _showComingSoon('All Customers List');
  }

  void _generateReport(String type) {
    _showComingSoon('Generate $type Report');
  }

  void _scheduleReport() {
    _showComingSoon('Schedule Report');
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature feature coming soon!'),
        backgroundColor: const Color(0xFF2A7F6E),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildBottomNav() {
    const items = [
      {'icon': Icons.dashboard_rounded, 'label': 'Dashboard'},
      {'icon': Icons.pending_actions_rounded, 'label': 'Approvals'},
      {'icon': Icons.bar_chart_rounded, 'label': 'Analytics'},
      {'icon': Icons.settings_rounded, 'label': 'Settings'},
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
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
                      Icon(
                        items[i]['icon'] as IconData,
                        color: active ? AppColors.primary : AppColors.textLight,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[i]['label'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w400,
                          color:
                              active ? AppColors.primary : AppColors.textLight,
                        ),
                      ),
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

// Custom painter for line chart
class LineChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;

  LineChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = const Color(0xFF2A7F6E)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = const Color(0xFF2A7F6E).withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final pointPaint = Paint()
      ..color = const Color(0xFF2A7F6E)
      ..style = PaintingStyle.fill;

    final double width = size.width;
    final double height = size.height;
    final double stepX = width / (data.length - 1);

    // Find max value for scaling (safely cast revenue to double)
    double maxValue = 0;
    if (data.isNotEmpty) {
      maxValue = data
          .map((e) => (e['revenue'] as num).toDouble())
          .reduce((a, b) => a > b ? a : b);
    }

    // avoid divide by zero or invalid drawing
    if (maxValue == 0) return;

    // Create path
    final path = Path();
    final List<Offset> points = [];

    for (int i = 0; i < data.length; i++) {
      final revenue = (data[i]['revenue'] as num).toDouble();
      double x = data.length > 1 ? i * stepX : width / 2;
      double y = height - (revenue / maxValue) * (height * 0.8) - 20;
      points.add(Offset(x, y));

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Draw fill
    final fillPath = Path.from(path);
    fillPath.lineTo(points.last.dx, height - 10);
    fillPath.lineTo(points.first.dx, height - 10);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);

    // Draw line
    canvas.drawPath(path, paint);

    // Draw points
    for (var point in points) {
      canvas.drawCircle(point, 4, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
