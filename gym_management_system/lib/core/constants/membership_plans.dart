import 'package:flutter/material.dart';
import 'app_colors.dart';

class ViciousMembershipPlan {
  final String id;
  final String name;
  final String title;
  final String priceString;
  final double price;
  final int days;
  final String durationLabel;
  final String description;
  final List<String> features;
  final bool hasCoach;
  final bool isPopular;
  final String? badgeText;
  final IconData icon;
  final Color accentColor;

  const ViciousMembershipPlan({
    required this.id,
    required this.name,
    required this.title,
    required this.priceString,
    required this.price,
    required this.days,
    required this.durationLabel,
    required this.description,
    required this.features,
    this.hasCoach = false,
    this.isPopular = false,
    this.badgeText,
    required this.icon,
    this.accentColor = AppColors.primary,
  });
}

const List<ViciousMembershipPlan> kViciousMembershipPlans = [
  ViciousMembershipPlan(
    id: 'flex_membership',
    name: 'Flex Membership',
    title: '₱800 Flex Membership',
    priceString: '₱800',
    price: 800.0,
    days: 30,
    durationLabel: '1 Month Access',
    description: '1 month unlimited entry with gym floor & locker access.',
    icon: Icons.fitness_center_rounded,
    accentColor: Color(0xFF22C55E),
    features: [
      '1 Month No Walk-in Fee',
      'Standard gym floor access',
      'Free Locker & Storage Access',
    ],
  ),
  ViciousMembershipPlan(
    id: '1_month_premium',
    name: '1-Month Premium Membership',
    title: '₱1,400 (1-Month Premium Membership)',
    priceString: '₱1,400',
    price: 1400.0,
    days: 30,
    durationLabel: '1 Month Access',
    description: 'No walk-in fee with free training sessions & guest passes.',
    isPopular: true,
    hasCoach: true,
    icon: Icons.military_tech_rounded,
    accentColor: Color(0xFFEF4444),
    features: [
      'No Walk-in Fee',
      'FREE (2) Fitness Training Sessions',
      'FREE Consultation with Coach',
      'FREE (3) Guest Day Passes',
      'Assigned Dedicated Coach',
      'Free Locker & Storage Access',
    ],
  ),
  ViciousMembershipPlan(
    id: '3_month_premium',
    name: '3-Month Premium Membership',
    title: '₱3,000 (3-Month Premium Membership)',
    priceString: '₱3,000',
    price: 3000.0,
    days: 90,
    durationLabel: '3 Months Access',
    description: 'Quarterly membership with 3 free training sessions and 4 guest passes.',
    hasCoach: true,
    icon: Icons.stars_rounded,
    accentColor: Color(0xFF94A3B8),
    features: [
      'No Walk-in Fee',
      'FREE (3) Fitness Training Sessions',
      'FREE Consultation with Coach',
      'FREE (4) Guest Day Passes',
      'Assigned Dedicated Coach',
      'Free Locker & Storage Access',
    ],
  ),
  ViciousMembershipPlan(
    id: '6_month_premium',
    name: '6-Month Premium Membership',
    title: '₱6,000 (6-Month Premium Membership)',
    priceString: '₱6,000',
    price: 6000.0,
    days: 180,
    durationLabel: '6 Months Access',
    description: 'Semi-annual membership with 5 free training sessions and 6 guest passes.',
    hasCoach: true,
    icon: Icons.workspace_premium_rounded,
    accentColor: Color(0xFFCBD5E1),
    features: [
      'No Walk-in Fee',
      'FREE (5) Fitness Training Sessions',
      'FREE Consultation with Coach',
      'FREE (6) Guest Day Passes',
      'Priority Coach Session Booking',
      'Free Locker & Storage Access',
    ],
  ),
  ViciousMembershipPlan(
    id: '1_year_elite',
    name: '1 Year Membership - Elite Founders Membership',
    title: '₱10,000 (1 Year Membership - Elite Founders Membership)',
    priceString: '₱10,000',
    price: 10000.0,
    days: 365,
    durationLabel: '1 Year Access',
    description: 'Full year access with 12 guest passes and exclusive Dri-Fit shirt.',
    hasCoach: true,
    icon: Icons.shield_rounded,
    accentColor: Color(0xFFF59E0B),
    features: [
      'No Walk-in Fee',
      'Full Gym Access 365 Days',
      'FREE Consultation with Coach',
      '12 Guest Day Passes',
      'FREE 1 Dri-Fit Shirt',
      'Free Locker & Storage Access',
    ],
  ),
];

bool planIncludesCoaching(String? planName) {
  if (planName == null || planName.isEmpty) return false;
  final p = planName.toLowerCase();
  return p.contains('premium') ||
      p.contains('elite') ||
      p.contains('founders') ||
      p.contains('coach') ||
      p.contains('trainer') ||
      p.contains('pro') ||
      p.contains('vip');
}

ViciousMembershipPlan? getMembershipPlan(String? planName) {
  if (planName == null || planName.trim().isEmpty) return null;
  final clean = planName.toLowerCase().trim();
  for (final plan in kViciousMembershipPlans) {
    if (plan.name.toLowerCase() == clean ||
        plan.title.toLowerCase() == clean ||
        plan.id.toLowerCase() == clean) {
      return plan;
    }
  }
  for (final plan in kViciousMembershipPlans) {
    if (clean.contains(plan.name.toLowerCase()) ||
        plan.name.toLowerCase().contains(clean)) {
      return plan;
    }
  }
  return null;
}

