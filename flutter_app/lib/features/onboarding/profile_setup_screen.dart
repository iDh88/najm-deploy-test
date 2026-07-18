import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/models/models.dart';
import '../../shared/constants/constants.dart';

// ─── Pending Approval Screen ──────────────────────────────────────────────────
class PendingApprovalScreen extends ConsumerWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: CIPTheme.grey50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  color: CIPTheme.warningAmberBg,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Center(
                  child: Text('⏳', style: TextStyle(fontSize: 44)),
                ),
              ),
              const SizedBox(height: 28),
              const Text('Account Under Review',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                    color: CIPTheme.grey900),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Your crew ID has been submitted for verification.\n\n'
                'An administrator will review your account and you will '
                'receive a push notification once approved.\n\n'
                'This usually takes less than 24 hours.',
                style: TextStyle(fontSize: 14, color: CIPTheme.grey700,
                    height: 1.6),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CIPTheme.grey200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.mail_outline, color: CIPTheme.saudiNavy),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Questions?', style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(AppConstants.supportEmail, style: const TextStyle(
                              color: CIPTheme.grey500, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  await ref.read(authServiceProvider).signOut();
                  if (context.mounted) context.go('/login');
                },
                child: const Text('Continue to app'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  await ref.read(authServiceProvider).signOut();
                  if (context.mounted) context.go('/login');
                },
                child: const Text('Sign out and try a different account'),
              ),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Sign in instead'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Profile Setup Screen ─────────────────────────────────────────────────────
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _crewIdController = TextEditingController();

  String _selectedBase = 'RUH';
  String _selectedRank = 'GD';
  bool _loading = false;
  bool _obscurePassword = true;

  static const _bases = ['RUH', 'JED', 'DMM'];

  // Official rank codes only
  static const _ranks = {
    'GD':  'GD — Guest Director',
    'PCA': 'PCA — Premium Cabin Crew',
    'BUT': 'BUT — Butler',
    'CHF': 'CHF — Chef',
    'SNF': 'SNF — Senior Cabin Attendant',
    'YCA': 'YCA — Economy Cabin Attendant',
    'CA':  'CA — Captain',
    'FO':  'FO — First Officer',
  };

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _crewIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CIPTheme.grey50,
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: CIPTheme.saudiNavy.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CIPTheme.saudiNavy.withOpacity(0.15)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: CIPTheme.saudiNavy, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your account will be reviewed by an admin before activation.',
                        style: TextStyle(fontSize: 12, color: CIPTheme.grey700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const Text('Personal Information',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              _buildField(_nameController, 'Full Name', 'e.g. Ahmed Al-Qahtani',
                validator: (v) => v!.trim().isEmpty ? 'Name required' : null),
              const SizedBox(height: 12),

              _buildField(_crewIdController, 'Crew ID', 'e.g. SA12345',
                keyboardType: TextInputType.text,
                validator: (v) => v!.trim().length < 4 ? 'Valid crew ID required' : null),
              const SizedBox(height: 12),

              _buildField(_emailController, 'Email Address', 'your.email@example.com',
                keyboardType: TextInputType.emailAddress,
                validator: (v) => !v!.contains('@') ? 'Valid email required' : null),
              const SizedBox(height: 12),

              _buildField(_passwordController, 'Password', 'Minimum 6 characters',
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                validator: (v) => v!.length < 6 ? 'Minimum 6 characters' : null),
              const SizedBox(height: 20),

              // Base station
              const Text('Base Station',
                style: TextStyle(fontSize: 13, color: CIPTheme.grey700)),
              const SizedBox(height: 8),
              Row(
                children: _bases.map((base) {
                  final selected = _selectedBase == base;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedBase = base),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: selected ? CIPTheme.saudiNavy : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected ? CIPTheme.saudiNavy : CIPTheme.grey200,
                          ),
                        ),
                        child: Center(
                          child: Text(base, style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: selected ? Colors.white : CIPTheme.grey700,
                          )),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Rank selection
              const Text('Rank', style: TextStyle(fontSize: 13, color: CIPTheme.grey700)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedRank,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: CIPTheme.grey200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: CIPTheme.grey200),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                items: _ranks.entries.map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value, style: const TextStyle(fontSize: 14)),
                )).toList(),
                onChanged: (v) => setState(() => _selectedRank = v!),
              ),
              const SizedBox(height: 32),

              if (_loading)
                const Center(child: CircularProgressIndicator())
              else
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submit,
                        child: const Text('Create Account',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Already have an account? Sign in'),
                    ),
                  ],
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, String hint, {
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CIPTheme.grey200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CIPTheme.grey200),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        crewId: _crewIdController.text.trim(),
        name: _nameController.text.trim(),
        nameAr: '',
        baseStation: _selectedBase,
        rank: CrewRank.values.firstWhere((r) => r.name == _selectedRank),
      );

      if (result.isSuccess && mounted) {
        await ref.read(authServiceProvider).signOut();
        context.go('/pending-approval');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.error ?? 'Registration failed'),
          backgroundColor: CIPTheme.violationRed,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}


// ─── Login Screen ─────────────────────────────────────────────────────────────
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() => _isLoading = true);

    final result = await ref.read(authServiceProvider).signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isSuccess) {
      context.go('/home');
    } else if (result.error == 'account_pending') {
      context.go('/pending-approval');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Login failed'),
          backgroundColor: CIPTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CIPTheme.grey50,
      appBar: AppBar(
        title: const Text('Sign In'),
        backgroundColor: CIPTheme.grey50,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 24),
            const Text(
              'Welcome back',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: CIPTheme.grey900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              onSubmitted: (_) => _isLoading ? null : _signIn(),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _signIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: CIPTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(56),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Sign In'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go('/profile-setup'),
              child: const Text('Create a new account'),
            ),
          ],
        ),
      ),
    );
  }
}
