import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/risk_result.dart';
import '../services/analysis_service.dart';

class AnalysisResultsPage extends StatefulWidget {
  final AnalysisOutput analysisOutput;
  final bool initialCloudEnsured;

  const AnalysisResultsPage({
    super.key,
    required this.analysisOutput,
    this.initialCloudEnsured = false,
  });

  @override
  State<AnalysisResultsPage> createState() => _AnalysisResultsPageState();
}

class _AnalysisResultsPageState extends State<AnalysisResultsPage> {
  bool _isEnsuring = false;
  late bool _isCloudEnsured;
  late List<RiskResult> _currentResults;
  final AnalysisService _analysisService = AnalysisService();

  @override
  void initState() {
    super.initState();
    _isCloudEnsured = widget.initialCloudEnsured;
    _currentResults = List.from(widget.analysisOutput.results ?? []);
  }

  Future<void> _runCloudEnsuring() async {
    final imagePath = widget.analysisOutput.imagePath;
    if (imagePath == null) return;

    setState(() => _isEnsuring = true);

    // Call Stage 2 Verification (Cloud API)
    final cloudResponse = await _analysisService.runCloudEnsuringStage(
      imagePath,
    );

    if (mounted) {
      if (cloudResponse != null && cloudResponse['eye_detected'] == true) {
        // Average measurements as per Step 4 of user requirements
        setState(() {
          _isEnsuring = false;
          _isCloudEnsured = true;
          _currentResults = _applyCloudEnhancement(
            _currentResults,
            cloudResponse,
          );
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Cloud verification complete: Indicators have been averaged for higher accuracy.",
            ),
            backgroundColor: Color(0xFF1B6F7A),
          ),
        );
      } else {
        setState(() => _isEnsuring = false);
        final errorMessage =
            cloudResponse?['notes'] ??
            "Cloud verification inconclusive. Please check your connection.";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  List<RiskResult> _applyCloudEnhancement(
    List<RiskResult> local,
    Map<String, dynamic> cloud,
  ) {
    return local.map((risk) {
      double cloudValue = 0;
      if (risk.condition == "Eye Fatigue") {
        cloudValue = (cloud['eye_fatigue_percent'] as num).toDouble();
      } else if (risk.condition == "Dry Eye Indicators") {
        cloudValue = (cloud['dry_eye_percent'] as num).toDouble();
      } else if (risk.condition == "Inflammation Indicators") {
        cloudValue = (cloud['inflammation_percent'] as num).toDouble();
      }

      // Formula: (local + cloud) / 2
      final averaged = (risk.riskPercentage + cloudValue) / 2;
      final newLabel = _getBalancedLabel(averaged);

      return risk.copyWith(
        riskPercentage: averaged,
        label: newLabel,
        colorCode: _getColorForLabel(newLabel),
      );
    }).toList();
  }

  String _getBalancedLabel(double score) {
    if (score > 85) return "High Indicator";
    if (score > 75) return "Moderate Indicator";
    return "Natural";
  }

  String _getColorForLabel(String label) {
    if (label == "High Indicator") return "#F44336";
    if (label == "Moderate Indicator") return "#FFC107";
    return "#4CAF50";
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF1B6F7A);
    const Color secondaryColor = Color(0xFF0F4C5C);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Analysis Results',
          style: GoogleFonts.outfit(
            color: secondaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: secondaryColor,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Disclaimer Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.amber[100]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange[800]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This app provides risk indicators, not diagnoses. Consult a doctor for any health concerns.',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: Colors.orange[900],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // System orientation - Local vs Cloud
            Row(
              children: [
                _buildSystemBadge(
                  "On-Device AI",
                  Icons.memory_rounded,
                  Colors.blue[700]!,
                ),
                const SizedBox(width: 8),
                if (_isCloudEnsured)
                  _buildSystemBadge(
                    "Cloud Verified",
                    Icons.cloud_done_rounded,
                    const Color(0xFF1B6F7A),
                  )
                else
                  _buildSystemBadge(
                    "Privacy First",
                    Icons.phonelink_lock_rounded,
                    Colors.teal[700]!,
                  ),
              ],
            ),

            const SizedBox(height: 24),

            Text(
              'Identified Risk Indicators',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: secondaryColor,
              ),
            ),

            const SizedBox(height: 16),

            // Result Cards
            ..._currentResults.map(
              (result) => _RiskIndicatorCard(result: result),
            ),

            const SizedBox(height: 24),

            // Stage 2: Cloud Ensuring Stage
            if (!_isCloudEnsured)
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: primaryColor,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Cloud Ensuring Stage',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: secondaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Let our secondary cloud algorithm verify these indicators to ensure they fall within natural ranges.',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: Colors.blueGrey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _runCloudEnsuring,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isEnsuring
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Ensure Results with Cloud'),
                      ),
                    ),
                  ],
                ),
              ),

            // Recommendation Card (Specialist)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [primaryColor, secondaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Need Professional Advice?',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You can find nearby eye specialists for a comprehensive check-up.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/find_specialist'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: secondaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Find a Specialist'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskIndicatorCard extends StatefulWidget {
  final RiskResult result;
  const _RiskIndicatorCard({required this.result});

  @override
  State<_RiskIndicatorCard> createState() => _RiskIndicatorCardState();
}

class _RiskIndicatorCardState extends State<_RiskIndicatorCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    const Color secondaryColor = Color(0xFF0F4C5C);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        widget.result.condition,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: secondaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      flex: 3,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Color(
                                  int.parse(
                                    widget.result.colorCode.replaceAll(
                                      '#',
                                      '0xFF',
                                    ),
                                  ),
                                ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                widget.result.label,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(
                                    int.parse(
                                      widget.result.colorCode.replaceAll(
                                        '#',
                                        '0xFF',
                                      ),
                                    ),
                                  ),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: Colors.grey,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Progress bar - maps risk level to visual representation
                _buildRiskProgressBar(widget.result),
                if (_isExpanded) ...[
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 10),
                  _buildDetailSection(
                    'Global Prevalence',
                    widget.result.prevalence,
                  ),
                  _buildDetailSection(
                    'Common Early Symptoms',
                    widget.result.commonSymptoms.join(', '),
                  ),
                  _buildDetailSection(
                    'Educational Insights',
                    widget.result.insights,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Confidence Score: ${(widget.result.confidenceScore * 100).toInt()}%',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1B6F7A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: Colors.blueGrey[700],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskProgressBar(RiskResult result) {
    // Map risk percentage to visual bar width
    // The scoring system uses: 0-75 = Low, 76-85 = Moderate, 86-100 = High
    // But visually, we want: Low = ~20%, Moderate = ~55%, High = ~85%
    double visualPercentage;

    if (result.riskPercentage <= 75) {
      // Low Risk: Map 0-75 → 10-25% visual
      visualPercentage = 0.10 + (result.riskPercentage / 75) * 0.15;
    } else if (result.riskPercentage <= 85) {
      // Moderate: Map 76-85 → 45-60% visual
      visualPercentage = 0.45 + ((result.riskPercentage - 76) / 9) * 0.15;
    } else {
      // High: Map 86-100 → 75-95% visual
      visualPercentage = 0.75 + ((result.riskPercentage - 86) / 14) * 0.20;
    }

    visualPercentage = visualPercentage.clamp(0.05, 0.95);

    final Color barColor = Color(
      int.parse(result.colorCode.replaceAll('#', '0xFF')),
    );

    return Stack(
      children: [
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        AnimatedFractionallySizedBox(
          duration: const Duration(seconds: 1),
          widthFactor: visualPercentage,
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
    );
  }
}
