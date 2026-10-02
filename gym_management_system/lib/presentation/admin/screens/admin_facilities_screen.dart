import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/theme_toggle_button.dart';
import '../../../data/models/facility_model.dart';
import '../../../domain/entities/workout_plan_entity.dart';
import '../../../domain/services/exercise_alternative_service.dart';
import '../providers/facility_provider.dart';

class AdminFacilitiesScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const AdminFacilitiesScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<AdminFacilitiesScreen> createState() =>
      _AdminFacilitiesScreenState();
}

class _AdminFacilitiesScreenState extends ConsumerState<AdminFacilitiesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(facilityNotifierProvider);

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.cardColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.titleColor),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Facilities & Inventory',
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
            tooltip: 'Refresh',
            onPressed: () =>
                ref.read(facilityNotifierProvider.notifier).loadData(),
          ),
          IconButton(
            icon: const Icon(Icons.add_box_rounded, color: AppColors.accentCyan),
            tooltip: 'Add Equipment',
            onPressed: () => _showAddEquipmentDialog(context, state.facilities),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: [
            Tab(
              icon: const Icon(Icons.meeting_room_rounded, size: 18),
              text: 'Zones (${state.facilities.length})',
            ),
            Tab(
              icon: const Icon(Icons.fitness_center_rounded, size: 18),
              text: 'Equipment (${state.equipment.length})',
            ),
          ],
        ),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildZonesTab(context, state),
                _buildEquipmentTab(context, state),
              ],
            ),
    );
  }

  // --- TAB 1: FACILITY ZONES (Table 10.0) ---
  Widget _buildZonesTab(BuildContext context, FacilityState state) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Live Capacity Summary Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.15),
                context.elevatedSurface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.domain_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vicious Fitness Facility Zones',
                      style: TextStyle(
                        color: context.titleColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Total Capacity: ${state.facilities.fold(0, (s, f) => s + f.capacity)} Members across ${state.facilities.length} Dedicated Zones',
                      style: TextStyle(
                        color: context.subtitleColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        ...state.facilities.map((fac) => _buildFacilityCard(context, fac)),
      ],
    );
  }

  Widget _buildFacilityCard(BuildContext context, FacilityModel fac) {
    final statusColor = fac.isOpen
        ? AppColors.success
        : (fac.isCleaning ? AppColors.accentCyan : AppColors.warning);

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
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getIconForFacility(fac.iconName),
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fac.name,
                      style: TextStyle(
                        color: context.titleColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Hours: ${fac.operatingHours}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  fac.status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            fac.description,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),

          // Occupancy Progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Live Crowd Occupancy',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${fac.currentOccupancy} / ${fac.capacity} (${fac.occupancyPercent}%)',
                style: TextStyle(
                  color: fac.occupancyPercent >= 80
                      ? AppColors.error
                      : (fac.occupancyPercent >= 50
                          ? AppColors.warning
                          : AppColors.success),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fac.occupancyRate,
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(
                fac.occupancyPercent >= 80
                    ? AppColors.error
                    : (fac.occupancyPercent >= 50
                        ? AppColors.warning
                        : AppColors.success),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Change Status Action Button
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => _showChangeZoneStatusDialog(context, fac),
              icon: const Icon(Icons.tune_rounded, size: 14),
              label: const Text('Update Zone Status'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: EQUIPMENT INVENTORY (Table 11.0) ---
  Widget _buildEquipmentTab(BuildContext context, FacilityState state) {
    final filtered = state.filteredEquipment;

    return Column(
      children: [
        // KPI Status Counts Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: context.cardColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInventoryKpi('Total Units', '${state.equipment.length}', context.titleColor),
              Container(width: 1, height: 28, color: context.borderLine),
              _buildInventoryKpi('Operational', '${state.operationalCount}', AppColors.success),
              Container(width: 1, height: 28, color: context.borderLine),
              _buildInventoryKpi('Maintenance', '${state.maintenanceCount}', AppColors.warning),
              Container(width: 1, height: 28, color: context.borderLine),
              _buildInventoryKpi('Out of Order', '${state.outOfOrderCount}', AppColors.error),
            ],
          ),
        ),

        // Filter Bar (Category & Status)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          color: context.cardColor,
          child: Column(
            children: [
              // Search input
              TextField(
                onChanged: (v) =>
                    ref.read(facilityNotifierProvider.notifier).setSearchQuery(v),
                style: TextStyle(color: context.titleColor, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search equipment by name or serial...',
                  hintStyle:
                      TextStyle(color: context.mutedColor, fontSize: 12),
                  prefixIcon:
                      Icon(Icons.search, size: 18, color: context.mutedColor),
                  filled: true,
                  fillColor: context.elevatedSurface,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: context.borderLine),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: context.borderLine),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Category filter horizontal chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    'All',
                    'Cardio',
                    'Strength',
                    'Free Weights',
                    'Functional',
                  ].map((cat) {
                    final selected = state.selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        selected: selected,
                        label: Text(cat, style: const TextStyle(fontSize: 11)),
                        selectedColor: AppColors.primary,
                        backgroundColor: context.elevatedSurface,
                        side: BorderSide(color: selected ? AppColors.primary : context.borderLine),
                        labelStyle: TextStyle(
                          color: selected ? Colors.black : context.titleColor,
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                        ),
                        onSelected: (_) => ref
                            .read(facilityNotifierProvider.notifier)
                            .filterByCategory(cat),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        Divider(color: context.borderLine, height: 1),

        // Equipment List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 48,
                          color: context.mutedColor.withValues(alpha: 0.5)),
                      const SizedBox(height: 8),
                      Text(
                        'No equipment matching filter',
                        style: TextStyle(
                          color: context.titleColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _buildEquipmentCard(context, item);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildInventoryKpi(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildEquipmentCard(BuildContext context, EquipmentModel item) {
    final statusColor = item.isOccupied
        ? AppColors.warning
        : (item.isOperational
            ? AppColors.success
            : (item.isUnderMaintenance ? AppColors.accentCyan : AppColors.error));

    final statusText = item.isOccupied
        ? 'OCCUPIED (IN USE)'
        : (item.isOperational
            ? 'OPERATIONAL'
            : (item.isUnderMaintenance ? 'MAINTENANCE' : 'OUT OF ORDER'));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        color: context.titleColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.category,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'S/N: ${item.serialNumber}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Icon(Icons.place_rounded, size: 13, color: context.mutedColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  item.facilityName,
                  style: TextStyle(
                    color: context.subtitleColor,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Maintained: ${DateFormat('MMM dd, yyyy').format(item.lastMaintained)}',
                style: TextStyle(color: context.mutedColor, fontSize: 10),
              ),
              Text(
                'Next Due: ${DateFormat('MMM dd, yyyy').format(item.nextMaintenanceDate)}',
                style: const TextStyle(
                  color: AppColors.accentCyan,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          if (item.notes != null && item.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.elevatedSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.borderLine),
              ),
              child: Text(
                'Note: ${item.notes!}',
                style: const TextStyle(
                  color: AppColors.warning,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],

          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: () => _confirmDeleteEquipment(context, item),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_outline_rounded,
                          size: 12, color: AppColors.error),
                      SizedBox(width: 4),
                      Text(
                        'Delete',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (item.isOccupied) ...[
                InkWell(
                  onTap: () => _showAiAlternativesPreview(context, item),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 12, color: AppColors.warning),
                        SizedBox(width: 4),
                        Text(
                          'AI Member Alts',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              PopupMenuButton<String>(
                color: context.cardColor,
                onSelected: (val) {
                  ref
                      .read(facilityNotifierProvider.notifier)
                      .updateEquipmentStatus(item.id, val);
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'operational',
                    child: Text('Mark Operational (Available)', style: TextStyle(color: context.titleColor)),
                  ),
                  PopupMenuItem(
                    value: 'occupied',
                    child: Text('Mark Fully Occupied (In-Use)', style: TextStyle(color: context.titleColor)),
                  ),
                  PopupMenuItem(
                    value: 'under_maintenance',
                    child: Text('Set Under Maintenance', style: TextStyle(color: context.titleColor)),
                  ),
                  PopupMenuItem(
                    value: 'out_of_order',
                    child: Text('Mark Out of Order', style: TextStyle(color: context.titleColor)),
                  ),
                ],
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.elevatedSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.borderLine),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_rounded, size: 12, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text(
                        'Change Status',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDeleteEquipment(BuildContext context, EquipmentModel item) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: context.cardColor,
          title: Text(
            'Delete ${item.name}?',
            style: TextStyle(color: context.titleColor, fontSize: 16),
          ),
          content: Text(
            'Are you sure you want to remove "${item.name}" (${item.serialNumber}) from the gym equipment inventory?',
            style: TextStyle(color: context.subtitleColor, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: TextStyle(color: context.subtitleColor)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                ref
                    .read(facilityNotifierProvider.notifier)
                    .deleteEquipment(item.id);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${item.name} removed from inventory'),
                    backgroundColor: context.cardColor,
                  ),
                );
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showChangeZoneStatusDialog(BuildContext context, FacilityModel fac) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: context.cardColor,
          title: Text(
            'Update Status for ${fac.name}',
            style: TextStyle(color: context.titleColor, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.check_circle_rounded, color: AppColors.success),
                title: Text('Open (Normal Operation)', style: TextStyle(color: context.titleColor)),
                onTap: () {
                  ref
                      .read(facilityNotifierProvider.notifier)
                      .updateFacilityStatus(fac.id, 'open');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.cleaning_services_rounded, color: AppColors.accentCyan),
                title: Text('Cleaning / Sanitizing', style: TextStyle(color: context.titleColor)),
                onTap: () {
                  ref
                      .read(facilityNotifierProvider.notifier)
                      .updateFacilityStatus(fac.id, 'cleaning');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.build_rounded, color: AppColors.warning),
                title: Text('Maintenance Work', style: TextStyle(color: context.titleColor)),
                onTap: () {
                  ref
                      .read(facilityNotifierProvider.notifier)
                      .updateFacilityStatus(fac.id, 'maintenance');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.block_rounded, color: AppColors.error),
                title: Text('Closed', style: TextStyle(color: context.titleColor)),
                onTap: () {
                  ref
                      .read(facilityNotifierProvider.notifier)
                      .updateFacilityStatus(fac.id, 'closed');
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddEquipmentDialog(
      BuildContext context, List<FacilityModel> facilities) {
    final nameCtrl = TextEditingController();
    final serialCtrl = TextEditingController();
    String selectedCategory = 'Cardio';
    String selectedFacilityId =
        facilities.isNotEmpty ? facilities.first.id : 'fac_cardio_01';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: context.cardColor,
              title: Text(
                'Add Equipment Unit',
                style: TextStyle(color: context.titleColor, fontSize: 16),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      style: TextStyle(color: context.titleColor),
                      decoration: InputDecoration(
                        labelText: 'Equipment Name',
                        labelStyle: TextStyle(color: context.mutedColor),
                        hintText: 'e.g. Olympic Incline Bench',
                        hintStyle: TextStyle(color: context.mutedColor),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: serialCtrl,
                      style: TextStyle(color: context.titleColor),
                      decoration: InputDecoration(
                        labelText: 'Serial / Inventory Number',
                        labelStyle: TextStyle(color: context.mutedColor),
                        hintText: 'e.g. VF-FW-2024-004',
                        hintStyle: TextStyle(color: context.mutedColor),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      dropdownColor: context.cardColor,
                      style: TextStyle(color: context.titleColor),
                      decoration: InputDecoration(
                        labelText: 'Category',
                        labelStyle: TextStyle(color: context.mutedColor),
                      ),
                      items: [
                        'Cardio',
                        'Strength',
                        'Free Weights',
                        'Functional',
                        'Recovery'
                      ]
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c, style: TextStyle(color: context.titleColor))))
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedCategory = v ?? 'Cardio'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedFacilityId,
                      dropdownColor: context.cardColor,
                      style: TextStyle(color: context.titleColor),
                      decoration: InputDecoration(
                        labelText: 'Facility Zone',
                        labelStyle: TextStyle(color: context.mutedColor),
                      ),
                      items: facilities
                          .map((f) =>
                              DropdownMenuItem(value: f.id, child: Text(f.name, style: TextStyle(color: context.titleColor))))
                          .toList(),
                      onChanged: (v) => setDialogState(
                          () => selectedFacilityId = v ?? facilities.first.id),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: TextStyle(color: context.subtitleColor)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    final serial = serialCtrl.text.trim();
                    if (name.isEmpty) return;

                    final parentFac = facilities
                        .firstWhere((f) => f.id == selectedFacilityId);
                    final newEq = EquipmentModel(
                      id: 'eq_${const Uuid().v4().substring(0, 8)}',
                      facilityId: selectedFacilityId,
                      facilityName: parentFac.name,
                      name: name,
                      category: selectedCategory,
                      serialNumber: serial.isNotEmpty
                          ? serial
                          : 'VF-${DateTime.now().millisecondsSinceEpoch}',
                      status: 'operational',
                      lastMaintained: DateTime.now(),
                      nextMaintenanceDate:
                          DateTime.now().add(const Duration(days: 90)),
                    );

                    ref.read(facilityNotifierProvider.notifier).addEquipment(newEq);
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Add Equipment'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  IconData _getIconForFacility(String? iconName) {
    switch (iconName) {
      case 'directions_run':
        return Icons.directions_run_rounded;
      case 'fitness_center':
        return Icons.fitness_center_rounded;
      case 'sports_gymnastics':
        return Icons.sports_gymnastics_rounded;
      case 'sports_mma':
        return Icons.sports_mma_rounded;
      default:
        return Icons.location_on_rounded;
    }
  }

  void _showAiAlternativesPreview(BuildContext context, EquipmentModel item) {
    final service = ExerciseAlternativeService();
    final dummyExercise = ExerciseEntity(
      name: item.name,
      muscleGroup: item.category == 'Cardio'
          ? 'Cardiovascular'
          : (item.name.toLowerCase().contains('leg') ? 'Quadriceps' : 'Full Body'),
      sets: '3-4',
      reps: '10-12',
      restSec: 60,
      equipment: item.name,
    );
    final alternatives = service.getAlternatives(exercise: dummyExercise);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: context.cardColor,
          title: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Member AI Alternatives: ${item.name}',
                  style: TextStyle(color: context.titleColor, fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: alternatives.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (ctx, idx) {
                final alt = alternatives[idx];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            alt.alternativeName,
                            style: TextStyle(color: context.titleColor, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${alt.matchPercentage}% Match',
                            style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Equip: ${alt.alternativeEquipment} • Target: ${alt.muscleGroup}',
                      style: TextStyle(color: context.subtitleColor, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alt.aiRationale,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: AppColors.primary)),
            ),
          ],
        );
      },
    );
  }
}
