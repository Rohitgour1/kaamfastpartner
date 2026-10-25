import 'package:flutter/material.dart';

enum PartnerRole { delivery, service, business }

extension PartnerRoleX on PartnerRole {
  String get id => name;

  String get title => switch (this) {
        PartnerRole.delivery => 'Delivery Partner',
        PartnerRole.service => 'Service Partner',
        PartnerRole.business => 'Business Partner',
      };

  String get description => switch (this) {
        PartnerRole.delivery => 'Deliver small parcels, documents, and food to customers.',
        PartnerRole.service => 'Provide home maintenance, repair, and assistance services directly to customers.',
        PartnerRole.business => 'Register your store or business (e.g. Laundry, Print, Hub) and receive bulk customer orders.',
      };

  IconData get icon => switch (this) {
        PartnerRole.delivery => Icons.local_shipping_rounded,
        PartnerRole.service => Icons.build_rounded,
        PartnerRole.business => Icons.storefront_rounded,
      };

  Color get accent => switch (this) {
        PartnerRole.delivery => const Color(0xFF011431),
        PartnerRole.service => const Color(0xFF7AC42B),
        PartnerRole.business => const Color(0xFF001030),
      };
}

class PartnerUser {
  PartnerUser({
    this.id,
    required this.name,
    required this.mobile,
    required this.role,
    required this.location,
    this.email,
    this.avatarUrl,
    this.isOnline = true,
    this.todayEarnings = 0,
    this.completedTodayCount = 0,
    this.activeJobsCount = 0,
    this.availableJobsCount = 0,
    this.rating = 4.8,
    this.canOperate = true,
    this.status,
    this.kycStatus,
    this.referralCode,
    this.workTypes = const [],
  });

  final int? id;
  final String name;
  final String mobile;
  final PartnerRole role;
  final String location;
  final String? email;
  final String? avatarUrl;
  bool isOnline;
  final double todayEarnings;
  final int completedTodayCount;
  final int activeJobsCount;
  final int availableJobsCount;
  final double rating;
  final bool canOperate;
  final String? status;
  final String? kycStatus;
  final String? referralCode;
  final List<String> workTypes;

  PartnerUser copyWith({
    int? id,
    String? name,
    String? mobile,
    PartnerRole? role,
    String? location,
    String? email,
    String? avatarUrl,
    bool? isOnline,
    double? todayEarnings,
    int? completedTodayCount,
    int? activeJobsCount,
    int? availableJobsCount,
    double? rating,
    bool? canOperate,
    String? status,
    String? kycStatus,
    String? referralCode,
    List<String>? workTypes,
  }) {
    return PartnerUser(
      id: id ?? this.id,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      role: role ?? this.role,
      location: location ?? this.location,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isOnline: isOnline ?? this.isOnline,
      todayEarnings: todayEarnings ?? this.todayEarnings,
      completedTodayCount: completedTodayCount ?? this.completedTodayCount,
      activeJobsCount: activeJobsCount ?? this.activeJobsCount,
      availableJobsCount: availableJobsCount ?? this.availableJobsCount,
      rating: rating ?? this.rating,
      canOperate: canOperate ?? this.canOperate,
      status: status ?? this.status,
      kycStatus: kycStatus ?? this.kycStatus,
      referralCode: referralCode ?? this.referralCode,
      workTypes: workTypes ?? this.workTypes,
    );
  }
}

class PartnerTask {
  PartnerTask({
    required this.id,
    this.bookingId,
    required this.orderCode,
    required this.time,
    required this.title,
    required this.distance,
    required this.estEarning,
    required this.category,
    required this.pickup,
    required this.drop,
    this.status = 'pending',
    this.assignedRider,
    this.legType,
    this.photoCount = 0,
    this.photoUrls = const [],
    this.customerPhotoUrls = const [],
    this.customerName,
    this.customerPhone,
    this.legs = const [],
    this.notes,
    this.pickupLat,
    this.pickupLng,
    this.dropLat,
    this.dropLng,
    this.isCash = false,
    this.paidBy = 'sender',
    this.paymentMethod,
    this.senderName,
    this.senderPhone,
    this.receiverName,
    this.receiverPhone,
    this.pickupPhotoCount = 0,
    this.podPhotoCount = 0,
    this.arrivedAtStop = false,
    this.handoffOtp,
    this.handoffOtpRequired = true,
  });

  final String id;
  final int? bookingId;
  final String orderCode;
  final String time;
  final String title;
  final String distance;
  final double estEarning;
  final String category;
  final String pickup;
  final String drop;
  String status;
  String? assignedRider;
  final String? legType;
  int photoCount;
  List<String> photoUrls;
  /// Photos the customer attached while booking (parcel / clothes).
  final List<String> customerPhotoUrls;
  final String? customerName;
  final String? customerPhone;
  final List<Map<String, dynamic>> legs;
  final String? notes;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropLat;
  final double? dropLng;
  final bool isCash;
  /// sender | receiver
  final String paidBy;
  final String? paymentMethod;
  final String? senderName;
  final String? senderPhone;
  final String? receiverName;
  final String? receiverPhone;
  int pickupPhotoCount;
  int podPhotoCount;
  bool arrivedAtStop;
  final String? handoffOtp;
  final bool handoffOtpRequired;

  bool get isDeliveryService {
    final cat = category.toLowerCase();
    return cat.contains('parcel') || cat.contains('medicine');
  }

  /// Laundry pickup/drop is a delivery trip, not the laundry shop flow.
  bool get isRiderLeg => isPickupLeg || isDropLeg;

