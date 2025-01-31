import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class Message {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  Message({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  String get content => text;
}

class ChatService extends ChangeNotifier {
  final List<Message> _messages = [];
  bool _isLoading = false;

  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;

  Future<void> sendMessage(String text) async {
    if (text.isEmpty) return;

    // Add user message
    _messages.add(Message(text: text, isUser: true));
    notifyListeners();

    _isLoading = true;
    notifyListeners();

    try {
      final response = await _sendToChatGPT(text);
      _messages.add(Message(text: response, isUser: false));
    } catch (e) {
      debugPrint('Xabar yuborishda xatolik: $e');
      _messages.add(Message(
        text: 'Xatolik yuz berdi. Iltimos, qayta urinib ko\'ring.',
        isUser: false,
      ));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String> _sendToChatGPT(String message) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null) {
      throw Exception('OPENAI_API_KEY topilmadi');
    }

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-3.5-turbo',
        'messages': [
          {'role': 'user', 'content': message}
        ],
        'temperature': 0.7,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception('ChatGPT API xatolik: ${response.statusCode}');
    }
  }

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }
}
