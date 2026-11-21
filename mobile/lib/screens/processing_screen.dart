import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import 'result_screen.dart';

class ProcessingScreen extends StatefulWidget {
  final String query;
  const ProcessingScreen({super.key, required this.query});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen>
    with TickerProviderStateMixin {
  late AnimationController _orbController;
  late Animation<double> _orbAnim;

  int _currentStep = -1;
  bool _stepsFinished = false; // animation done, maybe still waiting on API
  bool _allDone = false;
  bool _hasError = false;
  String _errorDetail = '';
  int _runId = 0; // lets us ignore stale runs after Retry

  static const List<_AnalysisStep> _steps = [
    _AnalysisStep(
      icon: Icons.cleaning_services_rounded,
      label: 'Preprocessing text',
      detail: 'Language detection, normalizing, tokenizing...',
      color: Color(0xFF6366F1),
      duration: 600,
    ),
    _AnalysisStep(
      icon: Icons.psychology_rounded,
      label: 'Detecting intent',
      detail: 'Matching 11 intent categories...',
      color: Color(0xFF2563EB),
      duration: 700,
    ),
    _AnalysisStep(
      icon: Icons.layers_rounded,
      label: 'Identifying issues',
      detail: 'Multi-label classification in progress...',
      color: Color(0xFF0891B2),
      duration: 700,
    ),
    _AnalysisStep(
      icon: Icons.label_important_rounded,
      label: 'Extracting entities',
      detail: 'spaCy NER + regex pattern matching...',
      color: Color(0xFF059669),
      duration: 600,
    ),
    _AnalysisStep(
      icon: Icons.warning_amber_rounded,
      label: 'Evaluating urgency',
      detail: 'Scoring severity and priority level...',
      color: Color(0xFFD97706),
      duration: 500,
    ),
    _AnalysisStep(
      icon: Icons.sentiment_dissatisfied_rounded,
      label: 'Analysing sentiment',
      detail: 'VADER sentiment analysis running...',
      color: Color(0xFFDB2777),
      duration: 500,
    ),
    _AnalysisStep(
      icon: Icons.alt_route_rounded,
      label: 'Computing confidence',
      detail: 'Calibrating prediction probabilities...',
      color: Color(0xFF7C3AED),
      duration: 500,
    ),
    _AnalysisStep(
      icon: Icons.corporate_fare_rounded,
      label: 'Routing to departments',
      detail: 'Assigning departments and explanations...',
      color: Color(0xFF2563EB),
      duration: 600,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _orbAnim = Tween<double>(begin: 0, end: 1).animate(_orbController);
    _start();
  }

  @override
  void dispose() {
    _orbController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final myRun = ++_runId;
    setState(() {
      _currentStep = -1;
      _stepsFinished = false;
      _allDone = false;
      _hasError = false;
      _errorDetail = '';
    });

    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted || myRun != _runId) return;

    // Call the real backend in parallel with the animation.
    // Errors are captured here so they never become "unhandled".
    String? errorText;
    final apiFuture = ApiService.analyzeQuery(widget.query)
        .then<Map<String, dynamic>?>((v) => v)
        .catchError((Object e) {
      errorText = e.toString();
      return null;
    });

    for (int i = 0; i < _steps.length; i++) {
      if (!mounted || myRun != _runId) return;
      setState(() => _currentStep = i);
      await Future.delayed(Duration(milliseconds: _steps[i].duration));
    }

    if (!mounted || myRun != _runId) return;
    setState(() => _stepsFinished = true);

    final result = await apiFuture;
    if (!mounted || myRun != _runId) return;

    if (result == null) {
      setState(() {
        _hasError = true;
        _stepsFinished = false;
        _errorDetail = errorText ?? 'Unknown error';
      });
      return;
    }

    setState(() {
      _currentStep = _steps.length; // marks the last step complete
      _allDone = true;
    });
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted || myRun != _runId) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ResultScreen(
          query: widget.query,
          analysisResult: result,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060E1E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildOrb(),
              const SizedBox(height: 20),
              _buildTitle(),
              const SizedBox(height: 12),
              _buildQueryPreview(),
              const SizedBox(height: 16),
              Expanded(child: _buildStepsList()),
              if (_allDone) _buildDoneBar(),
              if (_hasError) _buildErrorCard(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrb() {
    return AnimatedBuilder(
      animation: _orbAnim,
      builder: (context, child) {
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              transform: GradientRotation(_orbAnim.value * 6.28),
              colors: _hasError
                  ? const [
                      Color(0xFFDC2626),
                      Color(0xFF7F1D1D),
                      Color(0xFFDC2626),
                    ]
                  : const [
                      Color(0xFF2563EB),
                      Color(0xFF6366F1),
                      Color(0xFF0891B2),
                      Color(0xFF059669),
                      Color(0xFF2563EB),
                    ],
            ),
            boxShadow: [
              BoxShadow(
                color: (_hasError
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF2563EB))
                    .withOpacity(0.4),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Color(0xFF060E1E),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _hasError
                  ? Icons.cloud_off_rounded
                  : Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTitle() {
    String title;
    String sub;
    if (_hasError) {
      title = 'Could not reach the AI';
      sub = 'The analysis did not complete';
    } else if (_allDone) {
      title = 'Analysis complete';
      sub = 'Routing to the right teams';
    } else if (_stepsFinished) {
      title = 'Almost there…';
      sub = 'Waiting for the AI server to respond';
    } else {
      title = 'Understanding your query…';
      sub = 'Our NLP pipeline is processing your message';
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Column(
        key: ValueKey(title),
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildQueryPreview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1E35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.format_quote_rounded,
            color: Color(0xFF2563EB),
            size: 14,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.query,
              style: GoogleFonts.inter(
                color: Colors.white60,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsList() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: List.generate(_steps.length, (index) {
          final step = _steps[index];
          final isDone = index < _currentStep;
          final isActive = index == _currentStep && !_hasError;
          final isPending = index > _currentStep;

          return AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: isPending ? 0.3 : 1.0,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isActive
                    ? step.color.withOpacity(0.08)
                    : const Color(0xFF0F1E35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive
                      ? step.color.withOpacity(0.4)
                      : const Color(0xFF1E3A5F),
                  width: isActive ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isDone
                          ? const Color(0xFF16A34A).withOpacity(0.15)
                          : isActive
                              ? step.color.withOpacity(0.15)
                              : const Color(0xFF1E3A5F),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: isDone
                        ? const Icon(
                            Icons.check_rounded,
                            color: Color(0xFF16A34A),
                            size: 16,
                          )
                        : isActive
                            ? Padding(
                                padding: const EdgeInsets.all(8),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: step.color,
                                ),
                              )
                            : Icon(step.icon, color: Colors.white24, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.label,
                          style: GoogleFonts.inter(
                            color: (isDone || isActive)
                                ? Colors.white
                                : Colors.white38,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isActive || isDone) ...[
                          const SizedBox(height: 2),
                          Text(
                            isDone ? '✓ Complete' : step.detail,
                            style: GoogleFonts.inter(
                              color: isDone
                                  ? const Color(0xFF16A34A)
                                  : step.color.withOpacity(0.8),
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isActive)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: step.color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: step.color.withOpacity(0.6),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDoneBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF16A34A).withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF16A34A),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            'Analysis complete, loading results',
            style: GoogleFonts.inter(
              color: const Color(0xFF16A34A),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    const red = Color(0xFFDC2626);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: red.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: red.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wifi_off_rounded, color: red, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cannot reach the AI server',
                  style: GoogleFonts.inter(
                    color: red,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Server: ${ApiService.baseUrl}\n'
            'Make sure the backend is running, and on a real phone set the '
            'Backend URL in Settings (laptop IP or tunnel link, not 127.0.0.1).',
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 11,
              height: 1.5,
            ),
          ),
          if (_errorDetail.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _errorDetail.length > 110
                  ? '${_errorDetail.substring(0, 110)}…'
                  : _errorDetail,
              style: GoogleFonts.inter(color: Colors.white24, fontSize: 10),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _start,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        'Retry',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF1E3A5F)),
                    ),
                    child: Center(
                      child: Text(
                        'Back',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnalysisStep {
  final IconData icon;
  final String label;
  final String detail;
  final Color color;
  final int duration;

  const _AnalysisStep({
    required this.icon,
    required this.label,
    required this.detail,
    required this.color,
    required this.duration,
  });
}