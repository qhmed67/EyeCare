import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../models/specialist.dart';

class SpecialistService {
  final String _userAgent = "EyeCare_App_OSM_Search";

  // Broad categories for initial discovery (Performance-first)
  final List<String> _discoveryKeywords = [
    "Hospital",
    "Clinic",
    "Medical Center",
    "مستشفى",
    "عيادة",
    "مركز طبي",
  ];

  // Eye-specific semantic signals
  final List<String> _eyeSignals = [
    "العيون",
    "عيون",
    "بصريات",
    "رمد",
    "جراحة عيون",
    "أخصائي عيون",
    "طبيب عيون",
    "دكتور عيون",
    "Ophthalmology",
    "Ophthalmologist",
    "Eye",
    "Eye Clinic",
    "Eye Hospital",
    "Vision",
    "Optic",
    "Lasik",
    "Cornea",
  ];

  // Cache for governorate detection to save repeated reverse geocoding
  String? _cachedGov;
  double? _lastCacheLat;
  double? _lastCacheLng;

  Future<String> getGovernorate(double lat, double lng) async {
    // Basic caching logic (500m radius threshold for gov cache)
    if (_cachedGov != null && _lastCacheLat != null && _lastCacheLng != null) {
      double dist = Geolocator.distanceBetween(
        _lastCacheLat!,
        _lastCacheLng!,
        lat,
        lng,
      );
      if (dist < 500) return _cachedGov!;
    }

    final String url =
        "https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json&addressdetails=1";
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': _userAgent},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'];
        String gov =
            address['state'] ??
            address['province'] ??
            address['governorate'] ??
            address['city'] ??
            "Unknown";

        _cachedGov = gov;
        _lastCacheLat = lat;
        _lastCacheLng = lng;
        return gov;
      }
    } catch (e) {
      debugPrint("Reverse geocoding failed: $e");
    }
    return "Unknown";
  }

  Future<List<Specialist>> findNearbySpecialists({
    required double lat,
    required double lng,
    bool searchOutsideGovernorate = false,
  }) async {
    try {
      final DateTime startTime = DateTime.now();
      final String userGov = await getGovernorate(lat, lng);

      // BROAD DISCOVERY (Only 2-3 network calls max)
      // Grouping keywords into consolidated queries
      List<Specialist> rawDiscovery = [];
      Set<String> seenIds = {};

      final double delta = 0.5; // ~50km box
      final String viewbox =
          "${lng - delta},${lat + delta},${lng + delta},${lat - delta}";

      // Execute discovery queries in parallel for speed
      final List<Future<List<Specialist>>> futureResults = _discoveryKeywords
          .map((q) => _searchNominatim(q, viewbox, lat, lng))
          .toList();

      final List<List<Specialist>> resultsLists = await Future.wait(
        futureResults,
      );
      for (var list in resultsLists) {
        for (var s in list) {
          if (!seenIds.contains(s.id)) {
            rawDiscovery.add(s);
            seenIds.add(s.id);
          }
        }
      }

      // SEMANTIC CLASSIFICATION & EARLY FILTERING
      List<Specialist> eyeCareLocal = [];
      List<Specialist> generalLocal = [];
      List<Specialist> eyeCareOthers = [];

      for (var s in rawDiscovery) {
        bool isEye = _detectEyeSpecialty(s.name, s.specialty);
        bool inGov = s.governorate == userGov;

        // Create specialized copy if detected
        final specialist = s.copyWith(isEyeSpecialist: isEye);

        if (inGov) {
          if (isEye) {
            eyeCareLocal.add(specialist);
          } else {
            // Check if it's not a pharmacy/optics (retail)
            if (!_isUnrelated(s.name, s.specialty)) {
              generalLocal.add(specialist);
            }
          }
        } else if (searchOutsideGovernorate && isEye) {
          eyeCareOthers.add(specialist);
        }
      }

      // DISTANCE-FIRST RANKING (80% Proximity / 20% Semantic match if relevant)
      _rankResults(eyeCareLocal, lat, lng, isEyeContext: true);
      _rankResults(generalLocal, lat, lng, isEyeContext: false);
      _rankResults(eyeCareOthers, lat, lng, isEyeContext: true);

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint(
        "Google-Like Discovery completed in ${duration}ms with ${rawDiscovery.length} total results.",
      );

      return [...eyeCareLocal, ...generalLocal, ...eyeCareOthers];
    } catch (e) {
      debugPrint("Search failed: $e");
      return [];
    }
  }

  bool _detectEyeSpecialty(String name, String type) {
    final String combined = "$name $type".toLowerCase();
    return _eyeSignals.any((signal) => combined.contains(signal.toLowerCase()));
  }

  void _rankResults(
    List<Specialist> list,
    double lat,
    double lng, {
    required bool isEyeContext,
  }) {
    if (list.isEmpty) return;

    // Normalization factor for distance
    double maxDist = list.map((e) => e.distance ?? 0.0).reduce(max);
    if (maxDist < 1.0) maxDist = 1.0;

    list.sort((a, b) {
      double scoreA = _calculateSmartScore(a, maxDist, isEyeContext);
      double scoreB = _calculateSmartScore(b, maxDist, isEyeContext);
      return scoreB.compareTo(scoreA); // High score = first
    });
  }

  double _calculateSmartScore(Specialist s, double maxDist, bool isEyeContext) {
    // 80% weight on proximity
    double proximity = 1.0 - ((s.distance ?? 0.0) / maxDist);

    // 20% weight on semantic match strength
    double semanticMatch = 0.5; // baseline
    if (isEyeContext) {
      // Bonus if name specifically mentions "Eye/عيون" early or strongly
      if (s.name.toLowerCase().contains("eye") || s.name.contains("عيون")) {
        semanticMatch = 1.0;
      }
    }

    return (proximity * 0.8) + (semanticMatch * 0.2);
  }

  Future<List<Specialist>> _searchNominatim(
    String query,
    String viewbox,
    double userLat,
    double userLng,
  ) async {
    final String url =
        "https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&viewbox=$viewbox&bounded=1&addressdetails=1&limit=50";

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': _userAgent},
      );
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map<Specialist>((item) {
          final double sLat = double.parse(item['lat']);
          final double sLng = double.parse(item['lon']);
          final double dist =
              Geolocator.distanceBetween(userLat, userLng, sLat, sLng) / 1000;

          final addressData = item['address'] ?? {};
          final String gov =
              addressData['state'] ??
              addressData['province'] ??
              addressData['governorate'] ??
              addressData['city'] ??
              "Unknown";

          return Specialist(
            id: item['place_id'].toString(),
            name: item['display_name'].split(',')[0],
            specialty: "Medical Facility",
            rating: 0.0,
            reviewCount: 0,
            latitude: sLat,
            longitude: sLng,
            address: item['display_name'],
            isOpen: true,
            distance: dist,
            governorate: gov,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint("Query failed ($query): $e");
    }
    return [];
  }

  bool _isUnrelated(String name, String type) {
    final n = name.toLowerCase();
    final t = type.toLowerCase();
    final badKeywords = [
      "pharmacy",
      "صيدلية",
      "optical",
      "glasses",
      "نظارات",
      "صيدليه",
    ];
    return badKeywords.any((k) => n.contains(k) || t.contains(k));
  }
}
