import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/analysis_service.dart';
import 'analysis_results_page.dart';

class AnalysisProcessingPage extends StatefulWidget {
  final File image;
  const AnalysisProcessingPage({super.key, required this.image});

  @override
  State<AnalysisProcessingPage> createState() => _AnalysisProcessingPageState();
}

class _AnalysisProcessingPageState extends State<AnalysisProcessingPage> {
  final List<String> _steps = [
    "Verifying eye presence...",
    "Validating image quality...",
    "Analyzing eye features...",
    "Generating risk indicators...",
  ];

  int _currentStep = 0;
  final AnalysisService _analysisService = AnalysisService();
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _startAnalysis();
    _simulateSteps();
  }

  void _simulateSteps() {
    Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (_currentStep < _steps.length - 1) {
        if (mounted) {
          setState(() {
            _currentStep++;
          });
        }
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _startAnalysis() async {
    debugPrint("Starting AI Analysis...");
    final result = await _analysisService.runAnalysis(widget.image);

    if (!mounted || _isNavigating) return;

    if (result.humanEyeDetected) {
      debugPrint("Analysis data ready. Navigating to Results.");
      _isNavigating = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => AnalysisResultsPage(analysisOutput: result),
        ),
      );
    } else {
      debugPrint("Analysis failed: No eye detected.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.errorMessage ??
                  "No eye detected. Please try again with a clear photo.",
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Delay slightly to let user see the message, then go back
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        _isNavigating = true;
        Navigator.of(context).pop(); // Go back to UploadPage
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF1B6F7A);
    const Color secondaryColor = Color(0xFF0F4C5C);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: CircularProgressIndicator(
                        strokeWidth: 8,
                        color: primaryColor.withValues(alpha: 0.2),
                        value: 1.0,
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: CircularProgressIndicator(
                        strokeWidth: 8,
                        color: primaryColor,
                        value: (_currentStep + 1) / _steps.length,
                      ),
                    ),
                    Image.asset(
                      'assets/images/eye.gif',
                      width: 120,
                      height: 120,
                    ),
                  ],
                ),
                const SizedBox(height: 60),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.psychology_rounded,
                        size: 16,
                        color: primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Local AI Scan Running',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: Text(
                    _steps[_currentStep],
                    key: ValueKey(_steps[_currentStep]),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: secondaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _currentStep == _steps.length - 1
                      ? 'Finishing up...'
                      : 'Estimated time: ${(_steps.length - 1 - _currentStep) * 5} seconds',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_steps.length, (index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: index == _currentStep ? 12 : 8,
                      height: index == _currentStep ? 12 : 8,
                      decoration: BoxDecoration(
                        color: index <= _currentStep
                            ? primaryColor
                            : Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
