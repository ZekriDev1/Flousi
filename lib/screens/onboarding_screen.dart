import 'package:flutter/material.dart';
import 'home_screen.dart';
import '../main.dart';
import 'login_screen.dart';
import '../utils/translations.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final primaryColor = const Color(0xFF003D1B);

  String _t(BuildContext context, String key) => FlousiTranslations.t(context, key);

  final List<Map<String, String>> _pages = [
    {
      'title': '', // Language page
      'subtitle': '',
      'image': 'assets/Animal/Language.png',
    },
    {
      'title': 'onboarding_1_title',
      'subtitle': 'onboarding_1_subtitle',
      'image': 'assets/Animal/suivez_vos_depenses.png',
    },
    {
      'title': 'onboarding_2_title',
      'subtitle': 'onboarding_2_subtitle',
      'image': 'assets/Animal/atteignez_vos_objectifs.png',
    },
    {
      'title': 'onboarding_3_title',
      'subtitle': 'onboarding_3_subtitle',
      'image': 'assets/Animal/AnimalePNG.png',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final appState = FlousiApp.of(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF1FAF7),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _pages.length,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildLanguagePage(appState);
                }
                return Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(_pages[index]['image']!, height: 280),
                      const SizedBox(height: 60),
                      Text(
                        _t(context, _pages[index]['title']!),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryColor),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _t(context, _pages[index]['subtitle']!),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, color: Colors.grey, height: 1.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      height: 8,
                      width: _currentPage == index ? 24 : 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index ? primaryColor : Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: () {
                    if (_currentPage == _pages.length - 1) {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                    } else {
                      _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    minimumSize: const Size(double.infinity, 64),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                  child: Text(
                    _currentPage == _pages.length - 1 ? _t(context, 'get_started') : _t(context, 'next'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguagePage(FlousiAppState appState) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/Animal/Language.png', height: 250),
          const SizedBox(height: 40),
          const Text(
            'Choisissez votre langue',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF003D1B)),
          ),
          const SizedBox(height: 10),
          const Text(
            'Choose your preferred language',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 40),
          _buildLangOption('Français', 'fr', appState),
          const SizedBox(height: 12),
          _buildLangOption('English', 'en', appState),
          const SizedBox(height: 12),
          _buildLangOption('العربية', 'ar', appState),
        ],
      ),
    );
  }

  Widget _buildLangOption(String label, String code, FlousiAppState appState) {
    bool isSelected = appState.locale.languageCode == code;
    return GestureDetector(
      onTap: () => appState.setLocale(Locale(code)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF003D1B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF003D1B) : Colors.grey.shade200, width: 2),
          boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF003D1B).withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))] : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : const Color(0xFF263238),
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}
