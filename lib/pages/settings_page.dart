import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _cloudAiEnabled = true;
  bool _isOnline = true;
  bool _userManuallyDisabled = false;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkInitialConnectivity();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _checkInitialConnectivity() async {
    final List<ConnectivityResult> results = await Connectivity()
        .checkConnectivity();
    _updateConnectionStatus(results);
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final bool online = results.any(
      (result) => result != ConnectivityResult.none,
    );
    if (!mounted) return;
    setState(() {
      _isOnline = online;

      // Automatic behavior rule
      if (!_isOnline) {
        _cloudAiEnabled = false;
      } else {
        // If internet becomes available
        if (!_userManuallyDisabled) {
          _cloudAiEnabled = true;
        } else {
          _cloudAiEnabled = false; // Respect manual disable
        }
      }
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userManuallyDisabled =
          prefs.getBool('user_manually_disabled_cloud_ai') ?? false;
      // We don't load the state directly because it depends on connectivity too
    });
  }

  Future<void> _toggleCloudAi(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _cloudAiEnabled = value;
      _userManuallyDisabled = !value;
    });
    await prefs.setBool('user_manually_disabled_cloud_ai', !value);
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF1B6F7A);
    const Color secondaryColor = Color(0xFF0F4C5C);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: secondaryColor,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: secondaryColor,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cloud Verification',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: secondaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isOnline
                              ? "Ensuring stage available"
                              : "Offline: Stage 2 unavailable",
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: _isOnline
                                ? primaryColor
                                : Colors.orange[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Switch.adaptive(
                      value: _cloudAiEnabled,
                      activeThumbColor: primaryColor,
                      onChanged: _isOnline ? _toggleCloudAi : null,
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                const Divider(),
                const SizedBox(height: 15),
                Text(
                  'Enabled cloud-based verification as a secondary stage after the initial on-device scan. This ensures indicators are within natural ranges.',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: Colors.blueGrey[600],
                    height: 1.5,
                  ),
                ),
                if (!_isOnline) ...[
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange[100]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.wifi_off_rounded,
                          size: 18,
                          color: Colors.orange[900],
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Cloud AI requires an active internet connection.",
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: Colors.orange[900],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
