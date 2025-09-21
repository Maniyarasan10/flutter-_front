import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  String weatherInfo = "Loading weather...";
  String weatherDescription = "";
  String temperature = "";
  String humidity = "";
  String windSpeed = "";
  IconData weatherIcon = Icons.wb_sunny;

  List<Map<String, String>> newsList = [];
  List<Map<String, dynamic>> quickActions = [];
  String userName = "prasanna";
  String location = "Chennai, Tamil Nadu";
  bool isLoading = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late PageController _bannerController;
  int currentBannerIndex = 0;

  /// Replace with your API key from https://openweathermap.org/
  final String weatherApiKey = "YOUR_OPENWEATHER_API_KEY";

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _bannerController = PageController();

    _initializeData();
    _startBannerAutoPlay();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _bannerController.dispose();
    super.dispose();
  }

  void _startBannerAutoPlay() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          currentBannerIndex = (currentBannerIndex + 1) % 3;
        });
        _bannerController.animateToPage(
          currentBannerIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        _startBannerAutoPlay();
      }
    });
  }

  Future<void> _initializeData() async {
    await Future.wait([fetchWeather(), fetchNews(), _loadQuickActions()]);

    setState(() {
      isLoading = false;
    });
    _animationController.forward();
  }

  /// 🌤️ Enhanced Weather Fetch
  Future<void> fetchWeather() async {
    try {
      final url =
          "https://api.openweathermap.org/data/2.5/weather?q=Chennai,in&appid=$weatherApiKey&units=metric";
      final res = await http.get(Uri.parse(url));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final temp = data["main"]["temp"].round();
        final condition = data["weather"][0]["description"];
        final weatherCode = data["weather"][0]["id"];
        final humidityValue = data["main"]["humidity"];
        final windValue = data["wind"]["speed"];

        setState(() {
          temperature = "$temp°C";
          weatherDescription = condition;
          humidity = "$humidityValue%";
          windSpeed = "${windValue.toStringAsFixed(1)} m/s";
          weatherIcon = _getWeatherIcon(weatherCode);
          weatherInfo = "$condition • $temp°C";
        });
      } else {
        setState(() {
          weatherInfo = "Unable to fetch weather";
        });
      }
    } catch (e) {
      setState(() {
        weatherInfo = "Weather unavailable";
        temperature = "25°C";
        weatherDescription = "Partly cloudy";
        humidity = "65%";
        windSpeed = "3.2 m/s";
      });
    }
  }

  IconData _getWeatherIcon(int weatherCode) {
    if (weatherCode >= 200 && weatherCode < 300) return Icons.thunderstorm;
    if (weatherCode >= 300 && weatherCode < 400) return Icons.grain;
    if (weatherCode >= 500 && weatherCode < 600) return Icons.beach_access;
    if (weatherCode >= 600 && weatherCode < 700) return Icons.ac_unit;
    if (weatherCode >= 700 && weatherCode < 800) return Icons.foggy;
    if (weatherCode == 800) return Icons.wb_sunny;
    return Icons.wb_cloudy;
  }

  /// 📰 Enhanced News Fetch
  Future<void> fetchNews() async {
    try {
      final dummyNews = [
        {
          "title": "New Agricultural Subsidy Scheme Launched",
          "subtitle": "Government announces ₹50,000 cr package for farmers",
          "time": "2 hours ago",
          "category": "Policy",
        },
        {
          "title": "Monsoon Update: Heavy Rainfall Expected",
          "subtitle": "IMD predicts 120% normal rainfall this season",
          "time": "4 hours ago",
          "category": "Weather",
        },
        {
          "title": "Organic Farming Success Stories",
          "subtitle": "Tamil Nadu farmers increase income by 40%",
          "time": "6 hours ago",
          "category": "Success",
        },
        {
          "title": "New Disease-Resistant Rice Variety",
          "subtitle": "Scientists develop drought-tolerant seeds",
          "time": "1 day ago",
          "category": "Technology",
        },
      ];
      setState(() {
        newsList = dummyNews;
      });
    } catch (e) {
      setState(() {
        newsList = [
          {
            "title": "Unable to load news",
            "subtitle": "Please check your internet connection",
            "time": "now",
            "category": "Error",
          },
        ];
      });
    }
  }

  Future<void> _loadQuickActions() async {
    quickActions = [
      {
        "title": "Soil Test",
        "icon": Icons.science,
        "color": Colors.brown,
        "route": "/soil-test",
      },
      {
        "title": "Weather Alert",
        "icon": Icons.notification_important,
        "color": Colors.orange,
        "route": "/weather-alerts",
      },
      {
        "title": "Price Check",
        "icon": Icons.trending_up,
        "color": Colors.green,
        "route": "/price-check",
      },
      {
        "title": "Expert Call",
        "icon": Icons.phone,
        "color": Colors.blue,
        "route": "/expert-call",
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    final List<_FeatureCard> features = [
      _FeatureCard(
        title: "Crop Disease",
        subtitle: "AI-powered diagnosis 🔬",
        icon: Icons.local_hospital,
        color: Colors.red,
        route: "/crop-disease",
        isNew: true,
      ),
      _FeatureCard(
        title: "AI Assistant",
        subtitle: "24/7 farming support 🤖",
        icon: Icons.smart_toy,
        color: Colors.blue,
        route: "/chatbot",
        isPopular: true,
      ),
      _FeatureCard(
        title: "Marketplace",
        subtitle: "Direct buyer connect 🛒",
        icon: Icons.storefront,
        color: Colors.orange,
        route: "/marketplace",
      ),
      _FeatureCard(
        title: "My Orders",
        subtitle: "Track deliveries 📦",
        icon: Icons.local_shipping,
        color: Colors.purple,
        route: "/orders",
      ),
      _FeatureCard(
        title: "Loan Center",
        subtitle: "Easy farm loans 💳",
        icon: Icons.account_balance,
        color: Colors.teal,
        route: "/loans",
      ),
      _FeatureCard(
        title: "Insurance",
        subtitle: "Crop protection 🛡️",
        icon: Icons.security,
        color: Colors.indigo,
        route: "/insurance",
      ),
    ];

    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FFF8),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.green.shade600,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Loading your farm dashboard...",
                style: GoogleFonts.poppins(
                  color: Colors.green.shade700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FFF8),
      body: CustomScrollView(
        slivers: [
          // Enhanced App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            pinned: true,
            backgroundColor: Colors.green.shade700,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.green.shade700, Colors.green.shade500],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.white,
                          radius: 25,
                          child: Text(
                            userName.split(' ').map((e) => e[0]).join(),
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Welcome back, ${userName.split(' ')[0]}! 👋",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    color: Colors.white70,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    location,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.notifications,
                            color: Colors.white,
                          ),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Main Content
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Enhanced Search
                    _buildSearchBar(),
                    const SizedBox(height: 20),

                    // Quick Actions
                    _buildQuickActions(),
                    const SizedBox(height: 20),

                    // Enhanced Weather Card
                    _buildWeatherCard(),
                    const SizedBox(height: 20),

                    // Enhanced Banner
                    _buildBannerSection(),
                    const SizedBox(height: 25),

                    // Features Section
                    _buildSectionHeader("Features", "Explore all tools"),
                    const SizedBox(height: 15),
                    _buildFeaturesGrid(features),

                    const SizedBox(height: 25),

                    // Today's Recommendations
                    _buildSectionHeader(
                      "Today's Recommendations",
                      "Personalized for you",
                    ),
                    const SizedBox(height: 15),
                    _buildRecommendations(),

                    const SizedBox(height: 25),

                    // Enhanced News Section
                    _buildSectionHeader("Agricultural News", "Stay updated"),
                    const SizedBox(height: 15),
                    _buildNewsSection(),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: "Search crops, diseases, market prices...",
          hintStyle: GoogleFonts.poppins(color: Colors.grey.shade500),
          prefixIcon: Icon(Icons.search, color: Colors.green.shade600),
          suffixIcon: Icon(Icons.mic, color: Colors.green.shade600),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.flash_on, color: Colors.orange.shade600, size: 20),
            const SizedBox(width: 8),
            Text(
              "Quick Actions",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: quickActions.length,
            itemBuilder: (context, index) {
              final action = quickActions[index];
              return Container(
                margin: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, action["route"]),
                  child: Container(
                    width: 70,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(action["icon"], color: action["color"], size: 24),
                        const SizedBox(height: 4),
                        Text(
                          action["title"],
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade400, Colors.blue.shade600],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(weatherIcon, size: 32, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      temperature,
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  weatherDescription.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _weatherDetail(Icons.water_drop, "Humidity", humidity),
                    const SizedBox(width: 16),
                    _weatherDetail(Icons.air, "Wind", windSpeed),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.agriculture, color: Colors.white, size: 24),
                  const SizedBox(height: 8),
                  Text(
                    "Perfect for\nFieldwork",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _weatherDetail(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(fontSize: 9, color: Colors.white70),
            ),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBannerSection() {
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView(
            controller: _bannerController,
            onPageChanged: (index) {
              setState(() {
                currentBannerIndex = index;
              });
            },
            children: [
              _bannerCard(
                "🌾 Perfect Weather for Harvesting!",
                "Check your crop readiness today",
                [Colors.green.shade400, Colors.green.shade600],
                Icons.agriculture,
              ),
              _bannerCard(
                "📱 AI Disease Detection",
                "Identify crop diseases instantly",
                [Colors.purple.shade400, Colors.purple.shade600],
                Icons.camera_alt,
              ),
              _bannerCard(
                "💰 Best Market Prices",
                "Connect directly with buyers",
                [Colors.orange.shade400, Colors.orange.shade600],
                Icons.trending_up,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            return Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: currentBannerIndex == index
                    ? Colors.green.shade600
                    : Colors.grey.shade300,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _bannerCard(
    String title,
    String subtitle,
    List<Color> colors,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: colors[0].withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Icon(icon, size: 40, color: Colors.white30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: () {},
          child: Text(
            "View All",
            style: GoogleFonts.poppins(
              color: Colors.green.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesGrid(List<_FeatureCard> features) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: features.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.9,
      ),
      itemBuilder: (context, index) {
        final feature = features[index];
        return GestureDetector(
          onTap: () => Navigator.pushNamed(context, feature.route),
          child: _featureTile(feature),
        );
      },
    );
  }

  Widget _featureTile(_FeatureCard feature) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: feature.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Icon(feature.icon, size: 28, color: feature.color),
                ),
                const SizedBox(height: 12),
                Text(
                  feature.title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  feature.subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          if (feature.isNew == true)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "NEW",
                  style: GoogleFonts.poppins(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          if (feature.isPopular == true)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "HOT",
                  style: GoogleFonts.poppins(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecommendations() {
    final recommendations = [
      {
        "title": "Fertilizer Application Guide",
        "subtitle": "Best practices for current season",
        "icon": Icons.grass,
        "color": Colors.green,
        "progress": 0.8,
      },
      {
        "title": "Pest Control Schedule",
        "subtitle": "Preventive measures for your crops",
        "icon": Icons.bug_report,
        "color": Colors.orange,
        "progress": 0.6,
      },
      {
        "title": "Water Management Tips",
        "subtitle": "Optimize irrigation efficiency",
        "icon": Icons.water_drop,
        "color": Colors.blue,
        "progress": 0.4,
      },
    ];

    return Column(
      children: recommendations.map((rec) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (rec["color"] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  rec["icon"] as IconData,
                  color: rec["color"] as Color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rec["title"] as String,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rec["subtitle"] as String,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: rec["progress"] as double,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        rec["color"] as Color,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNewsSection() {
    return Column(
      children: newsList.map((news) {
        Color categoryColor = _getCategoryColor(news["category"]!);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 60,
                  decoration: BoxDecoration(
                    color: categoryColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: categoryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              news["category"]!.toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: categoryColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            news["time"]!,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        news["title"]!,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        news["subtitle"]!,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.bookmark_border,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'policy':
        return Colors.blue;
      case 'weather':
        return Colors.orange;
      case 'success':
        return Colors.green;
      case 'technology':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

class _FeatureCard {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;
  final bool? isNew;
  final bool? isPopular;

  _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
    this.isNew,
    this.isPopular,
  });
}
