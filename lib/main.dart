import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/session.dart';
import 'data/api.dart';
import 'ui/screens.dart';
import 'ui/budget_screen.dart';
import 'ui/entity_create_screen.dart';

final sessionProvider = Provider<Session>((ref) => throw UnimplementedError());
final apiProvider = Provider<Api>((ref) {
  final api = Api(ref.watch(sessionProvider));
  ref.onDispose(() => api.dio.close(force: true));
  return api;
});

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = Session();
  await session.restore();
  runApp(
    ProviderScope(
      overrides: [sessionProvider.overrideWithValue(session)],
      child: const NotaEntregaApp(),
    ),
  );
}

class NotaEntregaApp extends ConsumerStatefulWidget {
  const NotaEntregaApp({super.key});
  @override
  ConsumerState<NotaEntregaApp> createState() => _NotaEntregaAppState();
}

class _NotaEntregaAppState extends ConsumerState<NotaEntregaApp> {
  late final GoRouter router;
  late final Session session;
  @override
  void initState() {
    super.initState();
    session = ref.read(sessionProvider);
    router = GoRouter(
      refreshListenable: session,
      redirect: (context, state) {
        if (!session.signedIn) {
          return state.uri.path == '/login' ? null : '/login';
        }
        return state.uri.path == '/login' ? '/' : null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
        GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
        for (final kind in ['clients', 'products', 'notes', 'budgets'])
          GoRoute(
            path: '/$kind',
            builder: (_, _) => CatalogScreen(kind: kind),
          ),
        GoRoute(
          path: '/notes/new',
          builder: (_, _) => const CreateNoteScreen(),
        ),
        for (final kind in ['clients', 'products'])
          GoRoute(
            path: '/$kind/new',
            builder: (_, _) => EntityCreateScreen(kind: kind),
          ),
        GoRoute(
          path: '/budgets/new',
          builder: (_, _) => const CreateNoteScreen(budget: true),
        ),
        GoRoute(
          path: '/notes/:id',
          builder: (_, state) =>
              NoteScreen(id: int.tryParse(state.pathParameters['id']!) ?? -1),
        ),
        GoRoute(
          path: '/budgets/:id',
          builder: (_, state) =>
              BudgetScreen(id: int.tryParse(state.pathParameters['id']!) ?? -1),
        ),
      ],
    );
    session.addListener(clearData);
  }

  void clearData() {
    if (!ref.read(sessionProvider).signedIn) ref.invalidate(apiProvider);
  }

  @override
  void dispose() {
    session.removeListener(clearData);
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Nota Entrega Mobile',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xff176b61),
    ),
    routerConfig: router,
  );
}
