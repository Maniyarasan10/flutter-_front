import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';

/// Base URL of your FastAPI backend
const String baseUrl = kIsWeb
    ? "http://127.0.0.1:8000"
    : "http://10.0.2.2:8000";

/// --------------------
/// MODELS
/// --------------------

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);
  @override
  String toString() =>
      'ApiException: $message${statusCode != null ? ' (HTTP $statusCode)' : ''}';
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
  @override
  String toString() => 'NetworkException: $message';
}

class Product {
  final int id;
  final String name;
  final double price;
  final String description;
  final String category; // Add this new field
  final String imageUrl; // Add this for images

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.category,
    required this.imageUrl,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      price: (json['price'] as num).toDouble(),
      description: json['description'] ?? '',
      category: json['category'] ?? 'All',
      imageUrl: json['imageUrl'] ?? 'https://via.placeholder.com/150',
    );
  }
}

class Order {
  final int id;
  final List<int> productIds;
  final double totalPrice;

  Order({required this.id, required this.productIds, required this.totalPrice});

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'],
      productIds: List<int>.from(json['product_ids']),
      totalPrice: (json['total_price'] as num).toDouble(),
    );
  }
}

/// Additional models for detailed chatbot responses (from Document 1)
class ChatResponse {
  final String answer;
  final double confidenceScore;
  final List<String> sources;
  final List<String> relatedTopics;
  final String responseType;

  ChatResponse({
    required this.answer,
    required this.confidenceScore,
    required this.sources,
    required this.relatedTopics,
    required this.responseType,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      answer: json['answer'] ?? '',
      confidenceScore: (json['confidence_score'] ?? 0.0).toDouble(),
      sources: List<String>.from(json['sources'] ?? []),
      relatedTopics: List<String>.from(json['related_topics'] ?? []),
      responseType: json['response_type'] ?? 'unknown',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'answer': answer,
      'confidence_score': confidenceScore,
      'sources': sources,
      'related_topics': relatedTopics,
      'response_type': responseType,
    };
  }
}

class HealthStatus {
  final String status;
  final String ragSystem;
  final int knowledgeBaseSize;
  final String timestamp;

  HealthStatus({
    required this.status,
    required this.ragSystem,
    required this.knowledgeBaseSize,
    required this.timestamp,
  });

  factory HealthStatus.fromJson(Map<String, dynamic> json) {
    return HealthStatus(
      status: json['status'] ?? 'unknown',
      ragSystem: json['rag_system'] ?? 'unknown',
      knowledgeBaseSize: json['knowledge_base_size'] ?? 0,
      timestamp: json['timestamp'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'rag_system': ragSystem,
      'knowledge_base_size': knowledgeBaseSize,
      'timestamp': timestamp,
    };
  }

  bool get isHealthy => status == 'healthy';
  bool get isRagEnabled => ragSystem == 'initialized';
}

/// --------------------
/// API SERVICE CLASS
/// --------------------

class ApiService {
  static const Duration timeoutDuration = Duration(seconds: 30);
  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
  };

  /// Generates a unique session ID.
  static String generateSessionId() {
    return const Uuid().v4();
  }

  // Headers for all requests
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // --- Disease Detection Methods ---

