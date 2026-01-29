import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrivacyPolicyPage extends StatefulWidget {
  const PrivacyPolicyPage({super.key});

  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  bool _isAccepted = false;

  Future<void> _acceptPolicy() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('policy_accepted', true);
    if (mounted) {
      // For now, we'll just go back or show a success message since there's no "next" page yet
      // In a real flow, you'd navigate to the Home screen
      Navigator.of(context).pushReplacementNamed('/upload');
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF1B6F7A);
    const Color secondaryColor = Color(0xFF0F4C5C);
    const Color textColor = Color(0xFF2E2E2E);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 40),
              // Shield Icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  size: 80,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Privacy Policy',
                style: GoogleFonts.robotoSlab(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: secondaryColor,
                ),
              ),
              const SizedBox(height: 30),
              // Scrollable Policy Box
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.2),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPolicySection(
                            '1. Introduction',
                            'EyeCare AI is designed for educational and awareness purposes only. The App provides risk indicators related to eye health based on user-provided images and symptoms.',
                          ),
                          _buildPolicySection(
                            '2. No Medical Advice',
                            'The App does not provide medical diagnoses. Results are informational only and should not replace professional medical consultation. Users are strongly advised to consult a licensed healthcare professional for any concerns about their eye health.',
                          ),
                          _buildPolicySection(
                            '3. AI Model and Training',
                            'EyeCare AI uses an AI model trained to provide risk indicators. The AI is continuously improved and updated, but results may vary and are not guaranteed to be accurate.',
                          ),
                          _buildPolicySection(
                            '4. User Data',
                            'All data is processed on-device. No personal data or images are shared with third parties unless the user explicitly consents.',
                          ),
                          _buildPolicySection(
                            '5. Limitation of Liability',
                            'The developers and providers of EyeCare AI are not responsible for any decisions, actions, or consequences arising from the use of this App. The App cannot be held liable for any health-related outcomes.',
                          ),
                          _buildPolicySection(
                            '6. Acknowledgment',
                            'By using EyeCare AI, you acknowledge that you understand: The App provides risk indicators, not diagnoses. Professional consultation is essential for medical decisions. AI results may evolve over time as the model improves.',
                          ),
                          Text(
                            'Effective Date: January 18, 2026',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Checkbox row
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isAccepted = !_isAccepted;
                  });
                },
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Checkbox(
                      value: _isAccepted,
                      activeColor: primaryColor,
                      onChanged: (val) {
                        setState(() {
                          _isAccepted = val ?? false;
                        });
                      },
                    ),
                    Expanded(
                      child: Text(
                        'I have read and agree to all the terms of the Privacy Policy.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Next Button
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _isAccepted ? _acceptPolicy : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 5,
                  ),
                  child: Text(
                    'Next',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPolicySection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.robotoSlab(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F4C5C),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF2E2E2E),
              height: 1.5,
            ),
          ),
          const Divider(height: 24),
        ],
      ),
    );
  }
}

// Temporary Placeholder for the next page
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home Screen')),
      body: const Center(child: Text('You have accepted the policy!')),
    );
  }
}
