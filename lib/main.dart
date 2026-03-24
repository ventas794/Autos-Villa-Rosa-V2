import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/actividad_screen.dart';
import 'screens/coches_screen.dart';
import 'screens/citas_screen.dart';
import 'screens/login_screen.dart';

// ── Paleta de colores ───────────────────────────────────────────────────────
class AppColors {
  static const primaryBlue = Color(0xFF0053A0);
  static const primaryBlueDark = Color(0xFF003B7A);
  static const primaryBlueMedium = Color(0xFF1A6BB8);
  static const estadoPorLlegar = Color(0xFF0053A0);
  static const estadoDisponible = Color(0xFF43A047);
  static const estadoReservado = Color(0xFFB7950F);
  static const estadoVendido = Color(0xFFE53935);
  static const neutralGrey200 = Color(0xFFEEEEEE);
  static const neutralGrey400 = Color(0xFFBDBDBD);
  static const neutralGrey600 = Color(0xFF757575);
  static const textAlmostBlack = Color(0xFF111827);
  static const textSecondary = Color(0xFF4B5563);
  static const formLabelGrey = Colors.black54;
}

// ── Constantes de diseño ────────────────────────────────────────────────────
class AppConstants {
  static const double borderRadiusSmall = 8.0;
  static const double borderRadiusMedium = 12.0;
  static const double borderRadiusLarge = 16.0;
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double dialogTightPadding = 4.0;
  static const double formFieldVerticalSpacing = 6.0;
  static const double formInnerRadius = 8.0;
  static const double dialogMaxWidthCompact = 320.0;
  static const double dialogMaxHeightCompact = 480.0;
  static const double formLabelFontSize = 14.0;
  static const FontWeight formLabelFontWeight = FontWeight.w600;
  static const double iconSizeLarge = 40.0;
  static const double spacingSmall = 12.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 32.0;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: 'https://ablnbywlxynikfkhdvig.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFibG5ieXdseHluaWtma2hkdmlnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg1MDAyMzgsImV4cCI6MjA4NDA3NjIzOH0.oIr8aADi4LLHA62GWxwSsePefU_iaXZrKNbJp1YcCyc',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Autos Villa Rosa 2026',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', 'ES'), Locale('en', 'US')],
      locale: const Locale('es', 'ES'),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme(
          brightness: Brightness.light,
          primary: AppColors.primaryBlue,
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFE8F0FF),
          onPrimaryContainer: const Color(0xFF001B3D),
          secondary: const Color(0xFF6B7280),
          onSecondary: Colors.white,
          secondaryContainer: const Color(0xFFE5E7EB),
          onSecondaryContainer: const Color(0xFF1F2937),
          tertiary: AppColors.estadoDisponible,
          onTertiary: Colors.white,
          tertiaryContainer: const Color(0xFFE8F5E9),
          onTertiaryContainer: const Color(0xFF0F3D0F),
          surface: const Color(0xFFFAFCFF),
          onSurface: AppColors.textAlmostBlack,
          surfaceContainerHighest: const Color(0xFFF0F5FF),
          onSurfaceVariant: AppColors.textSecondary,
          outline: AppColors.neutralGrey400,
          shadow: const Color.fromRGBO(0, 0, 0, 0.10),
          error: const Color(0xFFDC2626),
          onError: Colors.white,
          inverseSurface: const Color(0xFF1F2937),
          onInverseSurface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF0F5FF),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              AppConstants.borderRadiusMedium,
            ),
            side: const BorderSide(color: AppColors.neutralGrey400, width: 0.8),
          ),
        ),
        listTileTheme: ListTileThemeData(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          titleTextStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textAlmostBlack,
          ),
          subtitleTextStyle: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
          iconColor: AppColors.primaryBlue,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
          ),
          titleTextStyle: const TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.w600,
            color: AppColors.textAlmostBlack,
          ),
          contentTextStyle: const TextStyle(
            fontSize: 14.0,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24.0,
            vertical: 20.0,
          ),
          actionsPadding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        ),
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: const TextStyle(
            fontSize: AppConstants.formLabelFontSize,
            fontWeight: AppConstants.formLabelFontWeight,
            color: AppColors.formLabelGrey,
          ),
          floatingLabelStyle: TextStyle(
            color: AppColors.primaryBlue,
            fontWeight: FontWeight.w600,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
            borderSide: const BorderSide(color: AppColors.neutralGrey400),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
            borderSide: const BorderSide(color: AppColors.neutralGrey400),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
            borderSide: const BorderSide(
              color: AppColors.primaryBlue,
              width: 2.0,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primaryBlue,
            textStyle: const TextStyle(fontSize: 14.0),
            minimumSize: const Size(100, 38),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            minimumSize: const Size(100, 38),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            textStyle: const TextStyle(fontSize: 14.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                AppConstants.borderRadiusSmall,
              ),
            ),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.primaryBlueDark,
          contentTextStyle: const TextStyle(color: Colors.white),
          behavior: SnackBarBehavior.floating,
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.textAlmostBlack,
          ),
          titleMedium: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textAlmostBlack,
          ),
          bodyLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
          bodyMedium: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textSecondary),
      ),
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final session = snapshot.data?.session;
          if (session != null) {
            return const MainScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  static const List<Widget> _screens = <Widget>[
    ActividadScreen(),
    CochesScreen(),
    CitasScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // Detectamos si es web (o pantalla muy ancha) para mostrar NavigationRail
    final bool isWide = MediaQuery.of(context).size.width >= 800;

    if (isWide) {
      // ── Versión WEB / Desktop / Tablet ancha ──
      return Scaffold(
        body: Row(
          children: [
            // Barra vertical a la izquierda con borde gris
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: AppColors.neutralGrey400,
                    width: 1.0,
                  ),
                ),
              ),
              child: NavigationRail(
                selectedIndex: _selectedIndex,
                onDestinationSelected: _onItemTapped,
                labelType: NavigationRailLabelType.all, // siempre visibles
                minWidth: 80,
                backgroundColor: Theme.of(context).colorScheme.surface,
                elevation: 6,
                useIndicator: true,
                indicatorColor: AppColors.primaryBlue.withValues(alpha: 0.15),
                selectedIconTheme: const IconThemeData(
                  color: AppColors.primaryBlue,
                  size: 28,
                ),
                unselectedIconTheme: IconThemeData(
                  color: AppColors.textSecondary,
                  size: 26,
                ),
                selectedLabelTextStyle: const TextStyle(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelTextStyle: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.timeline),
                    selectedIcon: Icon(Icons.timeline),
                    label: Text('Actividad'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.directions_car),
                    selectedIcon: Icon(Icons.directions_car),
                    label: Text('Coches'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.calendar_today),
                    selectedIcon: Icon(Icons.calendar_today),
                    label: Text('Citas'),
                  ),
                ],
              ),
            ),
            // Contenido principal (se expande para ocupar el resto)
            Expanded(child: _screens[_selectedIndex]),
          ],
        ),
      );
    } else {
      // ── Versión MÓVIL (Android/iOS) ──
      return Scaffold(
        body: _screens[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.timeline),
              label: 'Actividad',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.directions_car),
              label: 'Coches',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today),
              label: 'Citas',
            ),
          ],
          currentIndex: _selectedIndex,
          unselectedItemColor: AppColors.textSecondary,
          selectedItemColor: AppColors.primaryBlue,
          onTap: _onItemTapped,
        ),
      );
    }
  }
}
