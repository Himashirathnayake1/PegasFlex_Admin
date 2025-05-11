import 'package:flutter/material.dart';
import 'package:pegasflex_admin/dashboard_page.dart';


void main() {
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
      home: const DashboardPage(),
    );
  }
}
