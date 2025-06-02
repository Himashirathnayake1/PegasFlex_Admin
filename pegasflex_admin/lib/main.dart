import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:pegasflex_admin/dashboard_page.dart';
import 'package:pegasflex_admin/firebase_options.dart';


Future<void> main() async {
    WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print('✅ Firebase connected!');
  runApp(const PegasFlexAdmin());
}

class PegasFlexAdmin extends StatelessWidget {
  const PegasFlexAdmin({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PegasFlex Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Helvetica',
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: DashboardPage(),
    );
  }
}
