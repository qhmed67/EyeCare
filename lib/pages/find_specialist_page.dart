import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/specialist.dart';
import '../services/specialist_service.dart';

class FindSpecialistPage extends StatefulWidget {
  const FindSpecialistPage({super.key});

  @override
  State<FindSpecialistPage> createState() => _FindSpecialistPageState();
}

class _FindSpecialistPageState extends State<FindSpecialistPage> {
  final MapController _mapController = MapController();
  final SpecialistService _specialistService = SpecialistService();

  LatLng _currentPosition = const LatLng(30.0444, 31.2357); // Cairo default
  List<Specialist> _specialists = [];
  bool _isLoading = true;
  bool _hasPermission = false;
  bool _isOffline = false;
  bool _isFetching = false;
  bool _expandedSearch = false;
  String _currentGovernorate = "Detecting...";

  final PageController _pageController = PageController(viewportFraction: 0.85);
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
    _checkPermissionAndGetLocation();
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    setState(() {
      _isOffline = results.every((r) => r == ConnectivityResult.none);
    });
    if (!_isOffline && _specialists.isEmpty) {
      _getCurrentLocation();
    }
  }

  Future<void> _checkPermissionAndGetLocation() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      if (mounted) setState(() => _hasPermission = true);
      _getCurrentLocation();
    } else {
      if (mounted) {
        setState(() {
          _hasPermission = false;
          _isLoading = false;
        });
        _showManualSelectionInfo();
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    if (_isOffline) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final latLng = LatLng(position.latitude, position.longitude);
      final gov = await _specialistService.getGovernorate(
        latLng.latitude,
        latLng.longitude,
      );

      if (mounted) {
        setState(() {
          _currentPosition = latLng;
          _currentGovernorate = gov;
        });
        _mapController.move(latLng, 14);
      }

      _fetchSpecialists(latLng.latitude, latLng.longitude);
    } catch (e) {
      debugPrint("Error getting location: $e");
      _fetchSpecialists(_currentPosition.latitude, _currentPosition.longitude);
    }
  }

  Future<void> _fetchSpecialists(double lat, double lng) async {
    if (_isOffline || _isFetching) return;

    setState(() => _isFetching = true);
    if (mounted) setState(() => _isLoading = true);

    try {
      final results = await _specialistService.findNearbySpecialists(
        lat: lat,
        lng: lng,
        searchOutsideGovernorate: _expandedSearch,
      );
      if (mounted) {
        setState(() {
          _specialists = results;
        });
      }
    } catch (e) {
      debugPrint("Error fetching specialists: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isFetching = false;
          _isLoading = false;
        });
      }
    }
  }

  void _toggleExpandedSearch() {
    setState(() {
      _expandedSearch = !_expandedSearch;
      _specialists = [];
    });
    _fetchSpecialists(_currentPosition.latitude, _currentPosition.longitude);
  }

  Future<void> _openInMaps(double lat, double lng, String name) async {
    final Uri googleMapsUri = Uri.parse(
      Platform.isAndroid
          ? "geo:$lat,$lng?q=$lat,$lng($name)"
          : "https://www.google.com/maps/search/?api=1&query=$lat,$lng",
    );
    final Uri appleMapsUri = Uri.parse(
      "https://maps.apple.com/?q=$name&ll=$lat,$lng",
    );

    try {
      if (Platform.isIOS) {
        if (await canLaunchUrl(appleMapsUri)) {
          await launchUrl(appleMapsUri);
          return;
        }
      }

      if (await canLaunchUrl(googleMapsUri)) {
        await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
      } else {
        final Uri webUri = Uri.parse(
          "https://www.google.com/maps/search/?api=1&query=$lat,$lng",
        );
        if (await canLaunchUrl(webUri)) {
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      debugPrint("Error launching maps: $e");
    }
  }

  void _showManualSelectionInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Location denied. Showing default area."),
        backgroundColor: const Color(0xFF0F4C5C),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.outfitTextTheme(Theme.of(context).textTheme),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            _buildMap(),
            _buildAppBar(),
            _buildTopExpansionToggle(),
            if (_specialists.isNotEmpty) _buildCardOverlay(),
            if (_isLoading) _buildLoadingOverlay(),
            if (_isOffline) _buildOfflineBanner(),
            if (!_isLoading && !_isOffline) _buildStatusBanner(),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(initialCenter: _currentPosition, initialZoom: 14),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.eyecare.app',
        ),
        MarkerLayer(
          markers: _specialists.map((s) {
            final isLocal = s.governorate == _currentGovernorate;
            return Marker(
              point: LatLng(s.latitude, s.longitude),
              width: 45,
              height: 45,
              child: GestureDetector(
                onTap: () {
                  final index = _specialists.indexOf(s);
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: Icon(
                  Icons.local_hospital_rounded,
                  color: !isLocal
                      ? Colors.deepPurple
                      : (s.isEyeSpecialist
                            ? const Color(0xFF1B6F7A)
                            : Colors.blueGrey),
                  size: s.isEyeSpecialist ? 40 : 32,
                ),
              ),
            );
          }).toList(),
        ),
        if (_hasPermission)
          MarkerLayer(
            markers: [
              Marker(
                point: _currentPosition,
                width: 20,
                height: 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildAppBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 110,
        padding: const EdgeInsets.only(top: 50, left: 10, right: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF0F4C5C),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Intelligent Care Finder",
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F4C5C),
                  ),
                ),
                Text(
                  _isLoading
                      ? "Discovering nearby..."
                      : "$_currentGovernorate • ${_specialists.length} results",
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F4C5C)),
              onPressed: () => _getCurrentLocation(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopExpansionToggle() {
    return Positioned(
      top: 120,
      left: 20,
      right: 20,
      child: GestureDetector(
        onTap: _toggleExpandedSearch,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _expandedSearch ? const Color(0xFF0F4C5C) : Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
              ),
            ],
            border: Border.all(
              color: const Color(0xFF0F4C5C).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.travel_explore_rounded,
                size: 18,
                color: _expandedSearch ? Colors.white : const Color(0xFF0F4C5C),
              ),
              const SizedBox(width: 10),
              Text(
                "Search eye hospitals in other governorates",
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _expandedSearch
                      ? Colors.white
                      : const Color(0xFF0F4C5C),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    return Positioned(
      bottom: 240,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F2F1).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFB2DFDB)),
        ),
        child: Text(
          "This search prioritizes local eye-care relevance and proximity.",
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 10,
            color: const Color(0xFF00796B),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildCardOverlay() {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      height: 195,
      child: PageView.builder(
        controller: _pageController,
        itemCount: _specialists.length,
        onPageChanged: (index) {
          final s = _specialists[index];
          _mapController.move(LatLng(s.latitude, s.longitude), 15);
        },
        itemBuilder: (context, index) {
          final s = _specialists[index];
          return _buildSpecialistCard(s);
        },
      ),
    );
  }

  Widget _buildSpecialistCard(Specialist s) {
    final isLocal = s.governorate == _currentGovernorate;
    final primaryColor = !isLocal
        ? Colors.deepPurple
        : (s.isEyeSpecialist ? const Color(0xFF1B6F7A) : Colors.blueGrey);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: primaryColor.withValues(alpha: isLocal ? 0.2 : 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  !isLocal
                      ? "OUTSIDE GOVERNORATE"
                      : (s.isEyeSpecialist
                            ? "EYE SPECIALIST"
                            : "GENERAL MEDICINE"),
                  style: GoogleFonts.outfit(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                s.governorate,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            s.name,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F4C5C),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            "${s.distance?.toStringAsFixed(1)} km away • ${s.isEyeSpecialist ? 'Eye Care' : 'General Care'}",
            style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey[600]),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _openInMaps(s.latitude, s.longitude, s.name),
            icon: const Icon(Icons.directions_rounded, size: 16),
            label: const Text("Get Directions"),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.white.withValues(alpha: 0.7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF1B6F7A),
              strokeWidth: 3,
            ),
            const SizedBox(height: 25),
            Text(
              "Ranking by relevance...",
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: const Color(0xFF0F4C5C),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Positioned(
      top: 180,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.orange[50]!.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.orange[100]!),
        ),
        child: Row(
          children: [
            Icon(Icons.wifi_off_rounded, size: 18, color: Colors.orange[900]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Offline: Result discovery is restricted.",
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Colors.orange[900],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