  /// 🌱 Disease Detection (Mobile)
  static Future<Map<String, dynamic>> detectDisease(File imageFile) async {
    final uri = Uri.parse("$baseUrl/predict");
    final request = http.MultipartRequest("POST", uri);
    request.files.add(
      await http.MultipartFile.fromPath(
        "file",
        imageFile.path,
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    try {
      final response = await request.send().timeout(timeoutDuration);
      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        return json.decode(respStr);
      } else {
        throw ApiException("Failed to detect disease", response.statusCode);
      }
    } on SocketException {
      throw NetworkException(
        'No Internet. Please check your network connection.',
      );
    } catch (e) {
      rethrow;
    }
  }

  /// 🌱 Disease Detection (Web)
  static Future<Map<String, dynamic>> detectDiseaseWeb(
    Uint8List imageBytes,
  ) async {
    final uri = Uri.parse("$baseUrl/disease/predict");
    final request = http.MultipartRequest("POST", uri);
    request.files.add(
      http.MultipartFile.fromBytes(
        "file",
        imageBytes,
        filename: "upload.jpg",
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    try {
      final response = await request.send().timeout(timeoutDuration);
      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        return json.decode(respStr);
      } else {
        throw ApiException("Failed to detect disease", response.statusCode);
      }
    } on SocketException {
      throw NetworkException(
        'No Internet. Please check your network connection.',
      );
    } catch (e) {
      rethrow;
    }
  }

  // --- Chatbot Methods (for compatibility with your other screen) ---
  static String generatesessionId() => const Uuid().v4();

  /// 🤖 AI Chatbot - Compatible with ChatbotScreen (Original method preserved)

  /// 🔄 Clear chat session

  /// 📝 Get chat history for a session
  /// 📝 Get chat history for a session
  static Future<List<Map<String, dynamic>>> getChatHistory(
    String sessionId,
  ) async {
    try {
      debugPrint('Getting chat history for session: $sessionId');

      final response = await http
          .get(
            Uri.parse(
              '$baseUrl/chatbot/conversation/history?session_id=$sessionId',
            ),
            headers: headers,
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // CORRECTED: The Python backend returns 'messages', not 'history'
        return List<Map<String, dynamic>>.from(data['messages'] ?? []);
      } else {
        debugPrint('Failed to get chat history: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Error getting chat history: $e');
      return [];
    }
  }

  /// 🎯 Smart chatbot query with fallback chain// REPLACE all existing 'askChatbot...' methods with this one.

  /// 🤖 AI Chatbot (Primary Method)
  static Future<String> askChatbot({
    required String message, // The parameter is named 'message'
    required String sessionId,
    required String language,
    required String question,
    String? context, // Optional context
    String? cropType, // Optional cropType
  }) async {
    try {
      debugPrint('Sending question: $question (Session: $sessionId)');

      // Dynamically build the request body
      Map<String, dynamic> requestBody = {
        // CORRECTED: Use 'message' to match the Python backend's ChatRequest model
        'message': question,
        'session_id': sessionId,
      };

      // Add optional parameters if they exist
      if (context != null) requestBody['context'] = context;
      if (cropType != null) requestBody['crop_type'] = cropType;

      final response = await http
          .post(
            // Use the consistent '/chatbot/chat' endpoint
            Uri.parse('$baseUrl/chatbot/chat'),
            headers: headers,
            body: json.encode(requestBody),
          )
          .timeout(timeoutDuration);

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // CORRECTED: The Python backend returns a key named 'reply'
        return data['reply'] ?? 'Sorry, I couldn\'t process your question.';
      } else {
        // Handle server errors more gracefully
        final errorData = json.decode(response.body);
        throw ApiException(
          errorData['detail'] ?? 'An unknown server error occurred.',
          response.statusCode,
        );
      }
    } on SocketException {
      throw NetworkException(
        'No internet connection. Please check your network.',
      );
    } on HttpException {
      throw NetworkException('Could not find the server. Please try again.');
    } on FormatException {
      throw ApiException('Bad response format from the server.');
    } catch (e) {
      debugPrint('Error in askChatbot: $e');
      rethrow; // Rethrow the original exception to be handled by the UI
    }
  }

  /// 🔊 Converts text to speech audio data.
  // Make sure 'static' is present here.
  /// 🔊 Converts text to speech audio data.
  static Future<Uint8List> textToSpeech({
    required String text,
    required String language,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/chatbot/text-to-speech'),
            headers: _headers,
            body: json.encode({'text': text, 'language': language}),
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        final errorData = json.decode(response.body);
        throw ApiException(
          errorData['detail'] ?? 'Failed to generate audio.',
          response.statusCode,
        );
      }
    } on SocketException {
      throw NetworkException(
        'No Internet: Please check your network connection.',
      );
    } catch (e) {
      debugPrint('Error in textToSpeech: $e');
      rethrow;
    }
  }

  /// 🔄 Clear chat session
  static Future<bool> clearChatSession(String sessionId) async {
    try {
      debugPrint('Clearing session: $sessionId');

      // CORRECTED: The Python backend expects a POST request with a specific body
      final response = await http
          .post(
            // Should be POST
            Uri.parse('$baseUrl/chatbot/conversation/clear'), // Correct path
            headers: headers,
            body: json.encode({
              'session_id': sessionId,
            }), // The backend expects this body
          )
          .timeout(timeoutDuration);

      debugPrint('Clear session status: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error clearing session: $e');
      return false; // Don't throw an error, it's not critical
    }
  }

  /// Check server health (Original method preserved)
  static Future<HealthStatus> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return HealthStatus.fromJson(data);
      } else {
        throw Exception('Health check failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Health check error: $e');
      throw Exception('Unable to connect to server: ${e.toString()}');
    }
  }

  /// Enhanced server health check with additional info
  static Future<Map<String, dynamic>> checkServerStatus() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/status'), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Status check failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Server status check error: $e');
      return {
        'status': 'offline',
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Get available topics from the knowledge base (Original method preserved)
  static Future<List<String>> getAvailableTopics() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/topics'), headers: headers)
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['available_topics'] ?? []);
      } else {
        throw Exception('Failed to fetch topics: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching topics: $e');
      return [
        'irrigation',
        'pest_control',
        'soil_management',
        'nutrition',
        'climate',
      ];
    }
  }

  /// Generate a unique session ID
  static String generatesSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final random =
        (DateTime.now().microsecond * 1000 + DateTime.now().millisecond)
            .toString();
    return '${timestamp}_$random';
  }

  /// Validate session ID format
  static bool isValidSessionId(String? sessionId) {
    if (sessionId == null || sessionId.isEmpty) return false;
    // Basic validation - should contain timestamp and random part
    return sessionId.contains('_') && sessionId.length > 10;
  }

  /// Enhanced offline fallback responses (Original method preserved with improvements)
  static String _getFallbackResponse(String question) {
    final lowerQuestion = question.toLowerCase();

    if (lowerQuestion.contains('water') ||
        lowerQuestion.contains('irrigation')) {
      return "🌱 Most crops need 1-1.5 inches of water per week. Water deeply but less frequently to encourage root growth. Check soil moisture before watering.";
    } else if (lowerQuestion.contains('pest') ||
        lowerQuestion.contains('insect')) {
      return "🐛 Try Integrated Pest Management (IPM) first. Use neem oil for soft-bodied insects. Encourage beneficial insects like ladybugs.";
    } else if (lowerQuestion.contains('soil') ||
        lowerQuestion.contains('fertilizer')) {
      return "🌾 Ensure soil pH is between 6.0-7.5 for most crops. Add organic matter regularly. Test soil every 2-3 years.";
    } else if (lowerQuestion.contains('weather') ||
        lowerQuestion.contains('climate')) {
      return "🌤️ Check local forecasts and avoid irrigation before rains. Use row covers for frost protection.";
    } else if (lowerQuestion.contains('disease') ||
        lowerQuestion.contains('fungus')) {
      return "🍄 Practice crop rotation and ensure good air circulation. Remove infected plant material promptly. Consider copper-based fungicides for organic treatment.";
    } else if (lowerQuestion.contains('seed') ||
        lowerQuestion.contains('planting')) {
      return "🌱 Choose disease-resistant varieties when possible. Plant at proper depth and spacing. Check seed germination rates before planting.";
    } else {
      return "🚜 I'm currently offline, but here's a general farming tip: Monitor crops weekly for early signs of disease or pest problems. Feel free to ask more specific questions when I'm back online!";
    }
  }

  /// Test connection to server (Original method preserved)
  static Future<bool> testConnection() async {
    try {
      await checkHealth();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Enhanced connection test with detailed results
  static Future<Map<String, dynamic>> testConnectionDetailed() async {
    final startTime = DateTime.now();

    try {
      final healthStatus = await checkHealth();
      final endTime = DateTime.now();
      final responseTime = endTime.difference(startTime).inMilliseconds;

      return {
        'connected': true,
        'response_time_ms': responseTime,
        'server_status': healthStatus.toJson(),
        'timestamp': endTime.toIso8601String(),
      };
    } catch (e) {
      final endTime = DateTime.now();
      final responseTime = endTime.difference(startTime).inMilliseconds;

      return {
        'connected': false,
        'response_time_ms': responseTime,
        'error': e.toString(),
        'timestamp': endTime.toIso8601String(),
      };
    }
  }

  // 🛒 Get All Products (SIMULATED with categories for demonstration)
  static Future<List<Product>> fetchProducts() async {
    // This part is modified to simulate a backend response with categories.
    // In a real app, your FastAPI backend would provide this data.
    return Future.value([
      Product(
        id: 1,
        name: "Organic Fertilizer",
        price: 299.0,
        description: "Rich in nitrogen and potassium.",
        category: "Fertilizers",
        imageUrl:
            "https://www.pennington.com/-/media/Project/OneWeb/Pennington/Images/blog/fertilizer/What-is-Organic-Fertilizer/orgainc-soil.jpg",
      ),
      Product(
        id: 2,
        name: "Hybrid Seeds Pack",
        price: 149.0,
        description: "High-yield, drought-resistant.",
        category: "Seeds",
        imageUrl:
            "https://www.urbanplant.in/cdn/shop/files/Collectionsofseedscopy_47dd2e49-3263-4a48-bba7-dcea2ee0ca75.webp?v=1697894652",
      ),
      Product(
        id: 3,
        name: "Drip Irrigation Kit",
        price: 899.0,
        description: "Water-efficient irrigation system.",
        category: "Equipment",
        imageUrl: "https://m.media-amazon.com/images/I/81majOaqVHL._SX522_.jpg",
      ),
      Product(
        id: 4,
        name: "Premium Potting Soil",
        price: 120.0,
        description: "Aerated and rich with nutrients.",
        category: "Soil Test",
        imageUrl:
            "https://midwesthearth.com/cdn/shop/files/Potting-Soil-Hero_530x@2x.jpg?v=1691440368",
      ),
      Product(
        id: 5,
        name: "Tomato Seeds",
        price: 85.0,
        description: "Heirloom variety, great for sauces.",
        category: "Seeds",
        imageUrl:
            "https://m.media-amazon.com/images/I/71dDw+dB5wL._AC_SL1500_.jpg",
      ),
      Product(
        id: 6,
        name: "Pesticide Spray",
        price: 450.0,
        description: "Organic pest control solution.",
        category:
            "Fertilizers", // Renaming from 'Pesticide' to fit a broad category
        imageUrl: "https://m.media-amazon.com/images/I/71BhENsQiXL.jpg",
      ),
      Product(
        id: 7,
        name: "Tractor",
        price: 250000.0,
        description: "Used tractor, low hours.",
        category: "Equipment",
        imageUrl:
            "https://wallpapercrafter.com/desktop6/1513697-john-deere-john-deere-2850-tractors-tractor-agriculture.jpg",
      ),
      Product(
        id: 8,
        name: "Soil pH Test Kit",
        price: 550.0,
        description: "Easy to use kit for pH testing.",
        category: "Soil Test",
        imageUrl:
            "https://img.crocdn.co.uk/images/products2/pr/20/00/04/95/pr2000049553.jpg?width=940&height=940",
      ),
    ]);
    // The original code is commented out below
    // final response = await http.get(Uri.parse("$baseUrl/products/all"));
    // if (response.statusCode == 200) {
    //   List<dynamic> data = jsonDecode(response.body);
    //   return data.map((item) => Product.fromJson(item)).toList();
    // } else {
    //   throw Exception("Failed to load products");
    // }
  }

  /// 📦 Create New Order
  static Future<Order> createOrder(List<int> productIds) async {
    final response = await http.post(
      Uri.parse("$baseUrl/orders/create"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(productIds),
    );

    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    } else {
      throw Exception("Failed to create order");
    }
  }

  /// 📜 Get All Orders
  static Future<List<Order>> fetchOrders() async {
    final response = await http.get(Uri.parse("$baseUrl/orders/all"));

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => Order.fromJson(item)).toList();
    } else {
      throw Exception("Failed to fetch orders");
    }
  }
}
