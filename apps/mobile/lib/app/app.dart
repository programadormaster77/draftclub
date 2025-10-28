import 'package:flutter/material.dart';
import 'router.dart';
import 'theme.dart';

class DraftClubApp extends StatelessWidget {
  const DraftClubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DraftClub',
      theme: appTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
