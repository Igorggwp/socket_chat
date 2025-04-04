import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:web_socket_client/web_socket_client.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.name, required this.id});

  final String name;
  final String id;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final socket = WebSocket(Uri.parse('ws://10.200.74.57:8765'));
  final List<types.Message> _messages = [];
  late types.User me;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    me = types.User(id: widget.id, firstName: widget.name);

    socket.messages.listen((incomingMessage) {
      Map<String, dynamic> data = jsonDecode(incomingMessage);
      String id = data['id'];
      String msg = data['msg'];
      String nick = data['nick'] ?? id;

      var sender = types.User(id: id, firstName: nick);

      if (msg.startsWith('file://') || msg.endsWith('.jpg') || msg.endsWith('.png') || msg.endsWith('.gif')) {
        _addMessage(types.ImageMessage(
          author: sender,
          id: randomString(),
          uri: msg,
          name: 'Imagem',
          size: 0,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ));
      } else {
        _addMessage(types.TextMessage(
          author: sender,
          id: randomString(),
          text: msg,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ));
      }
    });
  }

  String randomString() {
    final random = Random.secure();
    return base64UrlEncode(List<int>.generate(16, (i) => random.nextInt(255)));
  }

  void _addMessage(types.Message message) {
    setState(() {
      _messages.insert(0, message);
    });
  }

  void _sendMessage(String text) {
    var payload = {'id': me.id, 'msg': text, 'nick': me.firstName};
    socket.send(json.encode(payload));

    if (text.startsWith('http') && (text.endsWith('.jpg') || text.endsWith('.png') || text.endsWith('.gif'))) {
      _addMessage(types.ImageMessage(
        author: me,
        id: randomString(),
        uri: text,
        name: 'Imagem',
        size: 0,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));
    } else {
      _addMessage(types.TextMessage(
        author: me,
        id: randomString(),
        text: text,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));
    }
  }

  void _handleSendPressed(types.PartialText message) {
    _sendMessage(message.text);
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final uri = image.path;
      final payload = {'id': me.id, 'msg': uri, 'nick': me.firstName};
      socket.send(json.encode(payload));

      _addMessage(types.ImageMessage(
        author: me,
        id: randomString(),
        uri: uri,
        name: image.name,
        size: await File(uri).length(),
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat: ${widget.name}', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: Icon(Icons.image, color: Colors.white),
            onPressed: _pickImage,
          ),
        ],
      ),
      body: Chat(
        messages: _messages,
        user: me,
        showUserAvatars: true,
        showUserNames: true,
        onSendPressed: _handleSendPressed,
      ),
    );
  }

  @override
  void dispose() {
    socket.close();
    super.dispose();
  }
}