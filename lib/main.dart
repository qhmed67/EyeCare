import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'privacy_policy_page.dart';
import 'upload_page.dart';
import 'pages/settings_page.dart';
import 'pages/find_specialist_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final bool policyAccepted = prefs.getBool('policy_accepted') ?? false;

  runApp(EyeCareApp(initialRoute: policyAccepted ? '/upload' : '/'));
}

class EyeCareApp extends StatelessWidget {
  final String initialRoute;
  const EyeCareApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eye Care',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B6F7A),
          primary: const Color(0xFF1B6F7A),
          secondary: const Color(0xFF0F4C5C),
        ),
        useMaterial3: true,
      ),
      initialRoute: initialRoute,
      routes: {
        '/': (context) => const WelcomePage(),
        '/privacy': (context) => const PrivacyPolicyPage(),
        '/upload': (context) => const UploadPage(),
        '/settings': (context) => const SettingsPage(),
        '/find_specialist': (context) => const FindSpecialistPage(),
      },
    );
  }
}

class MorphingText extends StatelessWidget {
  final bool isMorphed;
  final String from;
  final String to;
  final TextStyle style;
  final Duration duration;

  const MorphingText({
    super.key,
    required this.isMorphed,
    this.from = "EyeCare",
    this.to = "ICare",
    required this.style,
    this.duration = const Duration(milliseconds: 800),
  });

  double _getTextWidth(String text, TextStyle style) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return textPainter.width;
  }

  @override
  Widget build(BuildContext context) {
    // Robust detection: split "EyeCare" or "Eye Care"
    String pFrom, pTo, sfx;
    double gap = 6.0; // Added visible gap for legibility

    if (from.contains(' ')) {
      final fParts = from.split(RegExp(r'\s+'));
      pFrom = fParts[0];
      sfx = fParts.length > 1 ? fParts.sublist(1).join(' ') : "Care";
      gap = 5.0;
    } else {
      // Logic for "EyeCare" -> "ICare"
      pFrom = from.startsWith("Eye") ? "Eye" : from;
      sfx = from.startsWith("Eye") ? from.substring(3) : "";
    }
    pTo = to.startsWith("I") ? "I" : to;

    final double wEye = _getTextWidth(pFrom, style);
    final double wI = _getTextWidth(pTo, style);
    final double wCare = _getTextWidth(sfx, style);
    final double fixedWidth = wEye + gap + wCare;

    return TweenAnimationBuilder<double>(
      duration: duration,
      tween: Tween<double>(begin: 0.0, end: isMorphed ? 1.0 : 0.0),
      curve: Curves.easeInOutQuart,
      builder: (context, t, child) {
        // Slide Care to the left to fill the space released by Eye shrinking to I
        final double careX = (wEye + gap) - (t * (wEye - wI));

        return SizedBox(
          width: fixedWidth,
          height: style.fontSize! * 1.6,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Prefix Morphing (Eye -> I)
              Positioned(
                left: 0,
                bottom: 4,
                child: Stack(
                  alignment: Alignment.bottomLeft,
                  children: [
                    Opacity(
                      opacity: (1.0 - (t * 1.5)).clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 1.0 - (0.2 * t),
                        alignment: Alignment.bottomLeft,
                        child: Text(pFrom, style: style),
                      ),
                    ),
                    Opacity(
                      opacity: ((t * 2.0) - 1.0).clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 0.9 + (0.1 * t),
                        alignment: Alignment.bottomLeft,
                        child: Text(pTo, style: style),
                      ),
                    ),
                  ],
                ),
              ),
              // Suffix Sliding (Care)
              Positioned(
                left: careX,
                bottom: 4,
                child: Text(sfx, style: style),
              ),
            ],
          ),
        );
      },
    );
  }
}

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool _isChecking = false;

  void _handleCheckEye() {
    setState(() {
      _isChecking = true;
    });
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/privacy');
        setState(() {
          _isChecking = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image from Main.png
          Positioned.fill(
            child: Image.asset(
              'assets/images/main_bg.png',
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Upper Half Container
                Expanded(
                  flex: 4,
                  child: Stack(
                    children: [
                      Positioned(
                        right: MediaQuery.of(context).size.width * 0.09 + 4,
                        top: MediaQuery.of(context).size.height * 0.00 - 7,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF1B6F7A,
                                ).withValues(alpha: _isChecking ? 0.3 : 0.1),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/eye.gif',
                            width: 193,
                            height: 193,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Grey Branding Title
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 1000),
                        tween: Tween(begin: 0.0, end: 1.0),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: Text(
                                'Smart\nEye Care',
                                style: GoogleFonts.robotoSlab(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF8B8B8B),
                                  height: 1.2,
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 15),

                      // 2. Teal Question
                      Text(
                        'What’s In Your Eye?',
                        style: GoogleFonts.robotoSlab(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1B6F7A),
                        ),
                      ),

                      const SizedBox(height: 15),

                      // 3. Morphing EyeCare (Matching Teal)
                      MorphingText(
                        isMorphed: _isChecking,
                        from: "EyeCare",
                        to: "ICare",
                        style: GoogleFonts.robotoSlab(
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: const Color.fromARGB(255, 9, 48, 58),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // 4. Enhanced Button "Let's Get Started"
                Padding(
                  padding: const EdgeInsets.fromLTRB(40, 0, 40, 60),
                  child: AnimatedScale(
                    scale: _isChecking ? 0.96 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: double.infinity,
                      height: 70,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1B6F7A), Color(0xFF0F4C5C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF1B6F7A,
                            ).withValues(alpha: 0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: _isChecking ? null : _handleCheckEye,
                          splashColor: Colors.white24,
                          child: Center(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                AnimatedOpacity(
                                  opacity: _isChecking ? 0 : 1,
                                  duration: const Duration(milliseconds: 300),
                                  child: const Text(
                                    'Let’s Get Started',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                if (_isChecking)
                                  const SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
