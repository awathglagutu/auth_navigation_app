import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:auth_navigation_app/main.dart';
import 'package:auth_navigation_app/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Flutter UI & Form Validation Tests', () {
    testWidgets('LoginScreen shows empty input validation errors', (tester) async {
      final auth = AuthService();
      await tester.pumpWidget(MaterialApp(home: LoginScreen(auth: auth)));

      // Tap login without filling anything
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();

      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
    });

    testWidgets('RegistrationScreen validates empty inputs, format and password match', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final auth = AuthService();
      await tester.pumpWidget(MaterialApp(home: RegistrationScreen(auth: auth)));

      final createAccountBtn = find.text('Create account');

      // Tap Register with empty inputs
      await tester.ensureVisible(createAccountBtn);
      await tester.tap(createAccountBtn);
      await tester.pumpAndSettle();

      expect(find.text('This field is required.'), findsNWidgets(4));

      // Enter invalid email format
      await tester.enterText(find.byType(TextFormField).at(0), 'John Doe');
      await tester.enterText(find.byType(TextFormField).at(1), 'bademail');
      await tester.ensureVisible(createAccountBtn);
      await tester.tap(createAccountBtn);
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email address.'), findsOneWidget);

      // Enter short password
      await tester.enterText(find.byType(TextFormField).at(1), 'john@example.com');
      await tester.enterText(find.byType(TextFormField).at(2), '123');
      await tester.ensureVisible(createAccountBtn);
      await tester.tap(createAccountBtn);
      await tester.pumpAndSettle();
      expect(find.text('Use at least 6 characters.'), findsOneWidget);

      // Enter mismatched passwords
      await tester.enterText(find.byType(TextFormField).at(2), 'password123');
      await tester.enterText(find.byType(TextFormField).at(3), 'mismatched123');
      await tester.ensureVisible(createAccountBtn);
      await tester.tap(createAccountBtn);
      await tester.pumpAndSettle();
      expect(find.text('Passwords do not match.'), findsOneWidget);
    });

    testWidgets('DashboardScreen displays Admin role badge and data', (tester) async {
      final mockClientAdmin = MockClient((request) async {
        return http.Response(
            jsonEncode({
              'success': true,
              'user': {
                'name': 'Administrator',
                'email': 'admin@demo.com',
                'role': 'Admin'
              }
            }),
            200,
            headers: {'content-type': 'application/json'});
      });

      final authAdmin = AuthService(client: mockClientAdmin);
      await tester.pumpWidget(MaterialApp(
          home: DashboardScreen(auth: authAdmin, token: 'admin_test_token')));
      await tester.pumpAndSettle();

      expect(find.text('Welcome, Administrator!'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('admin@demo.com'), findsOneWidget);
    });

    testWidgets('DashboardScreen displays Student role badge and data', (tester) async {
      final mockClientStudent = MockClient((request) async {
        return http.Response(
            jsonEncode({
              'success': true,
              'user': {
                'name': 'Jane Student',
                'email': 'jane@student.com',
                'role': 'Student'
              }
            }),
            200,
            headers: {'content-type': 'application/json'});
      });

      final authStudent = AuthService(client: mockClientStudent);
      await tester.pumpWidget(MaterialApp(
          home: DashboardScreen(auth: authStudent, token: 'student_test_token')));
      await tester.pumpAndSettle();

      expect(find.text('Welcome, Jane Student!'), findsOneWidget);
      expect(find.text('Student'), findsOneWidget);
      expect(find.text('jane@student.com'), findsOneWidget);
    });

    testWidgets('Logout invalidates session and navigates to LoginScreen', (tester) async {
      bool logoutCalled = false;
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('logout.php')) {
          logoutCalled = true;
          return http.Response(
              jsonEncode({'success': true, 'message': 'Logged out.'}), 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response(
            jsonEncode({
              'success': true,
              'user': {
                'name': 'Test User',
                'email': 'test@demo.com',
                'role': 'Student'
              }
            }),
            200,
            headers: {'content-type': 'application/json'});
      });

      SharedPreferences.setMockInitialValues({'aster_session_token_v1': 'valid_token'});
      final auth = AuthService(client: mockClient);

      await tester.pumpWidget(MaterialApp(
          home: DashboardScreen(auth: auth, token: 'valid_token')));
      await tester.pumpAndSettle();

      // Tap logout
      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();

      expect(logoutCalled, isTrue);
      // Confirmed navigated to LoginScreen
      expect(find.text('Welcome back'), findsOneWidget);
      // Stored token is cleared
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('aster_session_token_v1'), isNull);
    });
  });
}
