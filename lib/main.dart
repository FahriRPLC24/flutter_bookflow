import 'package:flutter/material.dart';

import 'models/user.dart';
import 'screens/books_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/history_screen.dart';
import 'screens/loans_screen.dart';
import 'screens/login_screen.dart';
import 'screens/member/member_home_screen.dart';
import 'screens/members_screen.dart';
import 'screens/staff/loan_requests_screen.dart';
import 'screens/staff/reports_screen.dart';
import 'services/auth_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BookFlowApp());
}

class BookFlowApp extends StatelessWidget {
  const BookFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BookFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF283593)),
        scaffoldBackgroundColor: const Color(0xFFF5F6FB),
      ),
      home: const RootRouter(),
    );
  }
}

class RootRouter extends StatefulWidget {
  const RootRouter({super.key});
  @override
  State<RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<RootRouter> {
  final _auth = AuthService.instance;
  bool _loading = true;
  User? _user;

  @override
  void initState() {
    super.initState();
    authChanged.addListener(_onAuthChanged);
    _boot();
  }

  @override
  void dispose() {
    authChanged.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    setState(() {
      _user = _auth.currentUser;
    });
  }

  Future<void> _boot() async {
    final u = await _auth.restoreSession();
    if (!mounted) return;
    setState(() {
      _user = u;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_user == null) {
      return LoginScreen(onLoggedIn: (u) => setState(() => _user = u));
    }
    if (_user!.role == UserRole.petugas) {
      return const StaffShell();
    }
    return MemberShell(
      onLogout: () async {
        await AuthService.instance.logout();
      },
    );
  }
}

class StaffShell extends StatefulWidget {
  const StaffShell({super.key});
  @override
  State<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends State<StaffShell> {
  int _index = 0;

  static const List<Widget> _pages = [
    DashboardScreen(),
    BooksScreen(),
    MembersScreen(),
    LoansScreen(),
    HistoryScreen(),
    LoanRequestsScreen(),
    ReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Beranda'),
          NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Buku'),
          NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Anggota'),
          NavigationDestination(
              icon: Icon(Icons.swap_horiz),
              selectedIcon: Icon(Icons.swap_horiz),
              label: 'Pinjam'),
          NavigationDestination(
              icon: Icon(Icons.history),
              selectedIcon: Icon(Icons.history),
              label: 'Riwayat'),
          NavigationDestination(
              icon: Icon(Icons.assignment_turned_in_outlined),
              selectedIcon: Icon(Icons.assignment_turned_in),
              label: 'Ajuan'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Laporan'),
        ],
      ),
    );
  }
}