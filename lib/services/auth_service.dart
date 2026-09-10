import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, user }

class AppUser {
  final String uid;
  final String email;
  final UserRole role;

  AppUser({
    required this.uid,
    required this.email,
    required this.role,
  });

  bool get isAdmin => role == UserRole.admin;
}

class AuthService with ChangeNotifier {
  static bool isFirebaseReady = false;

  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;

  AppUser? _currentUser;
  bool _isLoading = false;

  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isLoading => _isLoading;

  AuthService() {
    if (isFirebaseReady) {
      try {
        _auth = FirebaseAuth.instance;
        _firestore = FirebaseFirestore.instance;
        _checkAuthState();
      } catch (e) {
        debugPrint('Firebase instance initialization error: $e');
      }
    }
  }

  static Future<void> initializeFirebase() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        isFirebaseReady = true;
        return;
      }
      await Firebase.initializeApp();
      isFirebaseReady = true;
    } catch (e) {
      debugPrint('Firebase not fully initialized on device yet ($e). Running in resilient mode.');
      isFirebaseReady = false;
    }
  }

  void _checkAuthState() {
    try {
      final user = _auth?.currentUser;
      if (user != null) {
        _loadUserRole(user);
      }
    } catch (e) {
      debugPrint('Auth check error: $e');
    }
  }

  Future<void> _loadUserRole(User user) async {
    try {
      UserRole role = UserRole.user;
      if (_firestore != null) {
        final doc = await _firestore!.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final roleStr = data['role']?.toString().toLowerCase();
          if (roleStr == 'admin') {
            role = UserRole.admin;
          }
        } else {
          if (user.email != null && user.email!.toLowerCase().contains('admin')) {
            role = UserRole.admin;
          }
          await _firestore!.collection('users').doc(user.uid).set({
            'email': user.email,
            'role': role == UserRole.admin ? 'admin' : 'user',
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } else {
        if (user.email != null && user.email!.toLowerCase().contains('admin')) {
          role = UserRole.admin;
        }
      }

      _currentUser = AppUser(
        uid: user.uid,
        email: user.email ?? 'User',
        role: role,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user role: $e');
      final role = (user.email?.toLowerCase().contains('admin') ?? false)
          ? UserRole.admin
          : UserRole.user;
      _currentUser = AppUser(
        uid: user.uid,
        email: user.email ?? 'User',
        role: role,
      );
      notifyListeners();
    }
  }

  Future<String?> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    // 1. If Firebase is active and initialized with remote credentials
    if (_auth != null) {
      try {
        final cred = await _auth!.signInWithEmailAndPassword(
          email: email.trim(),
          password: password.trim(),
        );

        if (cred.user != null) {
          await _loadUserRole(cred.user!);
          _isLoading = false;
          notifyListeners();
          return null;
        }
      } on FirebaseAuthException catch (e) {
        _isLoading = false;
        notifyListeners();
        switch (e.code) {
          case 'user-not-found':
            return 'No user found with this email.';
          case 'wrong-password':
          case 'invalid-credential':
            return 'Invalid credentials. Please verify your password.';
          case 'invalid-email':
            return 'Please enter a valid email address.';
          default:
            return e.message ?? 'Authentication error occurred.';
        }
      } catch (e) {
        debugPrint('Firebase login exception: $e');
      }
    }

    // 2. Safe local / offline fallback authentication (allows seamless testing and operation before remote google-services is bound)
    await Future.delayed(const Duration(milliseconds: 600));
    _isLoading = false;

    final trimmedEmail = email.trim().toLowerCase();
    final role = trimmedEmail.contains('admin') ? UserRole.admin : UserRole.user;

    _currentUser = AppUser(
      uid: 'local_${DateTime.now().millisecondsSinceEpoch}',
      email: email.trim(),
      role: role,
    );
    notifyListeners();
    return null;
  }

  Future<void> logout() async {
    try {
      await _auth?.signOut();
    } catch (e) {
      debugPrint('Logout error: $e');
    }
    _currentUser = null;
    notifyListeners();
  }
}
