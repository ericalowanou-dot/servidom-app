import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constants/app_colors.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/admin/admin_screen.dart';
import 'screens/prestataire/add_service_screen.dart';
import 'screens/prestataire/edit_service_screen.dart';
import 'screens/prestataire/my_services_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/messages/chat_screen.dart';
import 'screens/messages/conversations_screen.dart';
import 'screens/reservation/reservation_detail_screen.dart';
import 'screens/reservation/reservation_screen.dart';
import 'models/service_model.dart';
import 'screens/services/prestataire_detail_screen.dart';
import 'screens/services/prestataires_screen.dart';
import 'services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final api = ApiService(prefs);
  final auth = AuthProvider(api, prefs);
  await auth.init();

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>.value(value: api),
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ],
      child: const ServiDomApp(),
    ),
  );
}

class ServiDomApp extends StatelessWidget {
  const ServiDomApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'ServiDom',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.appBarBackground,
          foregroundColor: AppColors.onAppBar,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          shadowColor: Colors.black26,
          centerTitle: false,
          iconTheme: const IconThemeData(color: AppColors.onAppBar),
          actionsIconTheme: const IconThemeData(color: AppColors.onAppBar),
          systemOverlayStyle: SystemUiOverlayStyle.light,
          titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.onAppBar,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          indicatorColor: AppColors.primary.withValues(alpha: 0.12),
          labelTextStyle: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.selected)) {
              return const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary);
            }
            return const TextStyle(color: AppColors.textSecondary);
          }),
        ),
      ),
      home: const AppGate(),
      routes: {
        HomeScreen.routeName: (_) => const HomeScreen(),
        LoginScreen.routeName: (_) => const LoginScreen(),
        RegisterScreen.routeName: (_) => const RegisterScreen(),
        ProfileScreen.routeName: (_) => const ProfileScreen(),
        AddServiceScreen.routeName: (_) => const AddServiceScreen(),
        EditProfileScreen.routeName: (_) => const EditProfileScreen(),
        MyServicesScreen.routeName: (_) => const MyServicesScreen(),
        AdminScreen.routeName: (_) => const AdminScreen(),
        ConversationsScreen.routeName: (_) => const ConversationsScreen(),
      },
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case ChatScreen.routeName:
            final args = settings.arguments as ChatArgs;
            return MaterialPageRoute<void>(
              builder: (_) => ChatScreen(
                reservationId: args.reservationId,
                titre: args.titre,
                autrePartie: args.autrePartie,
              ),
              settings: settings,
            );
          case ReservationDetailScreen.routeName:
            final args = settings.arguments as ReservationDetailArgs;
            return MaterialPageRoute<void>(
              builder: (_) => ReservationDetailScreen(reservation: args.reservation),
              settings: settings,
            );
          case EditServiceScreen.routeName:
            final service = settings.arguments as ServiceModel;
            return MaterialPageRoute<void>(
              builder: (_) => EditServiceScreen(service: service),
              settings: settings,
            );
          case PrestatairesScreen.routeName:
            final args = settings.arguments as PrestatairesArgs;
            return MaterialPageRoute<void>(
              builder: (_) => PrestatairesScreen(
                category: args.category,
                quartierFilter: args.quartierFilter,
              ),
              settings: settings,
            );
          case PrestataireDetailScreen.routeName:
            final args = settings.arguments as PrestataireDetailArgs;
            return MaterialPageRoute<void>(
              builder: (_) => PrestataireDetailScreen(
                prestataireId: args.prestataireId,
                initialServiceId: args.initialServiceId,
              ),
              settings: settings,
            );
          case ReservationScreen.routeName:
            final args = settings.arguments as ReservationArgs;
            return MaterialPageRoute<void>(
              builder: (_) => ReservationScreen(
                prestataireId: args.prestataireId,
                serviceId: args.serviceId,
                prestataireNom: args.prestataireNom,
                serviceTitre: args.serviceTitre,
                tarifHoraire: args.tarifHoraire,
              ),
              settings: settings,
            );
        }
        return null;
      },
    );
  }
}

/// Première vue : accueil marketing si invité, sinon accès direct aux services.
class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isAuthenticated) {
      return const HomeScreen();
    }
    return const WelcomeScreen();
  }
}
