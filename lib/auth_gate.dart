import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'screens/events/event_list_screen.dart';

const Color _orange = Color(0xFFFF762E);
const Color _cream = Color(0xFFFFF9F5);
const Color _darkText = Color(0xFF2D2521);
const Color _mutedText = Color(0xFF94847A);
const Color _softPeach = Color(0xFFFFEADF);
const Color _border = Color(0xFFF0DFD3);

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Unable to check sign-in status.')),
          );
        }

        final user = snapshot.data;
        return user == null
            ? const AuthScreen()
            : EventListScreen(email: user.email ?? '');
      },
    );
  }
}

enum _AuthStage {
  welcome,
  login,
  createAccount,
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _AuthStage _stage = _AuthStage.welcome;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  bool get _isCreatingAccount => _stage == _AuthStage.createAccount;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showAuthOptions() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                  ),
                ),
                const _BrandMark(size: 64),
                const SizedBox(height: 20),
                Text(
                  'Welcome to EventHub',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: _darkText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Register for events and see the ones you booked.',
                  style: TextStyle(
                    color: _mutedText,
                    fontSize: 17,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _darkText,
                    ),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      setState(() {
                        _stage = _AuthStage.login;
                        _errorMessage = null;
                      });
                    },
                    child: const Text('Log in'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _softPeach,
                      foregroundColor: _darkText,
                    ),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      setState(() {
                        _stage = _AuthStage.createAccount;
                        _errorMessage = null;
                      });
                    },
                    child: const Text('Create an Account'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _goBack() {
    setState(() {
      _stage = _AuthStage.welcome;
      _errorMessage = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = FirebaseAuth.instance;
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (_isCreatingAccount) {
        final credential = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        await credential.user?.updateDisplayName(
          _nameController.text.trim(),
        );
      } else {
        await auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = switch (error.code) {
          'invalid-email' => 'Enter a valid email address.',
          'email-already-in-use' =>
          'An account already exists for this email.',
          'weak-password' => 'Choose a stronger password.',
          'user-not-found' ||
          'wrong-password' ||
          'invalid-credential' =>
          'Email or password is incorrect.',
          'network-request-failed' =>
          'Check your internet connection and try again.',
          _ => 'Unable to continue right now. Please try again.',
        };
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter your full name.';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || !value.trim().contains('@')) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.length < 6) {
      return 'Use at least 6 characters.';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value != _passwordController.text) {
      return 'The passwords do not match.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_stage == _AuthStage.welcome) {
      return _WelcomeScreen(onGetStarted: _showAuthOptions);
    }

    return _buildAuthForm();
  }

  Widget _buildAuthForm() {
    final title = _isCreatingAccount ? 'Create account' : 'Log in';
    final subtitle = _isCreatingAccount
        ? 'Sign up to book events and get your tickets.'
        : 'Use your email to see and book campus events.';

    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        leading: IconButton(
          onPressed: _goBack,
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _BrandMark(size: 64),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: _darkText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _mutedText,
                    fontSize: 17,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                if (_isCreatingAccount) ...[
                  _LabeledTextField(
                    label: 'Full name',
                    controller: _nameController,
                    hintText: 'Juan Dela Cruz',
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    validator: _validateName,
                  ),
                  const SizedBox(height: 18),
                ],
                _LabeledTextField(
                  label: 'Email',
                  controller: _emailController,
                  hintText: 'you@bulsu.edu.ph',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: _validateEmail,
                ),
                const SizedBox(height: 18),
                _LabeledTextField(
                  label: 'Password',
                  controller: _passwordController,
                  hintText: 'At least 6 characters',
                  obscureText: _obscurePassword,
                  textInputAction: _isCreatingAccount
                      ? TextInputAction.next
                      : TextInputAction.done,
                  validator: _validatePassword,
                  suffixIcon: IconButton(
                    tooltip:
                    _obscurePassword ? 'Show password' : 'Hide password',
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                if (_isCreatingAccount) ...[
                  const SizedBox(height: 18),
                  _LabeledTextField(
                    label: 'Confirm password',
                    controller: _confirmPasswordController,
                    hintText: 'Re-enter your password',
                    obscureText: _obscureConfirmPassword,
                    textInputAction: TextInputAction.done,
                    validator: _validateConfirmPassword,
                    suffixIcon: IconButton(
                      tooltip: _obscureConfirmPassword
                          ? 'Show password'
                          : 'Hide password',
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword =
                          !_obscureConfirmPassword;
                        });
                      },
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ],
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : Text(title),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        _isCreatingAccount
                            ? 'Already have an account? '
                            : 'New here? ',
                        style: const TextStyle(
                          color: _mutedText,
                          fontSize: 16,
                        ),
                      ),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                          setState(() {
                            _stage = _isCreatingAccount
                                ? _AuthStage.login
                                : _AuthStage.createAccount;
                            _errorMessage = null;
                          });
                        },
                        child: Text(
                          _isCreatingAccount
                              ? 'Log in'
                              : 'Create an account',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeScreen extends StatelessWidget {
  const _WelcomeScreen({required this.onGetStarted});

  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 44,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 24),
                    const _WelcomeIllustration(),
                    const SizedBox(height: 20),
                    Text(
                      'Find campus events.\nBook your spot.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: _darkText,
                        fontSize: 34,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Seminars, workshops and sports fests\nat BulSU, all in one app.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _mutedText,
                        fontSize: 17,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onGetStarted,
                        child: const Text('Get started'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WelcomeIllustration extends StatelessWidget {
  const _WelcomeIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 330,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 290,
            height: 290,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _orange.withOpacity(0.18),
                width: 1.5,
              ),
            ),
          ),
          Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _orange.withOpacity(0.18),
                width: 1.5,
              ),
            ),
          ),
          Container(
            width: 104,
            height: 104,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _orange,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: _orange.withOpacity(0.22),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const Text(
              'E',
              style: TextStyle(
                color: Colors.white,
                fontSize: 54,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const _FloatingIcon(
            icon: Icons.school_outlined,
            alignment: Alignment(-0.72, -0.72),
          ),
          const _FloatingIcon(
            icon: Icons.location_on_outlined,
            alignment: Alignment(0.72, -0.55),
          ),
          const _FloatingIcon(
            icon: Icons.mic_none,
            alignment: Alignment(-0.82, 0.12),
          ),
          const _FloatingIcon(
            icon: Icons.calendar_month_outlined,
            alignment: Alignment(-0.26, 0.66),
          ),
          const _FloatingIcon(
            icon: Icons.emoji_events_outlined,
            alignment: Alignment(0.62, 0.72),
          ),
        ],
      ),
    );
  }
}

class _FloatingIcon extends StatelessWidget {
  const _FloatingIcon({
    required this.icon,
    required this.alignment,
  });

  final IconData icon;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: _orange,
          size: 32,
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _orange,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Text(
        'E',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.58,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LabeledTextField extends StatelessWidget {
  const _LabeledTextField({
    required this.label,
    required this.controller,
    required this.hintText,
    required this.validator,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.suffixIcon,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final String? Function(String?) validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _darkText,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            suffixIcon: suffixIcon,
          ),
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          autocorrect: false,
          obscureText: obscureText,
          validator: validator,
        ),
      ],
    );
  }
}