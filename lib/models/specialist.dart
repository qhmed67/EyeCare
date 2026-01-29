class Specialist {
  final String id;
  final String name;
  final String specialty;
  final double rating;
  final int reviewCount;
  final double latitude;
  final double longitude;
  final String address;
  final bool isOpen;
  final double? distance; // distance in km
  final bool isEyeSpecialist;
  final String governorate;

  Specialist({
    required this.id,
    required this.name,
    required this.specialty,
    required this.rating,
    required this.reviewCount,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.isOpen,
    this.distance,
    this.isEyeSpecialist = false,
    this.governorate = '',
  });

  factory Specialist.fromJson(Map<String, dynamic> json) {
    return Specialist(
      id: json['place_id'] ?? '',
      name: json['name'] ?? '',
      specialty: 'Ophthalmologist',
      rating: (json['rating'] ?? 0.0).toDouble(),
      reviewCount: json['user_ratings_total'] ?? 0,
      latitude: json['geometry']['location']['lat'],
      longitude: json['geometry']['location']['lng'],
      address: json['vicinity'] ?? '',
      isOpen: json['opening_hours']?['open_now'] ?? false,
      isEyeSpecialist: true,
      governorate: '',
    );
  }

  Specialist copyWith({
    double? distance,
    bool? isEyeSpecialist,
    String? governorate,
  }) {
    return Specialist(
      id: id,
      name: name,
      specialty: specialty,
      rating: rating,
      reviewCount: reviewCount,
      latitude: latitude,
      longitude: longitude,
      address: address,
      isOpen: isOpen,
      distance: distance ?? this.distance,
      isEyeSpecialist: isEyeSpecialist ?? this.isEyeSpecialist,
      governorate: governorate ?? this.governorate,
    );
  }
}
