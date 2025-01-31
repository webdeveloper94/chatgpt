import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Message {
  final String text;
  final bool isUser;
  final String? imageUrl;
  final DateTime timestamp;

  Message({
    required this.text,
    required this.isUser,
    this.imageUrl,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'isUser': isUser,
      'imageUrl': imageUrl,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      text: json['text'],
      isUser: json['isUser'],
      imageUrl: json['imageUrl'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class ChatService extends ChangeNotifier {
  final List<Message> _messages = [];
  bool _isLoading = false;
  final _supabase = Supabase.instance.client;

  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;

  Future<void> sendMessage(String text, {String? imageUrl}) async {
    if (text.trim().isEmpty && imageUrl == null) return;

    final userMessage = Message(
      text: text,
      isUser: true,
      imageUrl: imageUrl,
      timestamp: DateTime.now(),
    );

    _messages.add(userMessage);
    _isLoading = true;
    notifyListeners();

    try {
      // Save message to Supabase
      await _supabase.from('messages').insert(userMessage.toJson());

      // Send to ChatGPT API
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${dotenv.env['OPENAI_API_KEY']}',
        },
        body: jsonEncode({
          'model': 'gpt-4-vision-preview',
          'messages': [
            {
              'role': 'system',
              'content': 'Siz o\'zbek tilidagi suhbatdoshsiz. Foydalanuvchiga doimo o\'zbek tilida javob bering.',
            },
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': text},
                if (imageUrl != null)
                  {
                    'type': 'image_url',
                    'image_url': {'url': imageUrl},
                  },
              ],
            },
          ],
          'max_tokens': 500,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final botResponse = data['choices'][0]['message']['content'];

        final botMessage = Message(
          text: botResponse,
          isUser: false,
          timestamp: DateTime.now(),
        );

        _messages.add(botMessage);
        await _supabase.from('messages').insert(botMessage.toJson());
      } else {
        throw Exception('ChatGPT API xatosi');
      }
    } catch (e) {
      _messages.add(
        Message(
          text: 'Xatolik yuz berdi: $e',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMessages() async {
    try {
      final response = await _supabase
          .from('messages')
          .select()
          .order('timestamp', ascending: true);

      _messages.clear();
      _messages.addAll(
        (response as List).map((msg) => Message.fromJson(msg)).toList(),
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Xabarlarni yuklashda xatolik: $e');
    }
  }

  Future<String?> uploadImage(String filePath) async {
    try {
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final response = await _supabase.storage
          .from('chat_images')
          .upload('images/$fileName', File(filePath));

      final imageUrl = _supabase.storage
          .from('chat_images')
          .getPublicUrl('images/$fileName');

      return imageUrl;
    } catch (e) {
      debugPrint('Rasmni yuklashda xatolik: $e');
      return null;
    }
  }
}
