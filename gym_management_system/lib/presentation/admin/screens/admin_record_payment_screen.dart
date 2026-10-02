import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/theme_toggle_button.dart';
import '../../../data/datasources/local/local_cache_service.dart';
import '../../../data/models/membership_model.dart';
import '../../../data/models/user_model.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../core/constants/membership_plans.dart';
import '../providers/admin_provider.dart';

class AdminRecordPaymentScreen extends ConsumerStatefulWidget {
  final String? preselectedUserId;
  final String? preselectedPlan;
  final int initialTab;

  const AdminRecordPaymentScreen({
    super.key,
    this.preselectedUserId,
    this.preselectedPlan,
    this.initialTab = 0,
  });

  @override
  ConsumerState<AdminRecordPaymentScreen> createState() =>
      _AdminRecordPaymentScreenState();
}

class _AdminRecordPaymentScreenState
    extends ConsumerState<AdminRecordPaymentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String? _selectedUserId;
  String _selectedPlanName = '1-Month Premium Membership';
  double _selectedPrice = 1400.0;
  int _selectedDurationDays = 30;
  final String _paymentMethod = 'Cash at Counter';
  final TextEditingController _amountTenderedController = TextEditingController();
  final TextEditingController _receiptNotesController = TextEditingController();
  final TextEditingController _memberSearchController = TextEditingController();
  bool _isProcessing = false;

  final List<Map<String, dynamic>> _availablePlans = kViciousMembershipPlans.map((p) => {
    'name': p.name,
    'price': p.price,
    'days': p.days,
    'tag': p.badgeText ?? (p.isPopular ? 'MOST POPULAR' : (p.hasCoach ? 'INCLUDES COACH' : 'NO WALK-IN FEE')),
    'features': p.features.join(' • '),
    'icon': p.icon,
    'accentColor': p.accentColor,
  }).toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );

    _selectedUserId = widget.preselectedUserId;

    if (widget.preselectedPlan != null) {
      final matchedPlan = _availablePlans.firstWhere(
        (p) => (p['name'] as String).toLowerCase() == widget.preselectedPlan!.toLowerCase(),
        orElse: () => _availablePlans.first,
      );
      _selectedPlanName = matchedPlan['name'] as String;
      _selectedPrice = matchedPlan['price'] as double;
      _selectedDurationDays = matchedPlan['days'] as int;
    } else if (_selectedUserId != null) {
      final userPending = LocalCacheService().getMembership(_selectedUserId!);
      if (userPending != null && userPending.isPending) {
        final matchedPlan = _availablePlans.firstWhere(
          (p) => (p['name'] as String).toLowerCase() == userPending.planName.toLowerCase(),
          orElse: () => _availablePlans.first,
        );
        _selectedPlanName = matchedPlan['name'] as String;
        _selectedPrice = userPending.price > 0 ? userPending.price : (matchedPlan['price'] as double);
        _selectedDurationDays = matchedPlan['days'] as int;
      }
    }

    _amountTenderedController.text = _selectedPrice.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountTenderedController.dispose();
    _receiptNotesController.dispose();
    _memberSearchController.dispose();
    super.dispose();
  }

  void _onPlanSelected(Map<String, dynamic> plan) {
    setState(() {
      _selectedPlanName = plan['name'] as String;
      _selectedPrice = plan['price'] as double;
      _selectedDurationDays = plan['days'] as int;
      _amountTenderedController.text = _selectedPrice.toStringAsFixed(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(adminNotifierProvider);
    final pendingCount = adminState.pendingMemberships.length;
    final totalTransactionsCount = adminState.memberships.length;

    // Ensure a default user is selected if none specified
    if (_selectedUserId == null && adminState.members.isNotEmpty) {
      _selectedUserId = adminState.members.first.id;
    }

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.cardColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.titleColor),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop(true);
            }
          },
        ),
        title: Text(
          'Record Member Payment',
          style: TextStyle(
            color: context.titleColor,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            tooltip: 'Refresh Records',
            onPressed: () async {
              await ref.read(adminNotifierProvider.notifier).loadDashboard();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Records synchronized with live database.'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.accentCyan),
            tooltip: 'Register New Member',
            onPressed: () => context.push(AppRoutes.register),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          isScrollable: MediaQuery.of(context).size.width < 700,
          tabAlignment: MediaQuery.of(context).size.width < 700 ? TabAlignment.start : TabAlignment.fill,
          tabs: [
            const Tab(
              icon: Icon(Icons.autorenew_rounded, size: 18),
              text: 'Renew Plan / Subscription',
            ),
            Tab(
              icon: const Icon(Icons.pending_actions_rounded, size: 18),
              text: 'Pending Cash ($pendingCount)',
            ),
            Tab(
              icon: const Icon(Icons.receipt_long_rounded, size: 18),
              text: 'Transactions ($totalTransactionsCount)',
            ),
          ],
        ),
      ),
      body: adminState.isLoading && adminState.members.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDirectPaymentTab(context, adminState),
                _buildPendingApprovalsTab(context, adminState),
                _buildTransactionsTab(context, adminState),
              ],
            ),
    );
  }

  // --- TAB 1: DIRECT PAYMENT FORM (WHOLE SCREEN) ---
  Widget _buildDirectPaymentTab(BuildContext context, AdminState adminState) {
    final currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 0);

    // Filter members based on search
    final query = _memberSearchController.text.trim().toLowerCase();
    final memberList = query.isEmpty
        ? adminState.members
        : adminState.members.where((m) =>
            m.name.toLowerCase().contains(query) ||
            m.email.toLowerCase().contains(query) ||
            m.fitnessGoal.toLowerCase().contains(query)).toList();

    // Ensure _selectedUserId has a valid fallback
    if (_selectedUserId == null && memberList.isNotEmpty) {
      _selectedUserId = memberList.first.id;
    }

    final effectiveSelectedId = memberList.any((m) => m.id == _selectedUserId)
        ? _selectedUserId
        : (memberList.isNotEmpty ? memberList.first.id : null);

    // Find selected member entity
    final selectedMember = adminState.members.where((m) => m.id == effectiveSelectedId).firstOrNull ??
        (adminState.members.isNotEmpty ? adminState.members.first : null);

    final currentMembership = selectedMember != null
        ? adminState.getMembershipForUser(selectedMember.id)
        : null;

    final tenderedAmount = double.tryParse(_amountTenderedController.text.trim()) ?? _selectedPrice;
    final changeDue = (tenderedAmount - _selectedPrice).clamp(0.0, 999999.0);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // Hero Card (Styled exactly like Facilities & Inventory)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.16),
                context.cardColor,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.point_of_sale_rounded, color: Colors.black, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Front Desk Reception & Plan Renewal Desk',
                      style: TextStyle(
                        color: context.titleColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Renew member plans, subscribe members to new packages, verify pending cash requests, and activate subscriptions.',
                      style: TextStyle(color: context.subtitleColor, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Walk-In Day Pass Notice & Quick Redirect
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.directions_walk_rounded, color: Colors.amber, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Walk-In Customer (No Account Needed)',
                      style: TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Day pass walk-in guests do not need an account. Log their entry & time-in directly via Attendance Console.',
                      style: TextStyle(color: context.subtitleColor, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => context.push(AppRoutes.adminAttendance),
                icon: const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.black),
                label: const Text('Attendance', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Section 1: Member Selection
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.borderLine),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_pin_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '1. Select Gym Member',
                        style: TextStyle(
                          color: context.titleColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${adminState.members.length} Members in Database',
                    style: TextStyle(color: context.mutedColor, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Search Filter
              TextField(
                controller: _memberSearchController,
                style: TextStyle(color: context.titleColor, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search member by name or email...',
                  hintStyle: TextStyle(color: context.mutedColor, fontSize: 13),
                  prefixIcon: Icon(Icons.search, size: 18, color: context.mutedColor),
                  suffixIcon: _memberSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, size: 16, color: context.mutedColor),
                          onPressed: () {
                            setState(() {
                              _memberSearchController.clear();
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: context.elevatedSurface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.borderLine),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.borderLine),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),

              // Dropdown Selection
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(
                  color: context.elevatedSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.borderLine),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: effectiveSelectedId,
                    isExpanded: true,
                    dropdownColor: context.cardColor,
                    icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                    items: memberList.map((m) {
                      return DropdownMenuItem<String>(
                        value: m.id,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                              child: Text(
                                m.name.isNotEmpty ? m.name[0].toUpperCase() : 'M',
                                style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${m.name} (${m.email})',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: context.titleColor, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedUserId = val;
                          final memberPending = adminState.pendingMemberships.where((p) => p.userId == val).firstOrNull;
                          if (memberPending != null) {
                            final matchedPlan = _availablePlans.firstWhere(
                              (p) => (p['name'] as String).toLowerCase() == memberPending.planName.toLowerCase(),
                              orElse: () => _availablePlans.first,
                            );
                            _selectedPlanName = matchedPlan['name'] as String;
                            _selectedPrice = memberPending.price > 0 ? memberPending.price : (matchedPlan['price'] as double);
                            _selectedDurationDays = matchedPlan['days'] as int;
                            _amountTenderedController.text = _selectedPrice.toStringAsFixed(0);
                          }
                        });
                      }
                    },
                  ),
                ),
              ),

              // Selected Member Summary Pill
              if (selectedMember != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.elevatedSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedMember.name,
                              style: TextStyle(color: context.titleColor, fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currentMembership != null && currentMembership.isActive
                                  ? 'Current: ${currentMembership.planName} • ${currentMembership.remainingDays} days remaining'
                                  : (currentMembership != null && currentMembership.isPending
                                      ? 'Status: Pending Cash Approval for ${currentMembership.planName}'
                                      : 'Status: No Active Membership Plan'),
                              style: TextStyle(
                                color: currentMembership?.isActive == true
                                    ? AppColors.primary
                                    : (currentMembership?.isPending == true ? AppColors.accent : context.mutedColor),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Section 2: Choose Subscription Tier
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.borderLine),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.card_membership_rounded, color: AppColors.accent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '2. Select Plan to Renew / Activate',
                    style: TextStyle(
                      color: context.titleColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Choose the package requested by the member. Duration and pricing update automatically.',
                style: TextStyle(color: context.subtitleColor, fontSize: 12),
              ),
              const SizedBox(height: 14),

              ..._availablePlans.map((plan) {
                final isSelected = _selectedPlanName == plan['name'];
                final planPrice = plan['price'] as double;
                final planDays = plan['days'] as int;
                final planTag = plan['tag'] as String;
                final planFeatures = plan['features'] as String;
                final planColor = plan['accentColor'] as Color;

                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _onPlanSelected(plan),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? planColor.withValues(alpha: 0.12)
                            : context.elevatedSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? planColor : context.borderLine,
                          width: isSelected ? 2.0 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    color: isSelected ? planColor : context.mutedColor,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    plan['name'] as String,
                                    style: TextStyle(
                                      color: isSelected ? planColor : context.titleColor,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: planColor.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: planColor.withValues(alpha: 0.4)),
                                    ),
                                    child: Text(
                                      planTag,
                                      style: TextStyle(
                                        color: planColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    currencyFormat.format(planPrice),
                                    style: TextStyle(
                                      color: isSelected ? AppColors.primary : context.titleColor,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(left: 28),
                            child: Text(
                              '$planDays Days Validity • $planFeatures',
                              style: TextStyle(
                                color: context.mutedColor,
                                fontSize: 11,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Section 3: Payment Method & Counter Tender Calculator
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.borderLine),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.payment_rounded, color: AppColors.accentCyan, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '3. Payment Method & Cash Tender',
                    style: TextStyle(
                      color: context.titleColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Payment Method Display (Cash at Counter Only)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.point_of_sale_rounded, color: AppColors.primary, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Cash at Counter (Front Desk Cashier)',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Amount Tendered & Calculator
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Amount Received / Tendered (₱)',
                          style: TextStyle(color: context.subtitleColor, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _amountTenderedController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.w800),
                          decoration: InputDecoration(
                            prefixText: '₱ ',
                            prefixStyle: const TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.w800),
                            filled: true,
                            fillColor: context.elevatedSurface,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: context.borderLine),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: context.borderLine),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.primary),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.elevatedSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.borderLine),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Change to Member',
                            style: TextStyle(color: context.mutedColor, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currencyFormat.format(changeDue),
                            style: TextStyle(
                              color: changeDue > 0 ? AppColors.accent : context.titleColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Quick Cash Preset Buttons
              Wrap(
                spacing: 8,
                children: [
                  _QuickCashButton(
                    label: 'Exact (${currencyFormat.format(_selectedPrice)})',
                    onTap: () {
                      setState(() {
                        _amountTenderedController.text = _selectedPrice.toStringAsFixed(0);
                      });
                    },
                  ),
                  _QuickCashButton(
                    label: '+₱500',
                    onTap: () {
                      final current = double.tryParse(_amountTenderedController.text) ?? _selectedPrice;
                      setState(() {
                        _amountTenderedController.text = (current + 500).toStringAsFixed(0);
                      });
                    },
                  ),
                  _QuickCashButton(
                    label: '+₱1,000',
                    onTap: () {
                      final current = double.tryParse(_amountTenderedController.text) ?? _selectedPrice;
                      setState(() {
                        _amountTenderedController.text = (current + 1000).toStringAsFixed(0);
                      });
                    },
                  ),
                  _QuickCashButton(
                    label: '₱3,000',
                    onTap: () {
                      setState(() => _amountTenderedController.text = '3000');
                    },
                  ),
                  _QuickCashButton(
                    label: '₱5,000',
                    onTap: () {
                      setState(() => _amountTenderedController.text = '5000');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Receipt / Cashier Notes
              Text(
                'Receipt Number / Cashier Notes (Optional)',
                style: TextStyle(color: context.subtitleColor, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _receiptNotesController,
                style: TextStyle(color: context.titleColor, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'e.g., OR# 2026-0930-104, Paid in full cash at reception',
                  hintStyle: TextStyle(color: context.mutedColor, fontSize: 12),
                  filled: true,
                  fillColor: context.elevatedSurface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.borderLine),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.borderLine),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Section 4: Live Payment Summary & Confirmation CTA
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_rounded, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Plan Renewal & Activation Summary',
                    style: TextStyle(color: context.titleColor, fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SummaryRow(label: 'Member Name', value: selectedMember?.name ?? 'Select Member'),
              _SummaryRow(label: 'Selected Plan', value: _selectedPlanName),
              _SummaryRow(label: 'Validity Duration', value: '$_selectedDurationDays Days'),
              _SummaryRow(
                label: 'Effective Date',
                value: '${DateFormat('MMM dd, yyyy').format(DateTime.now())} → ${DateFormat('MMM dd, yyyy').format(DateTime.now().add(Duration(days: _selectedDurationDays)))}',
              ),
              _SummaryRow(label: 'Payment Method', value: _paymentMethod),
              const Divider(color: AppColors.border, height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Payable Amount',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    currencyFormat.format(_selectedPrice),
                    style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Big Primary CTA Button
        CustomButton(
          text: _isProcessing
              ? 'Processing Plan Renewal...'
              : 'Confirm & Renew Plan (${currencyFormat.format(_selectedPrice)})',
          icon: Icons.autorenew_rounded,
          color: AppColors.primary,
          isLoading: _isProcessing,
          onPressed: (effectiveSelectedId != null || _selectedUserId != null) && !_isProcessing
              ? _submitPayment
              : null,
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Future<void> _submitPayment() async {
    final adminState = ref.read(adminNotifierProvider);
    final targetUserId = _selectedUserId ??
        (adminState.members.isNotEmpty ? adminState.members.first.id : null);

    if (targetUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a member first.')),
      );
      return;
    }
    setState(() => _isProcessing = true);

    final success = await ref.read(adminNotifierProvider.notifier).recordPayment(
          userId: targetUserId,
          planName: _selectedPlanName,
          amount: _selectedPrice,
          durationDays: _selectedDurationDays,
        );

    setState(() => _isProcessing = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Payment of ₱${_selectedPrice.toStringAsFixed(0)} recorded! Plan renewed and subscription is now ACTIVE.',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
        // Return to dashboard with refresh result, or switch tab if not poppable
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        } else {
          _tabController.animateTo(2);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to record payment. Please check database connection.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // --- TAB 2: PENDING APPROVALS QUEUE ---
  Widget _buildPendingApprovalsTab(BuildContext context, AdminState adminState) {
    final pendingList = adminState.pendingMemberships;
    final currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 0);

    if (pendingList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline_rounded, size: 48, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              Text(
                'No Pending Cash Approvals',
                style: TextStyle(color: context.titleColor, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'All member pass requests have been verified and processed.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.subtitleColor, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Pending Queue Hero Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.accent.withValues(alpha: 0.15),
                context.elevatedSurface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.hourglass_top_rounded, color: Colors.black, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${pendingList.length} Members Waiting at Counter Desk',
                      style: TextStyle(
                        color: context.titleColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Verify physical cash received from the member to instantly activate their membership.',
                      style: TextStyle(color: context.subtitleColor, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        ...pendingList.map((pending) {
          final matched = adminState.members.where((m) => m.id == pending.userId);
          final member = (matched.isNotEmpty ? matched.first : null) ??
              LocalCacheService().getUserById(pending.userId) ??
              UserModel(
                id: pending.userId,
                name: 'Member (${pending.userId.length > 6 ? pending.userId.substring(0, 6) : pending.userId})',
                email: 'Cash Payment Requested',
                role: UserRole.member,
                createdAt: DateTime.now(),
              );

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderLine),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.name,
                            style: TextStyle(
                              color: context.titleColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            member.email,
                            style: TextStyle(color: context.subtitleColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        '${currencyFormat.format(pending.price)} CASH',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.card_membership_rounded, size: 15, color: AppColors.accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Requested Plan: ${pending.planName}',
                        style: TextStyle(color: context.titleColor, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      DateFormat('MMM dd, yyyy • h:mm a').format(pending.startDate),
                      style: TextStyle(color: context.mutedColor, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final ok = await ref
                              .read(adminNotifierProvider.notifier)
                              .approveMembership(pending);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ok
                                    ? 'Cash verified! ${member.name}\'s ${pending.planName} is now ACTIVE.'
                                    : 'Failed to approve membership.'),
                                backgroundColor: ok ? AppColors.primary : AppColors.error,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 18, color: Colors.black),
                        label: const Text(
                          'Confirm Cash & Activate Pass',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () async {
                        final ok = await ref
                            .read(adminNotifierProvider.notifier)
                            .rejectMembership(membershipId: pending.id, userId: pending.userId);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok ? 'Request cancelled.' : 'Failed to reject.'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.error.withValues(alpha: 0.6)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      ),
                      child: const Text('Reject', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // --- TAB 3: TRANSACTION & REVENUE LOG ---
  Widget _buildTransactionsTab(BuildContext context, AdminState adminState) {
    final currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 0);
    final sortedMemberships = List<MembershipModel>.from(adminState.memberships)
      ..sort((a, b) => b.startDate.compareTo(a.startDate));

    if (sortedMemberships.isEmpty) {
      return Center(
        child: Text('No transaction history found in database.', style: TextStyle(color: context.mutedColor)),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Transaction Hero Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.accentCyan.withValues(alpha: 0.15),
                context.elevatedSurface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accentCyan,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: Colors.black, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Ledger & Subscription Records (${sortedMemberships.length})',
                      style: TextStyle(
                        color: context.titleColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Immutable audit trail of all activated memberships and payments.',
                      style: TextStyle(color: context.subtitleColor, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        ...sortedMemberships.map((mem) {
          final member = adminState.members.where((m) => m.id == mem.userId).firstOrNull ??
              LocalCacheService().getUserById(mem.userId);
          final memberName = member?.name ?? 'Member (${mem.userId.length > 6 ? mem.userId.substring(0, 6) : mem.userId})';
          final memberEmail = member?.email ?? 'No email';

          Color statusColor;
          String statusText;
          if (mem.isActive) {
            statusColor = AppColors.primary;
            statusText = 'ACTIVE PASS';
          } else if (mem.isPending) {
            statusColor = AppColors.accent;
            statusText = 'PENDING CASH';
          } else {
            statusColor = AppColors.error;
            statusText = 'EXPIRED';
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderLine),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  child: Icon(Icons.payment_rounded, color: statusColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              memberName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: context.titleColor, fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            currencyFormat.format(mem.price),
                            style: const TextStyle(color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${mem.planName} • $memberEmail',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.subtitleColor, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('MMM dd, yyyy • h:mm a').format(mem.startDate),
                            style: TextStyle(color: context.mutedColor, fontSize: 11),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: context.mutedColor, fontSize: 12)),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(color: context.titleColor, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickCashButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickCashButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: context.cardColor,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: Size.zero,
        side: BorderSide(color: context.borderLine),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: TextStyle(color: context.subtitleColor, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
