import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  final _storage = const FlutterSecureStorage();
  
  // baseUrl of WebSocket like ws://10.0.2.2:8000/ws
  // In a real app we parse it from dotenv, but hardcoded here for simplicity:
  final String _wsUrl = 'wss://clix-taxi.onrender.com/ws'; 

  final StreamController<Map<String, dynamic>> _messageController = StreamController.broadcast();
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  bool _isConnected = false;

  void connect(String endpoint) async {
    if (_isConnected) return;
    
    final token = await _storage.read(key: 'access_token');
    if (token == null) return;

    final url = '$_wsUrl/$endpoint/?token=$token';

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _isConnected = true;

      _channel!.stream.listen(
        (data) {
          try {
            final decoded = jsonDecode(data);
            _messageController.add(decoded);
          } catch (e) {
            debugPrint("WS JSON Error: $e");
          }
        },
        onDone: () {
          _isConnected = false;
          _scheduleReconnect(endpoint);
        },
        onError: (error) {
          _isConnected = false;
          _scheduleReconnect(endpoint);
        },
      );
    } catch (e) {
      _isConnected = false;
      _scheduleReconnect(endpoint);
    }
  }

  void _scheduleReconnect(String endpoint) {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      connect(endpoint);
    });
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _isConnected = false;
  }
}
