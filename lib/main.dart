import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'utils/notification_helper.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://jfyxkznmqbjluceppwmh.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpmeXhrem5tcWJqbHVjZXBwd21oIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM4NzUzMzEsImV4cCI6MjA4OTQ1MTMzMX0.3On0RX3CMtQcWxX81kBGufDfG2r_8MOgKihcxXkETbw',
  );

  // Initialize Local Notifications
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings();
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(const FlousiApp());
}

class FlousiApp extends StatefulWidget {
  const FlousiApp({super.key});

  @override
  State<FlousiApp> createState() => FlousiAppState();

  static FlousiAppState of(BuildContext context) =>
      context.findAncestorStateOfType<FlousiAppState>()!;
}

class FlousiAppState extends State<FlousiApp> {
  bool _isLoggedIn = false;
  Locale _locale = const Locale('fr');

  Locale get locale => _locale;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _setupAuthListener();
  }

  void _setupAuthListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      final event = data.event;

      debugPrint('Auth Event: $event');

      if (session != null) {
        setLoggedIn(true);
        // Navigate to home if we just signed in, token refreshed, or session recovered
        if (event == AuthChangeEvent.signedIn || 
            event == AuthChangeEvent.tokenRefreshed ||
            event == AuthChangeEvent.initialSession) {
          // Use a small delay to ensure navigator is ready
          Future.delayed(Duration.zero, () {
            navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
          });
        }
      }
    });
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final bool loggedIn = prefs.getBool('is_logged_in') ?? false;
    String? lang = prefs.getString('user_lang');
    
    // Check Supabase for language preference if logged in
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('language')
            .eq('id', user.id)
            .maybeSingle();
        if (profile != null && profile['language'] != null) {
          lang = profile['language'];
        }
      } catch (e) {
        debugPrint('Error fetching language from Supabase: $e');
      }
    }
    
    setState(() {
      _isLoggedIn = loggedIn;
      if (lang != null) _locale = Locale(lang);
    });

    // Schedule daily reminder after locale is set
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigatorKey.currentContext != null) {
        NotificationHelper.scheduleDailyReminder(navigatorKey.currentContext!);
      }
    });
  }

  void setLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', value);
    setState(() => _isLoggedIn = value);
  }

  void setLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_lang', locale.languageCode);
    
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        await Supabase.instance.client.from('profiles').update({
          'language': locale.languageCode,
        }).eq('id', user.id);
      } catch (e) {
        debugPrint('Error syncing language to Supabase: $e');
      }
    }
    
    setState(() => _locale = locale);

    // Reschedule reminder with new language
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigatorKey.currentContext != null) {
        NotificationHelper.scheduleDailyReminder(navigatorKey.currentContext!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Flousi',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: const [
        Locale('fr'),
        Locale('en'),
        Locale('ar'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF003D1B),
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF003D1B),
          primary: const Color(0xFF003D1B),
          secondary: const Color(0xFFC5A059),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
