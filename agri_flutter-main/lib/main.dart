import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/crop_disease_screen.dart';
import 'screens/chatbot_screen.dart';
import 'screens/marketplace_screen.dart';
import 'screens/orders_screen.dart';

void main() {
  runApp(const AgriApp());
}

class AgriApp extends StatelessWidget {
  const AgriApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agri Advisor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    CropDiseaseScreen(),
    ChatbotScreen(),
    MarketplaceScreen(),
    OrdersScreen(),
  ];

  void changeTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        onTap: (index) => changeTab(index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_florist),
            label: "Disease",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: "Chatbot"),
          BottomNavigationBarItem(icon: Icon(Icons.store), label: "Market"),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag),
            label: "Community",
          ),
        ],
      ),
    );
  }
}
