import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:servidom/main.dart';
import 'package:servidom/providers/auth_provider.dart';
import 'package:servidom/services/api_service.dart';

void main() {
  testWidgets('ServiDom affiche l’accueil', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = ApiService(prefs);
    final auth = AuthProvider(api, prefs);
    await auth.init();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiService>.value(value: api),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ],
        child: const ServiDomApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.textContaining('ServiDom'), findsWidgets);
  });
}
