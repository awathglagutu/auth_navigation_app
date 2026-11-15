import 'package:flutter/material.dart';

import 'config/api_config.dart';
import 'services/auth_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Log every endpoint URL to the debug console on startup.
  ApiConfig.debugPrintConfig();
  // Fire a background health-check so the first log line confirms reachability.
  AuthService().healthCheck();
  runApp(const AuthNavigationApp());
}

class AuthNavigationApp extends StatefulWidget {
  const AuthNavigationApp({super.key});

  @override
  State<AuthNavigationApp> createState() => _AuthNavigationAppState();
}

class _AuthNavigationAppState extends State<AuthNavigationApp> {
  final AuthService _auth = AuthService();
  late final Future<String?> _startup = _auth.savedToken();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aster',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF3949AB),
            surface: const Color(0xFFF8F9FC)),
        scaffoldBackgroundColor: const Color(0xFFF8F9FC),
        appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFF8F9FC),
            foregroundColor: Color(0xFF20243A),
            elevation: 0),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
          border: _inputBorder(const Color(0xFFDDE1EC)),
          enabledBorder: _inputBorder(const Color(0xFFDDE1EC)),
          focusedBorder: _inputBorder(const Color(0xFF3949AB), width: 1.6),
          errorBorder: _inputBorder(const Color(0xFFB3261E)),
        ),
        textTheme: const TextTheme(
            headlineMedium:
                TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.8)),
      ),
      home: FutureBuilder<String?>(
        future: _startup,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return LoginScreen(auth: _auth, startupLoading: true);
          }
          final token = snapshot.data;
          return token == null || token.isEmpty
              ? LoginScreen(auth: _auth)
              : DashboardScreen(auth: _auth, token: token);
        },
      ),
    );
  }
}

OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key, required this.auth});
  final AuthService auth;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _showPassword = false;
  bool _showConfirm = false;
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await widget.auth.register(
          name: _name.text, email: _email.text, password: _password.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Registration successful. Please log in.')));
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
          builder: (_) => LoginScreen(auth: widget.auth)));
    } on AuthApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
        child: Form(
          key: _formKey,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const _BrandHeader(),
            const SizedBox(height: 28),
            Text('Create your account',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text('A simple place to get started.',
                style: TextStyle(color: Color(0xFF697087))),
            const SizedBox(height: 24),
            TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline)),
                validator: _required),
            const SizedBox(height: 14),
            TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                    labelText: 'Email address',
                    prefixIcon: Icon(Icons.mail_outline)),
                validator: (value) {
                  final required = _required(value);
                  if (required != null) return required;
                  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                          .hasMatch(value!.trim())
                      ? null
                      : 'Enter a valid email address.';
                }),
            const SizedBox(height: 14),
            TextFormField(
                controller: _password,
                obscureText: !_showPassword,
                decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                        tooltip:
                            _showPassword ? 'Hide password' : 'Show password',
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                        icon: Icon(_showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined))),
                validator: (value) {
                  final required = _required(value);
                  if (required != null) return required;
                  return value!.length >= 6
                      ? null
                      : 'Use at least 6 characters.';
                }),
            const SizedBox(height: 14),
            TextFormField(
                controller: _confirm,
                obscureText: !_showConfirm,
                decoration: InputDecoration(
                    labelText: 'Confirm password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                        tooltip:
                            _showConfirm ? 'Hide password' : 'Show password',
                        onPressed: () =>
                            setState(() => _showConfirm = !_showConfirm),
                        icon: Icon(_showConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined))),
                validator: (value) {
                  final required = _required(value);
                  if (required != null) return required;
                  return value == _password.text
                      ? null
                      : 'Passwords do not match.';
                }),
            const SizedBox(height: 22),
            FilledButton(
                onPressed: _submitting ? null : _register,
                child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Text(
                        _submitting ? 'Creating account…' : 'Create account'))),
            const SizedBox(height: 12),
            Center(
                child: TextButton(
                    onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                            builder: (_) => LoginScreen(auth: widget.auth))),
                    child: const Text('Already have an account?  Log in'))),
          ]),
        ),
      );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen(
      {super.key, required this.auth, this.startupLoading = false});
  final AuthService auth;
  final bool startupLoading;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;
  bool _submitting = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final token =
          await widget.auth.login(email: _email.text, password: _password.text);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
              builder: (_) => DashboardScreen(auth: widget.auth, token: token)),
          (_) => false);
    } on AuthApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
        child: Form(
          key: _formKey,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const _BrandHeader(),
            const SizedBox(height: 40),
            Text('Welcome back',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text('Log in to continue to your account.',
                style: TextStyle(color: Color(0xFF697087))),
            const SizedBox(height: 28),
            TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                    labelText: 'Email address',
                    prefixIcon: Icon(Icons.mail_outline)),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter your email address.'
                    : null),
            const SizedBox(height: 16),
            TextFormField(
                controller: _password,
                obscureText: !_showPassword,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                        tooltip:
                            _showPassword ? 'Hide password' : 'Show password',
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                        icon: Icon(_showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined))),
                validator: (value) => value == null || value.isEmpty
                    ? 'Enter your password.'
                    : null),
            const SizedBox(height: 24),
            FilledButton(
                onPressed: _submitting || widget.startupLoading ? null : _login,
                child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Text(widget.startupLoading
                        ? 'Loading…'
                        : _submitting
                            ? 'Logging in…'
                            : 'Log in'))),
            const SizedBox(height: 12),
            Center(
                child: TextButton(
                    onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                            builder: (_) =>
                                RegistrationScreen(auth: widget.auth))),
                    child: const Text('Don’t have an account?  Register'))),
          ]),
        ),
      );
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.auth, required this.token});
  final AuthService auth;
  final String token;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<UserProfile> _profile = widget.auth.profile(widget.token);
  bool _loggingOut = false;
  bool _redirecting = false;

  void _retryProfile() =>
      setState(() => _profile = widget.auth.profile(widget.token));

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    await widget.auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => LoginScreen(auth: widget.auth)),
        (_) => false);
  }

  void _expireSession() {
    if (_redirecting) return;
    _redirecting = true;
    widget.auth.clearToken();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
              builder: (_) => LoginScreen(auth: widget.auth)),
          (_) => false);
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        child: Scaffold(
          appBar: AppBar(title: const Text('Aster')),
          body: SafeArea(
            child: FutureBuilder<UserProfile>(
              future: _profile,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  final error = snapshot.error;
                  if (error is AuthApiException && error.statusCode == 401) {
                    _expireSession();
                    return const Center(child: CircularProgressIndicator());
                  }
                  return _ProfileError(
                      message: error is AuthApiException
                          ? error.message
                          : 'Could not load your profile.',
                      onRetry: _retryProfile,
                      onLogout: _logout);
                }
                final user = snapshot.data!;
                return ListView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                    children: [
                      Container(
                          width: 58,
                          height: 58,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: const Color(0xFFE9ECFF),
                              borderRadius: BorderRadius.circular(18)),
                          child: const Icon(Icons.waving_hand_outlined,
                              color: Color(0xFF3949AB), size: 30)),
                      const SizedBox(height: 22),
                      Text('Welcome, ${user.name}!',
                          style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      const Text(
                          'You’re signed in. Here are your account details.',
                          style:
                              TextStyle(color: Color(0xFF697087), height: 1.5)),
                      const SizedBox(height: 28),
                      Card(
                          elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: const BorderSide(color: Color(0xFFE5E8F0)),
                          ),
                          child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      const Expanded(
                                          child: Text('Your profile',
                                              style: TextStyle(
                                                  fontSize: 17,
                                                  fontWeight:
                                                      FontWeight.w700))),
                                      Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                              color: const Color(0xFFE9ECFF),
                                              borderRadius:
                                                  BorderRadius.circular(30)),
                                          child: Text(user.role,
                                              style: const TextStyle(
                                                  color: Color(0xFF303F9F),
                                                  fontWeight: FontWeight.w600)))
                                    ]),
                                    const SizedBox(height: 22),
                                    _ProfileDetail(
                                        icon: Icons.person_outline,
                                        label: 'Full name',
                                        value: user.name),
                                    const Divider(height: 28),
                                    _ProfileDetail(
                                        icon: Icons.mail_outline,
                                        label: 'Email address',
                                        value: user.email),
                                  ]))),
                      const SizedBox(height: 28),
                      FilledButton.tonalIcon(
                          onPressed: _loggingOut ? null : _logout,
                          icon: const Icon(Icons.logout),
                          label: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                  _loggingOut ? 'Logging out…' : 'Log out'))),
                    ]);
              },
            ),
          ),
        ),
      );
}

class _ProfileError extends StatelessWidget {
  const _ProfileError(
      {required this.message, required this.onRetry, required this.onLogout});
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cloud_off_outlined,
                  size: 42, color: Color(0xFF697087)),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
              TextButton(onPressed: onLogout, child: const Text('Log out')),
            ])),
      );
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
              child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: child))),
        ),
      );
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: const Color(0xFF3949AB),
                borderRadius: BorderRadius.circular(15)),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white)),
        const SizedBox(width: 12),
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ASTER',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  color: Color(0xFF20243A))),
          SizedBox(height: 2),
          Text('Your account, in one place',
              style: TextStyle(fontSize: 12, color: Color(0xFF697087)))
        ]),
      ]);
}

class _ProfileDetail extends StatelessWidget {
  const _ProfileDetail(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: const Color(0xFFF1F2F8),
                borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: const Color(0xFF58617B))),
        const SizedBox(width: 13),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF697087))),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: Color(0xFF292D40)))
        ])),
      ]);
}
