class DairyCustomer {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String deliveryZone;
  final String subscriptionPlan;
  final String milkPreference;
  final double walletBalance;
  final String status;
  final String joinedDate;
  final String? profileImageUrl;

  const DairyCustomer({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.deliveryZone,
    required this.subscriptionPlan,
    required this.milkPreference,
    required this.walletBalance,
    required this.status,
    required this.joinedDate,
    this.profileImageUrl,
  });

  DairyCustomer copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? deliveryZone,
    String? subscriptionPlan,
    String? milkPreference,
    double? walletBalance,
    String? status,
    String? joinedDate,
    String? profileImageUrl,
  }) {
    return DairyCustomer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      deliveryZone: deliveryZone ?? this.deliveryZone,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      milkPreference: milkPreference ?? this.milkPreference,
      walletBalance: walletBalance ?? this.walletBalance,
      status: status ?? this.status,
      joinedDate: joinedDate ?? this.joinedDate,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }
}
