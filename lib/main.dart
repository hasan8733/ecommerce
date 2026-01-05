import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/auth/login_screen.dart';
import 'screens/user/user_main_screen.dart';
import 'screens/store/store_main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyDqi-wT2TnIde2rmkiqt3hdbIdB-yEcWUY",
      appId: "1:415934079690:web:840fa18d72cea87b758a33",
      messagingSenderId: "415934079690",
      projectId: "ecommerce-5437c",
      authDomain: "ecommerce-5437c.firebaseapp.com",
      storageBucket: "ecommerce-5437c.firebasestorage.app",
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData) {
            return FutureBuilder<String>(
              future: _getUserRole(snapshot.data!.uid),
              builder: (context, roleSnapshot) {
                if (roleSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                if (roleSnapshot.hasData) {
                  if (roleSnapshot.data == 'store') {
                    return const StoreMainScreen();
                  } else {
                    return const UserMainScreen();
                  }
                }

                return const LoginScreen();
              },
            );
          }

          return const LoginScreen();
        },
      ),
    );
  }

  Future<String> _getUserRole(String uid) async {
    // Check in users collection
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    if (userDoc.exists) {
      return userDoc.data()?['role'] ?? 'user';
    }

    // Check in stores collection
    final storeDoc =
        await FirebaseFirestore.instance.collection('stores').doc(uid).get();

    if (storeDoc.exists) {
      return storeDoc.data()?['role'] ?? 'store';
    }

    return 'user'; // Default to user
  }
}
