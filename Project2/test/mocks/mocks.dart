// FILE: test/mocks/mocks.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Add this for signup
import 'package:go_router/go_router.dart';
import 'package:mockito/annotations.dart';

// This tells build_runner which classes to mock
@GenerateMocks([
  // Firebase Auth
  FirebaseAuth,
  UserCredential,
  User, // Add this for signup
  // Firestore
  FirebaseFirestore,
  CollectionReference,
  DocumentReference,
  // Navigation
  GoRouter,
])
void main() {} // This file needs a main function to be valid