import 'package:QuizSphere/ads/services/rewarded_ad_service.dart';
import 'package:QuizSphere/login/login_screen.dart';
import 'package:QuizSphere/login/terms_and_condition/privacy_policy.dart';
import 'package:QuizSphere/login/terms_and_condition/terms_condition_screen.dart';
import 'package:QuizSphere/quizes/admin/screens/admin_daily_quiz_screen.dart';
import 'package:QuizSphere/quizes/home/home_screen.dart';
import 'package:QuizSphere/quizes/home/onboarding_screen.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'core/services/fcm_service.dart';
import 'features/deep_links/deep_link_handler.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables if needed
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('[dotenv] $e');
  }

  // Firebase is required before AuthWrapper starts
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('[Firebase Init Error] $e');
  }

  // Start Flutter UI immediately
  runApp(const ProviderScope(child: QuizApp()));

  // Perform non-critical initialization after UI appears
  _initializeBackgroundServices();
}

Future<void> _initializeBackgroundServices() async {
  // Mobile Ads
  try {
    // Google Play Families Policy: every ad request must be treated as
    // child-directed and limited to G-rated content. This MUST be set
    // BEFORE initialize() and before any ad is loaded.
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes,
        tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.yes,
        maxAdContentRating: MaxAdContentRating.g,
      ),
    );
    await MobileAds.instance.initialize();
    debugPrint('========== Mobile Ads Initialized ==========');
  } catch (e) {
    debugPrint('[Ads Init Error] $e');
  }

  // FCM
  if (!kIsWeb) {
    try {
      await FcmService.init();
    } catch (e) {
      debugPrint('[FCM] init skipped: $e');
    }
  }

  // Deep links
  if (!kIsWeb) {
    try {
      await DeepLinkHandler.init();
    } catch (e) {
      debugPrint('[DeepLink] init skipped: $e');
    }
  }

  // Preload rewarded ad without blocking startup
  if (!kIsWeb) {
    RewardedAdService.instance.loadAd();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class QuizApp extends StatelessWidget {
  const QuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: DeepLinkHandler.navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'QuizAura',

      // ── Named routes ──────────────────────────────────────────────────────
      routes: {
        '/privacy': (_) => const PrivacyPolicyScreen(),
        '/terms': (_) => const TermsConditionsScreen(),
      },

      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        appBarTheme: const AppBarTheme(
          color: Colors.teal,
          centerTitle: true,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AuthWrapper — routes to LoginScreen or HomeScreen based on auth state.
// ─────────────────────────────────────────────────────────────────────────────
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _timedOut = false;
  Stream<User?>? _authStream;

  // True once the stream delivers its first event (User or null).
  // The 8-second timeout must NOT fire after this point — doing so would
  // remove the StreamBuilder from the tree and cause us to miss subsequent
  // Firebase emissions (e.g. the real User arriving after an initial null).
  bool _streamEmitted = false;

  @override
  void initState() {
    super.initState();

    // Defence 1 — synchronous FirebaseAuth throw
    try {
      _authStream = FirebaseAuth.instance.authStateChanges().handleError((
        Object error,
        StackTrace stack,
      ) {
        debugPrint(
          '[AuthWrapper] authStateChanges error: $error\n'
          'Check: Firebase Console → Authentication → Settings\n'
          '       → Authorized Domains → ensure your domain is listed.',
        );
      });
    } catch (e) {
      debugPrint('[AuthWrapper] FirebaseAuth.instance threw: $e');
      Future.microtask(() {
        if (mounted) setState(() => _timedOut = true);
      });
    }

    // Defence 2 — 8-second timeout.
    // Only triggers if the stream has NEVER emitted.  This prevents the
    // timeout from racing with a valid (but slow) auth event and destroying
    // the StreamBuilder before Firebase can deliver the real User.
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && !_streamEmitted) {
        debugPrint(
          '[AuthWrapper] Timed out after 8s (stream never emitted) → LoginScreen',
        );
        setState(() => _timedOut = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_timedOut || _authStream == null) {
      return const LoginScreen();
    }

    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.waiting) {
          _streamEmitted = true; // stream is live — disable the timeout guard
          return _resolve(snapshot);
        }
        if (_timedOut) return const LoginScreen();
        return const _SplashScreen();
      },
    );
  }

  Widget _resolve(AsyncSnapshot<User?> snapshot) {
    if (snapshot.hasError) {
      debugPrint('[AuthWrapper] Resolved with error → LoginScreen');
      return const LoginScreen();
    }

    if (!snapshot.hasData) {
      return const LoginScreen();
    }

    final user = snapshot.data!;

    if (user.email == 'admin741@gmail.com') {
      return const AdminDailyQuizManagerScreen();
    }

    if (!kIsWeb) {
      FcmService.saveTokenForUser(user.uid);
      DeepLinkHandler.processPendingLink();
    }

    return const HomeScreen();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated Splash Screen
// ─────────────────────────────────────────────────────────────────────────────
class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scaleIn;
  late final AnimationController _spinCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;
  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _fadeIn = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _scaleIn = Tween<double>(
      begin: 0.88,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutBack));

    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _spinCtrl.dispose();
    _pulseCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080818),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0D0221),
                  Color(0xFF1A0533),
                  Color(0xFF0B1E6E),
                  Color(0xFF002040),
                ],
                stops: [0.0, 0.28, 0.58, 1.0],
              ),
            ),
          ),

          Positioned(
            top: -100,
            left: -80,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => _buildOrb(
                380,
                Color.lerp(
                  const Color(0x557B2FF7),
                  const Color(0x886A11CB),
                  _pulse.value,
                )!,
              ),
            ),
          ),

          Positioned(
            bottom: -60,
            right: -60,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => _buildOrb(
                300,
                Color.lerp(
                  const Color(0x442575FC),
                  const Color(0x6600C6FF),
                  _pulse.value,
                )!,
              ),
            ),
          ),

          Center(
            child: FadeTransition(
              opacity: _fadeIn,
              child: ScaleTransition(
                scale: _scaleIn,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 148,
                      height: 148,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _spinCtrl,
                            builder: (_, __) => Transform.rotate(
                              angle: _spinCtrl.value * 6.2832,
                              child: CustomPaint(
                                size: const Size(148, 148),
                                painter: _ArcPainter(
                                  color: const Color(0xFF00E5FF),
                                  opacity: 0.75,
                                  sweepFraction: 0.6,
                                  strokeWidth: 2.5,
                                ),
                              ),
                            ),
                          ),
                          AnimatedBuilder(
                            animation: _spinCtrl,
                            builder: (_, __) => Transform.rotate(
                              angle: -_spinCtrl.value * 6.2832 * 1.4,
                              child: CustomPaint(
                                size: const Size(114, 114),
                                painter: _ArcPainter(
                                  color: const Color(0xFF7B4FFF),
                                  opacity: 0.55,
                                  sweepFraction: 0.32,
                                  startAngle: 1.8,
                                  strokeWidth: 2.0,
                                ),
                              ),
                            ),
                          ),
                          AnimatedBuilder(
                            animation: _pulse,
                            builder: (_, __) => Container(
                              width: 102,
                              height: 102,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Color.lerp(
                                      const Color(0x307B4FFF),
                                      const Color(0x5000E5FF),
                                      _pulse.value,
                                    )!,
                                    const Color(0x15000040),
                                  ],
                                ),
                                border: Border.all(
                                  color: Color.lerp(
                                    const Color(0x3000E5FF),
                                    const Color(0x6600E5FF),
                                    _pulse.value,
                                  )!,
                                  width: 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color.lerp(
                                      const Color(0x2000E5FF),
                                      const Color(0x5500E5FF),
                                      _pulse.value,
                                    )!,
                                    blurRadius: 28,
                                    spreadRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          AnimatedBuilder(
                            animation: _pulse,
                            builder: (_, __) => Icon(
                              Icons.auto_awesome_rounded,
                              size: 50,
                              color: Color.lerp(
                                const Color(0xFF80D8FF),
                                const Color(0xFFFFFFFF),
                                _pulse.value,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    AnimatedBuilder(
                      animation: _shimmerCtrl,
                      builder: (_, __) {
                        final p = _shimmerCtrl.value;
                        return ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: const [
                              Color(0xFFA78BFA),
                              Color(0xFF00E5FF),
                              Color(0xFFFFFFFF),
                              Color(0xFF00E5FF),
                              Color(0xFFA78BFA),
                            ],
                            stops: [
                              0.0,
                              (p - 0.15).clamp(0.0, 1.0),
                              p.clamp(0.0, 1.0),
                              (p + 0.15).clamp(0.0, 1.0),
                              1.0,
                            ],
                          ).createShader(bounds),
                          child: const Text(
                            'QuizAura',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3.5,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 8),
                    const Text(
                      'KNOWLEDGE  ·  BATTLE  ·  CONQUER',
                      style: TextStyle(
                        color: Color(0x8800E5FF),
                        fontSize: 9.5,
                        letterSpacing: 3.5,
                        fontWeight: FontWeight.w300,
                      ),
                    ),

                    const SizedBox(height: 48),

                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) => SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color.lerp(
                              const Color(0xFF7B4FFF),
                              const Color(0xFF00E5FF),
                              _pulse.value,
                            )!,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 28,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeIn,
              child: const Text(
                'POWERED BY QUIZAURA',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0x30FFFFFF),
                  fontSize: 8,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrb(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, Colors.transparent]),
    ),
  );
}

class _ArcPainter extends CustomPainter {
  final Color color;
  final double opacity;
  final double sweepFraction;
  final double startAngle;
  final double strokeWidth;

  const _ArcPainter({
    required this.color,
    required this.opacity,
    required this.sweepFraction,
    this.startAngle = 0,
    this.strokeWidth = 2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final r = strokeWidth / 2;
    canvas.drawArc(
      Rect.fromLTWH(r, r, size.width - strokeWidth, size.height - strokeWidth),
      startAngle,
      sweepFraction * 6.2832,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter o) => false;
}
