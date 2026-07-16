import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingPage(
      emoji: '📂',
      titleAr: 'Upload Your Monthly Roster',
      titleEn: 'Upload Your Monthly Roster',
      bodyAr:
          'Upload your monthly Excel file and Najm automatically analyses all available flight lines',
      bodyEn:
          'Upload your monthly Excel file and Najm automatically analyses all available flight lines instantly',
    ),
    _OnboardingPage(
      emoji: '⚖️',
      titleAr: 'Compare & Bid Intelligently',
      titleEn: 'Compare & Bid Intelligently',
      bodyAr:
          'Compare lines, check legality rules, and submit bids in one tap',
      bodyEn:
          'Compare lines, check legality rules, and submit bids in one tap — Najm validates legality automatically',
    ),
    _OnboardingPage(
      emoji: '🔄',
      titleAr: 'Trade Flights Safely',
      titleEn: 'Trade Flights Safely',
      bodyAr:
          'Post and accept trade requests with instant legality checks',
      bodyEn:
          'Post and accept trade requests with instant legality checks protecting your rest and safety',
    ),
    _OnboardingPage(
      emoji: '⭐',
      titleAr: 'Meet Najm AI',
      titleEn: 'Meet Najm AI',
      bodyAr:
          'Ask Najm in any language for instant recommendations',
      bodyEn:
          'Ask Najm in Arabic or English for instant recommendations that learn from your preferences',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: CIPTheme.grey50,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.go('/profile-setup'),
                child: const Text(
                  'Skip',
                  style: TextStyle(color: CIPTheme.grey500),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _pages[i],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Page indicator dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _currentPage ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _currentPage
                              ? CIPTheme.saudiNavy
                              : CIPTheme.grey300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      if (isLast) {
                        context.go('/profile-setup');
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    child: Text(
                      isLast ? 'Get Started' : 'Next',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final String emoji, titleAr, titleEn, bodyAr, bodyEn;

  const _OnboardingPage({
    required this.emoji,
    required this.titleAr,
    required this.titleEn,
    required this.bodyAr,
    required this.bodyEn,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 80)),
          const SizedBox(height: 32),
          Text(
            titleAr,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
              color: CIPTheme.saudiNavy,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            titleEn,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: CIPTheme.grey700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            bodyAr,
            style: const TextStyle(
              fontSize: 15,
              color: CIPTheme.grey700,
              height: 1.6,
              fontFamily: 'Inter',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            bodyEn,
            style: const TextStyle(
              fontSize: 13,
              color: CIPTheme.grey500,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
