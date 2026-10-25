import 'package:dio/dio.dart';
import 'package:kaamfast_partner/core/api_client.dart';
import 'package:kaamfast_partner/core/app_constants.dart';
import 'package:kaamfast_partner/data/mock_data.dart';

class PartnerApi {
  PartnerApi(this._api, this._tokens);

  final ApiClient _api;
  final TokenStorage _tokens;

  Future<Map<String, dynamic>> sendOtp(
    String phone, {
    String countryCode = '+91',
  }) async {
    final data = await _api.post(
      '/partner/auth/send-otp',
      data: {'phone': phone, 'country_code': countryCode},
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> verifyOtp(
    String phone,
    String otp, {
    String countryCode = '+91',
    String? name,
    String? email,
    String? referralCode,
  }) async {
    final data = await _api.post(
      '/partner/auth/verify-otp',
      data: {
        'phone': phone,
        'country_code': countryCode,
        'otp': otp,
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (referralCode != null && referralCode.trim().isNotEmpty)
          'referral_code': referralCode.trim(),
        'terms_accepted': true,
        'terms_version': AppConstants.legalVersion,
      },
    );
    final map = Map<String, dynamic>.from(data as Map);
    final token = map['token']?.toString();
    if (token != null && token.isNotEmpty) {
      await _tokens.write(token);
    }
    return map;
  }

  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String email,
  }) async {
    final data = await _api.put(
      '/partner/profile',
      data: {'name': name, 'email': email},
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> uploadAvatar(String filePath) async {
    final form = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(filePath, filename: 'avatar.jpg'),
    });
    final data = await _api.postMultipart('/partner/profile/avatar', form);
    if (data is Map && data['partner'] is Map) {
      return Map<String, dynamic>.from(data['partner'] as Map);
    }
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> me() async {
    final data = await _api.get('/partner/auth/me');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> profile() async {
    final data = await _api.get('/partner/profile');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> onboardingServices() async {
    final data = await _api.get('/partner/onboarding/services');
    final list = data is List ? data : (data is Map ? data['data'] : null);
    final modules = <Map<String, dynamic>>[];
    if (list is List) {
      for (final item in list) {
        if (item is Map) modules.add(Map<String, dynamic>.from(item));
      }
    }
    return modules;
  }

  Future<Map<String, dynamic>> onboardingForm(
    String service, {
    String? partnerType,
  }) async {
    final data = await _api.get(
      '/partner/onboarding/form/$service',
      query: {
        if (partnerType != null && partnerType.isNotEmpty)
          'partner_type': partnerType,
      },
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> submitOnboarding({
    required String partnerType,
    required List<int> serviceModuleIds,
    required String name,
    Map<String, dynamic>? meta,
  }) async {
    final data = await _api.post(
      '/partner/onboarding/submit',
      data: {
        'partner_type': partnerType,
        'service_module_ids': serviceModuleIds,
        if (serviceModuleIds.isNotEmpty)
          'service_module_id': serviceModuleIds.first,
        'name': name,
        if (meta != null) 'meta': meta,
      },
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> dashboard() async {
    final data = await _api.get('/partner/dashboard');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> setAvailability(bool isOnline) async {
    final data = await _api.post(
      '/partner/availability',
      data: {'is_online': isOnline},
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> registerDeviceToken(String token) async {
    final data = await _api.post(
      '/partner/device-token',
      data: {'fcm_token': token},
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> updateLocation(double lat, double lng) async {
    final data = await _api.post(
      '/partner/location',
      data: {'latitude': lat, 'longitude': lng},
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<PartnerTask>> listBookings({
    String scope = 'mine',
    int? partnerId,
  }) async {
    final data = await _api.get(
      '/partner/bookings',
      query: {'scope': scope, 'per_page': 50},
    );
    final list = data is Map ? data['data'] : data;
    final tasks = <PartnerTask>[];
    if (list is List) {
      for (final item in list) {
        if (item is Map) {
          tasks.add(
            taskFromBooking(
              Map<String, dynamic>.from(item),
              partnerId: partnerId,
              asOffer: scope == 'available',
            ),
          );
        }
      }
    }
    return tasks;
  }

  Future<Map<String, dynamic>> acceptBooking(int id, {String? legType}) async {
    final data = await _api.post(
      '/partner/bookings/$id/accept',
      data: {if (legType != null) 'leg_type': legType},
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> rejectBooking(
    int id, {
    String reason = 'Unavailable',
  }) async {
    final data = await _api.post(
      '/partner/bookings/$id/reject',
      data: {'reason': reason},
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> updateBookingStatus(
    int id,
    String status, {
    bool cashCollected = false,
    String? otp,
  }) async {
    final data = await _api.post(
      '/partner/bookings/$id/status',
      data: {
        'status': status,
        if (cashCollected) 'cash_collected': true,
        if (otp != null && otp.isNotEmpty) 'otp': otp,
      },
    );
    // Status may already be committed server-side even if payload is empty/null.
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {'id': id, 'status': status};
  }

  Future<Map<String, dynamic>> sendJobOtp(int id, String purpose) async {
    final data = await _api.post(
      '/partner/bookings/$id/otp/send',
      data: {'purpose': purpose},
    );
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {'purpose': purpose};
  }

  Future<List<Map<String, dynamic>>> listBookingMedia(int bookingId) async {
    final data = await _api.get('/partner/bookings/$bookingId/media');
    final list = data is List ? data : (data is Map ? data['data'] : null);
    final rows = <Map<String, dynamic>>[];
    if (list is List) {
      for (final item in list) {
        if (item is Map) rows.add(Map<String, dynamic>.from(item));
      }
    }
    return rows;
  }

  Future<List<Map<String, dynamic>>> uploadBookingPhotos({
    required int bookingId,
    required List<String> filePaths,
    String kind = 'laundry_complete',
  }) async {
    if (filePaths.isEmpty) {
      throw ApiException('Select at least one photo.');
    }
    final form = FormData();
    form.fields.add(MapEntry('kind', kind));
    for (final path in filePaths) {
      form.files.add(
        MapEntry(
          'photos[]',
          await MultipartFile.fromFile(
            path,
            filename: path.split(RegExp(r'[\\/]')).last,
          ),
        ),
      );
    }
    final data = await _api.postMultipart(
      '/partner/bookings/$bookingId/media',
      form,
    );
    final list = data is List ? data : (data is Map ? data['data'] : null);
    final rows = <Map<String, dynamic>>[];
    if (list is List) {
      for (final item in list) {
        if (item is Map) rows.add(Map<String, dynamic>.from(item));
      }
    }
    return rows;
  }

  Future<Map<String, dynamic>> bookingDetail(int id) async {
    final data = await _api.get('/partner/bookings/$id');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> bookingChat(int bookingId) async {
    final data = await _api.get('/partner/bookings/$bookingId/chat');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> sendBookingChat(
    int bookingId,
    String body,
  ) async {
    final data = await _api.post(
      '/partner/bookings/$bookingId/chat/messages',
      data: {'body': body},
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> bookingSearching(int id) async {
    final data = await _api.get('/partner/bookings/$id/searching');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> earnings() async {
    final data = await _api.get('/partner/earnings');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> wallet() async {
    final data = await _api.get('/partner/wallet');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> paymentConfig() async {
    final data = await _api.get('/payments/config');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> supportConfig() async {
    try {
      final data = await _api.get('/support/config');
      if (data is Map) return Map<String, dynamic>.from(data);
    } catch (_) {}
    return {};
  }

  Future<Map<String, dynamic>> referralSummary() async {
    final data = await _api.get('/partner/referral');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> referralTree() async {
    final data = await _api.get('/partner/referral/tree');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> referralList() async {
    final data = await _api.get('/partner/referral/list');
    final list = data is Map ? data['data'] : data;
    final rows = <Map<String, dynamic>>[];
    if (list is List) {
      for (final item in list) {
        if (item is Map) rows.add(Map<String, dynamic>.from(item));
      }
    }
    return rows;
  }

  Future<Map<String, dynamic>> saveFormResponses({
    required Map<String, dynamic> responses,
    List<int> serviceModuleIds = const [],
  }) async {
    final data = await _api.post(
      '/partner/onboarding/responses',
      data: {
        'responses': responses,
        if (serviceModuleIds.isNotEmpty) 'service_module_ids': serviceModuleIds,
      },
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> onboardingStatus() async {
    final data = await _api.get('/partner/onboarding/status');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> uploadKycDocument({
    required String filePath,
    required String documentType,
    String? name,
    String? documentNumber,
    int? requiredDocumentId,
    int? serviceModuleId,
  }) async {
    final form = FormData.fromMap({
      'document_type': documentType,
      if (name != null && name.isNotEmpty) 'name': name,
      if (documentNumber != null && documentNumber.isNotEmpty)
        'document_number': documentNumber,
      if (requiredDocumentId != null)
        'required_document_id': requiredDocumentId,
      if (serviceModuleId != null) 'service_module_id': serviceModuleId,
      'file': await MultipartFile.fromFile(
        filePath,
        filename: filePath.split(RegExp(r'[\\/]')).last,
      ),
    });
    final data = await _api.postMultipart(
      '/partner/onboarding/documents',
      form,
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> walletTopup(double amount) async {
    final data = await _api.post(
      '/partner/wallet/topup',
      data: {'amount': amount},
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> confirmWalletTopup(
    int topupId,
    Map<String, String> payload,
  ) async {
    final data = await _api.post(
      '/partner/wallet/topup/$topupId/confirm',
      data: payload,
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> walletWithdraw({
    required double amount,
    required String upiId,
  }) async {
    final data = await _api.post(
      '/partner/wallet/withdraw',
      data: {'amount': amount, 'upi_id': upiId},
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> bankAccount() async {
    final data = await _api.get('/partner/wallet/bank-account');
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<Map<String, dynamic>> updateBankAccount({
    required String accountHolderName,
    required String accountNumber,
    required String ifscCode,
  }) async {
    final data = await _api.put(
      '/partner/wallet/bank-account',
      data: {
        'account_holder_name': accountHolderName,
        'account_number': accountNumber,
        'ifsc_code': ifscCode,
      },
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> walletTransactions({
    int page = 1,
    int perPage = 20,
  }) async {
    final data = await _api.get(
      '/partner/wallet/transactions',
      query: {'page': page, 'per_page': perPage},
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> withdrawalHistory({
    int page = 1,
    int perPage = 20,
  }) async {
    final data = await _api.get(
      '/partner/wallet/withdrawals',
      query: {'page': page, 'per_page': perPage},
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> notifications() async {
    final data = await _api.get('/partner/notifications');
    final list = data is Map ? data['data'] : data;
    final items = <Map<String, dynamic>>[];
    if (list is List) {
      for (final item in list) {
        if (item is Map) items.add(Map<String, dynamic>.from(item));
      }
    }
    return items;
  }

  Future<void> markNotificationRead(int id) async {
    await _api.post('/partner/notifications/$id/read');
  }

  Future<void> markAllNotificationsRead() async {
    await _api.post('/partner/notifications/read-all');
  }

  Future<void> logout() async {
    try {
      await _api.post('/partner/auth/logout');
    } catch (_) {
      // ignore network errors on logout
    }
    await _tokens.clear();
  }

  PartnerTask taskFromBooking(
    Map<String, dynamic> json, {
    int? partnerId,
    bool asOffer = false,
  }) {
    final address = json['address'];
    final drop =
        json['drop_address'] ??
        (json['meta'] is Map ? (json['meta'] as Map)['drop_address'] : null);
    final module = json['module'];
    final status = json['status']?.toString() ?? 'pending';
    var mappedStatus = switch (status) {
      'confirmed' => 'pending',
      'assigned' => 'accepted',
      'arrived' => 'arrived',
      'in_progress' || 'started' => 'in_progress',
      'completed' => 'completed',
      _ => status,
    };

    String lineOf(dynamic addr) {
      if (addr is! Map) return '—';
      return [
        addr['line1'],
        addr['line2'],
        addr['landmark'],
        addr['city'],
        addr['state'],
        addr['pincode'],
      ].where((e) => e != null && '$e'.trim().isNotEmpty).join(', ');
    }

    double? coordOf(dynamic addr, String key) {
      if (addr is! Map) return null;
      final value = addr[key];
      final parsed = value is num
          ? value.toDouble()
          : double.tryParse('$value');
      if (parsed == null || parsed.abs() < 0.0001) return null;
      return parsed;
    }

    final scheduled = json['scheduled_at']?.toString();
    final created = json['created_at']?.toString();
    final time = (scheduled ?? created ?? '').replaceFirst('T', ' ');

    String? legType;
    final legMaps = <Map<String, dynamic>>[];
    final legs = json['legs'];
    if (legs is List) {
      Map<String, dynamic>? active;
      for (final item in legs) {
        if (item is! Map) continue;
        final leg = Map<String, dynamic>.from(item);
        legMaps.add(leg);
        final st = leg['status']?.toString();
        if (active == null && (st == 'in_progress' || st == 'assigned')) {
          active = leg;
        }
      }
      if (active == null) {
        for (final leg in legMaps) {
          if (leg['leg_type']?.toString() == 'laundry') {
            active = leg;
            break;
          }
        }
      }
      legType = active?['leg_type']?.toString();
    }

    final offerLeg = _openDeliveryOfferLeg(legMaps, partnerId);
    if (asOffer || offerLeg != null) {
      // Laundry accept sets the booking to assigned. A pickup/drop offer for
      // this rider must stay a request, not an already-accepted job.
      mappedStatus = 'pending';
      if (offerLeg != null) legType = offerLeg;
    }

    var arrivedAtStop = false;
    final ownedRider = _ownedRiderLeg(legMaps, partnerId);
    final ownedLaundry = _ownedLaundryLeg(legMaps, partnerId);
    if (!asOffer && offerLeg == null && ownedRider != null) {
      legType = ownedRider['leg_type']?.toString() ?? legType;
      mappedStatus = switch (ownedRider['status']?.toString()) {
        'in_progress' => 'in_progress',
        'completed' => 'completed',
        'assigned' => 'accepted',
        _ => mappedStatus,
      };
      final meta = json['meta'];
      final arrivedKey = legType == 'drop'
          ? 'drop_arrived_at'
          : 'pickup_arrived_at';
      arrivedAtStop =
          meta is Map && meta[arrivedKey] != null && mappedStatus == 'accepted';
    } else if (!asOffer && offerLeg == null && ownedLaundry != null) {
      // Pickup can be assigned first in the legs list. The shop still owns
      // laundry — do not show the rider's arrived/pickup buttons.
      legType = 'laundry';
      mappedStatus = switch (ownedLaundry['status']?.toString()) {
        'in_progress' => 'in_progress',
        'completed' => 'completed',
        'assigned' => 'accepted',
        _ => mappedStatus,
      };
    } else if (!asOffer &&
        offerLeg == null &&
        ownedRider == null &&
        (legType == 'pickup' || legType == 'drop')) {
      Map<String, dynamic>? laundryLeg;
      for (final leg in legMaps) {
        if (leg['leg_type']?.toString() == 'laundry') {
          laundryLeg = leg;
          break;
        }
      }
      if (laundryLeg != null) {
        legType = 'laundry';
        mappedStatus = switch (laundryLeg['status']?.toString()) {
          'in_progress' => 'in_progress',
          'completed' => 'completed',
          'assigned' => 'accepted',
          _ => mappedStatus,
        };
      }
    }

    final photoUrls = <String>[];
    final customerPhotoUrls = <String>[];
    final photos = json['photos'] ?? json['laundry_complete_photos'];
    var pickupPhotoCount = 0;
    var podPhotoCount = 0;
    if (photos is List) {
      for (final item in photos) {
        if (item is Map && item['url'] != null) {
          final url = item['url'].toString().trim();
          final kind = item['kind']?.toString();
          if (kind == 'user_pickup') {
            if (url.isNotEmpty) customerPhotoUrls.add(url);
            continue;
          }
          if (url.isNotEmpty) photoUrls.add(url);
          if (kind == 'parcel_pickup') pickupPhotoCount++;
          if (kind == 'parcel_pod' || kind == 'drop_proof') podPhotoCount++;
        }
      }
    }

    final user = json['user'];
    final customerName = user is Map ? user['name']?.toString() : null;
    final customerPhone = user is Map ? user['phone']?.toString() : null;
    final contacts = json['contacts'] is Map
        ? Map<String, dynamic>.from(json['contacts'] as Map)
        : (json['meta'] is Map
              ? Map<String, dynamic>.from(json['meta'] as Map)
              : <String, dynamic>{});

    return PartnerTask(
      id: '${json['id']}',
      bookingId: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id']}'),
      orderCode: json['booking_number']?.toString() ?? '#${json['id']}',
      time: time.length > 16 ? time.substring(0, 16) : time,
      title: switch (offerLeg) {
        'pickup' => 'Pickup delivery',
        'drop' => 'Return delivery',
        _ => module is Map ? (module['name']?.toString() ?? 'Job') : 'Job',
      },
      distance: '',
      estEarning: () {
        // Show booking fare (customer total) — same amount user sees.
        final total = (json['total'] is num)
            ? (json['total'] as num).toDouble()
            : double.tryParse('${json['total']}');
        if (total != null && total > 0) return total;
        final earning = (json['partner_earning'] is num)
            ? (json['partner_earning'] as num).toDouble()
            : double.tryParse('${json['partner_earning']}');
        return earning ?? 0;
      }(),
      category: module is Map ? (module['slug']?.toString() ?? 'job') : 'job',
      pickup: lineOf(address),
      drop: lineOf(drop),
      status: mappedStatus,
      legType: legType,
      photoCount:
          (json['laundry_complete_photos_count'] as num?)?.toInt() ??
          photoUrls.length,
      photoUrls: photoUrls,
      customerPhotoUrls: customerPhotoUrls,
      customerName: customerName,
      customerPhone: customerPhone,
      legs: legMaps,
      notes: json['notes']?.toString(),
      pickupLat: coordOf(address, 'latitude'),
      pickupLng: coordOf(address, 'longitude'),
      dropLat: coordOf(drop, 'latitude'),
      dropLng: coordOf(drop, 'longitude'),
      isCash: json['payment_method']?.toString() == 'cash',
      paidBy: () {
        final fromContacts = contacts['paid_by']?.toString();
        if (fromContacts != null && fromContacts.isNotEmpty)
          return fromContacts;
        final meta = json['meta'];
        if (meta is Map && meta['paid_by'] != null)
          return meta['paid_by'].toString();
        return 'sender';
      }(),
      paymentMethod: json['payment_method']?.toString(),
      senderName: contacts['sender_name']?.toString(),
      senderPhone: contacts['sender_phone']?.toString(),
      receiverName: contacts['receiver_name']?.toString(),
      receiverPhone: contacts['receiver_phone']?.toString(),
      pickupPhotoCount: pickupPhotoCount,
      podPhotoCount: podPhotoCount,
      arrivedAtStop: arrivedAtStop,
      handoffOtp: json['handoff_otp']?.toString(),
      handoffOtpRequired: json['handoff_otp_required'] != false,
    );
  }

  PartnerUser userFromPartnerJson(
    Map<String, dynamic> json, {
    PartnerRole? preferredRole,
  }) {
    // Some responses nest the partner under `data` / `partner`.
    var source = json;
    if (source['phone'] == null &&
        source['mobile'] == null &&
        source['data'] is Map) {
      source = Map<String, dynamic>.from(source['data'] as Map);
    }
    if (source['phone'] == null &&
        source['mobile'] == null &&
        source['partner'] is Map) {
      source = Map<String, dynamic>.from(source['partner'] as Map);
    }

    final type = source['partner_type']?.toString();
    // Server role always wins. A locally picked role is only a signup fallback
    // when the account does not have a partner_type yet.
    final role = switch (type) {
      'business' => PartnerRole.business,
      'service' => PartnerRole.service,
      'delivery' => PartnerRole.delivery,
      _ => preferredRole ?? PartnerRole.delivery,
    };

    final rawPhone =
        source['phone']?.toString() ?? source['mobile']?.toString() ?? '';
    final mobile = rawPhone.replaceAll(RegExp(r'\D'), '');

    return PartnerUser(
      id: source['id'] is int
          ? source['id'] as int
          : int.tryParse('${source['id']}'),
      name: source['name']?.toString().isNotEmpty == true
          ? source['name'].toString()
          : 'Partner',
      mobile: mobile,
      email: source['email']?.toString(),
      avatarUrl: source['avatar_url']?.toString(),
      role: role,
      location: '',
      isOnline: source['is_online'] == true,
      rating: (source['rating_avg'] is num)
          ? (source['rating_avg'] as num).toDouble()
          : double.tryParse('${source['rating_avg']}') ?? 0,
      canOperate: source['can_operate'] == true,
      status: source['status']?.toString(),
      kycStatus: source['kyc_status']?.toString(),
      referralCode: source['referral_code']?.toString(),
    );
  }
}

/// Pickup/drop still waiting for a rider, and this partner does not already own a leg.
String? _openDeliveryOfferLeg(List<Map<String, dynamic>> legs, int? partnerId) {
  if (legs.isEmpty) return null;

  int? ownerId(Map<String, dynamic> leg) {
    final nested = leg['partner'];
    final raw = nested is Map ? nested['id'] : leg['partner_id'];
    if (raw == null || '$raw'.trim().isEmpty) return null;
    return raw is int ? raw : int.tryParse('$raw');
  }

  bool open(Map<String, dynamic> leg) {
    final status = leg['status']?.toString();
    return ownerId(leg) == null && (status == null || status == 'pending');
  }

  Map<String, dynamic>? ofType(String type) {
    for (final leg in legs) {
      if (leg['leg_type']?.toString() == type) return leg;
    }
    return null;
  }

  if (partnerId != null && legs.any((leg) => ownerId(leg) == partnerId)) {
    return null;
  }

  final laundry = ofType('laundry');
  final pickup = ofType('pickup');
  final drop = ofType('drop');

  if (pickup != null &&
      open(pickup) &&
      laundry != null &&
      ownerId(laundry) != null) {
    return 'pickup';
  }

  if (drop != null &&
      open(drop) &&
      laundry?['status']?.toString() == 'completed' &&
      (pickup == null || pickup['status']?.toString() == 'completed')) {
    return 'drop';
  }

  return null;
}

Map<String, dynamic>? _ownedRiderLeg(
  List<Map<String, dynamic>> legs,
  int? partnerId,
) {
  if (partnerId == null) return null;
  for (final type in ['pickup', 'drop']) {
    for (final leg in legs) {
      if (leg['leg_type']?.toString() != type) continue;
      if (_legOwnerId(leg) == partnerId) return leg;
    }
  }
  return null;
}

Map<String, dynamic>? _ownedLaundryLeg(
  List<Map<String, dynamic>> legs,
  int? partnerId,
) {
  if (partnerId == null) return null;
  for (final leg in legs) {
    if (leg['leg_type']?.toString() != 'laundry') continue;
    if (_legOwnerId(leg) == partnerId) return leg;
  }
  return null;
}

int? _legOwnerId(Map<String, dynamic> leg) {
  final nested = leg['partner'];
  final raw = nested is Map ? nested['id'] : leg['partner_id'];
  if (raw == null || '$raw'.trim().isEmpty) return null;
  return raw is int ? raw : int.tryParse('$raw');
}