  bool get paymentFromSender => paidBy.toLowerCase() != 'receiver';

  bool get paymentFromReceiver => paidBy.toLowerCase() == 'receiver';

  /// Collect at pickup before start (sender pays: cash / wallet / online).
  bool get collectPaymentBeforeStart => isDeliveryService && paymentFromSender;

  /// Collect at drop before complete (receiver pays: cash only).
  bool get collectPaymentAtDrop => isDeliveryService && paymentFromReceiver;

  bool get needsCompletePhotos {
    if (isRiderLeg) return false;
    final cat = category.toLowerCase();
    return cat.contains('laundry') || legType == 'laundry';
  }

  bool get needsPickupGoodsPhotos => isDeliveryService || isPickupLeg;

  bool get needsPodPhotos => isDeliveryService;

  bool get isOnSiteService {
    final cat = category.toLowerCase();
    return cat.contains('helper') ||
        cat.contains('cleaning') ||
        isDeliveryService;
  }

  bool get isPickupLeg => legType == 'pickup';

  bool get isDropLeg => legType == 'drop';

  bool get isLaundryLeg =>
      !isRiderLeg && (legType == 'laundry' || (legType == null && needsCompletePhotos));

  bool get needsHandoffOtp => isPickupLeg || (isDropLeg && !isCash);

  bool get waitingForPickup {
    if (isRiderLeg || !isLaundryLeg) return false;
    if (legs.isEmpty) return false;
    Map<String, dynamic>? pickup;
    for (final leg in legs) {
      if (leg['leg_type']?.toString() == 'pickup') {
        pickup = leg;
        break;
      }
    }
    if (pickup == null) return false;
    return pickup['status']?.toString() != 'completed';
  }

  bool get hasDrop => drop.isNotEmpty && drop != '—';

  bool get canNavigate {
    if (pickupLat != null && pickupLng != null) return true;
    if (dropLat != null && dropLng != null) return true;
    return pickup.isNotEmpty && pickup != '—';
  }
}

class MockPartnerData {
  static PartnerUser userFor(PartnerRole role) => switch (role) {
        PartnerRole.delivery => PartnerUser(
            name: 'Rahul S.',
            mobile: '98765 43210',
            role: role,
            location: 'Bengaluru, KA',
            todayEarnings: 1280,
            completedTodayCount: 8,
            activeJobsCount: 1,
            availableJobsCount: 12,
          ),
        PartnerRole.service => PartnerUser(
            name: 'Amit',
            mobile: '98765 12345',
            role: role,
            location: 'Vijay Nagar, Indore',
            todayEarnings: 720,
            completedTodayCount: 3,
            availableJobsCount: 2,
          ),
        PartnerRole.business => PartnerUser(
            name: 'Laundry Hub - Indore',
            mobile: '98765 88888',
            role: role,
            location: 'Indore, MP',
            todayEarnings: 4850,
            completedTodayCount: 24,
            activeJobsCount: 15,
            availableJobsCount: 8,
            rating: 4.7,
          ),
      };

  static List<PartnerTask> deliveryTasks() => [
        PartnerTask(
          id: 'del-1',
          orderCode: 'DEL-8801',
          time: '10:15 AM',
          title: 'Koramangala 4th Block',
          distance: '2.5 km away',
          estEarning: 150,
          category: 'Small Parcel',
          pickup: 'Cloud Kitchen Hub, Sector 3',
          drop: 'Prestige Towers, MG Road',
        ),
        PartnerTask(
          id: 'del-2',
          orderCode: 'DEL-8802',
          time: '11:00 AM',
          title: 'Indiranagar 100ft Rd',
          distance: '4.1 km away',
          estEarning: 220,
          category: 'Documents',
          pickup: 'Tech Park Block B',
          drop: 'Legal Associates, High Court',
        ),
        PartnerTask(
          id: 'del-3',
          orderCode: 'DEL-8803',
          time: '11:45 AM',
          title: 'HSR Layout Sector 1',
          distance: '1.8 km away',
          estEarning: 180,
          category: 'Express Delivery',
          pickup: 'Biryani Zone, Agara',
          drop: 'Brigade Residency, HSR',
        ),
      ];

  static List<PartnerTask> businessOrders() => [
        PartnerTask(
          id: 'biz-1',
          orderCode: 'LDR-2201',
          time: '09:40 AM',
          title: 'Wash & Fold · 6 kg',
          distance: 'Pickup scheduled',
          estEarning: 420,
          category: 'Laundry',
          pickup: 'Home, Vijay Nagar',
          drop: 'Laundry Hub - Indore',
        ),
        PartnerTask(
          id: 'biz-2',
          orderCode: 'LDR-2202',
          time: '10:20 AM',
          title: 'Dry Clean · 4 pcs',
          distance: 'In shop',
          estEarning: 560,
          category: 'Laundry',
          pickup: 'Laundry Hub - Indore',
          drop: 'Greater Kailash Society',
          status: 'accepted',
        ),
        PartnerTask(
          id: 'biz-3',
          orderCode: 'LDR-2203',
          time: '11:10 AM',
          title: 'Wash & Iron · 8 pcs',
          distance: 'Ready for drop',
          estEarning: 380,
          category: 'Laundry',
          pickup: 'Laundry Hub - Indore',
          drop: 'Scheme 54, Indore',
          status: 'in_progress',
          assignedRider: 'Vikram · Bike',
        ),
      ];
}
