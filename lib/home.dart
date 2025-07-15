import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late String clientID;
  late MqttServerClient client;
  final String topic = "haberlesme";
  List<ChatMessage> messages = [];
  final TextEditingController _messageController = TextEditingController();
  bool isConnected = false;
  final ImagePicker _picker = ImagePicker();
  bool _showEmojiPicker = false;
  
  // Popüler emojiler
  final List<String> _popularEmojis = [
    '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣', '😊', '😇',
    '🙂', '🙃', '😉', '😌', '😍', '🥰', '😘', '😗', '😙', '😚',
    '😋', '😛', '😝', '😜', '🤪', '🤨', '🧐', '🤓', '😎', '🥸',
    '🤩', '🥳', '😏', '😒', '😞', '😔', '😟', '😕', '🙁', '☹️',
    '😣', '😖', '😫', '😩', '🥺', '😢', '😭', '😤', '😠', '😡',
    '🤬', '🤯', '😳', '🥵', '🥶', '😱', '😨', '😰', '😥', '😓',
    '🤗', '🤔', '🤭', '🤫', '🤥', '😶', '😐', '😑', '😬', '🙄',
    '😯', '😦', '😧', '😮', '😲', '🥱', '😴', '🤤', '😪', '😵',
    '🤐', '🥴', '🤢', '🤮', '🤧', '😷', '🤒', '🤕', '🤑', '🤠',
    '👍', '👎', '👌', '🤌', '🤏', '✌️', '🤞', '🤟', '🤘', '🤙',
    '💪', '🦾', '🦿', '🦵', '🦶', '👂', '🦻', '👃', '🧠', '🫀',
    '🫁', '🦷', '🦴', '👀', '👁️', '👅', '👄', '💋', '🩸', '💯',
    '💢', '💥', '💫', '💦', '💨', '🕳️', '💣', '💬', '👁️‍🗨️', '🗨️',
    '🗯️', '💭', '💤', '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤',
    '🤍', '🤎', '💔', '❣️', '💕', '💞', '💓', '💗', '💖', '💘',
    '💝', '💟', '☮️', '✝️', '☪️', '🕉️', '☸️', '✡️', '🔯', '🕎',
    '☯️', '☦️', '🛐', '⛎', '♈', '♉', '♊', '♋', '♌', '♍',
    '♎', '♏', '♐', '♑', '♒', '♓', '🆔', '⚛️', '🉑', '☢️',
    '☣️', '📴', '📳', '🈶', '🈚', '🈸', '🈺', '🈷️', '✴️', '🆚',
    '💮', '🉐', '㊙️', '㊗️', '🈴', '🈵', '🈹', '🈲', '🅰️', '🅱️',
  ];
  
  @override
  void initState() {
    super.initState();
    clientID = DateTime.now().millisecondsSinceEpoch.toString();
  }

  @override
  void dispose() {
    _messageController.dispose();
    if (isConnected) {
      disConnectMqtt();
    }
    super.dispose();
  }

//#region MQTT

  void connectMqtt() {
    client = MqttServerClient.withPort("broker.hivemq.com", clientID, 1883);
    client.logging(on: true);
    client.keepAlivePeriod = 60;
    client.onDisconnected = onDisconnected;
    client.onConnected = onConnected;
    client.onSubscribed = onSubscribed;
    client.connect();
    client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
      final String pt = MqttPublishPayload.bytesToStringAsString(
        recMess.payload.message,
      );
      print("Received message: $pt from topic: ${c[0].topic}");
      
      // Mesajı parse et
      final parts = pt.split('|');
      if (parts.length >= 4) {
        final senderID = parts[0];
        final messageType = parts[1];
        final content = parts[2];
        final timestamp = parts[3];
        final messageId = parts.length > 4 ? parts[4] : DateTime.now().millisecondsSinceEpoch.toString();
        
        // Mesaj silme komutu
        if (messageType == 'DELETE') {
          setState(() {
            messages.removeWhere((msg) => msg.id == content);
          });
          return;
        }
        
        // Kendi mesajımız değilse ekle
        if (senderID != clientID) {
          setState(() {
            messages.add(ChatMessage(
              id: messageId,
              message: content,
              timestamp: timestamp,
              isMe: false,
              senderID: senderID,
              type: MessageType.values.firstWhere(
                (e) => e.toString().split('.').last == messageType,
                orElse: () => MessageType.text,
              ),
            ));
          });
        }
      }
    });
  }

  void onDisconnected() {
    print("Disconnected from MQTT broker");
    setState(() {
      isConnected = false;
    });
  }

  void onConnected() {
    print("Connected to MQTT broker");
    if (client.connectionStatus!.state != MqttConnectionState.connected) {
      print("Connection failed: ${client.connectionStatus!.returnCode}");
      return;
    }
    setState(() {
      isConnected = true;
    });
    client.subscribe(topic, MqttQos.atMostOnce);
  }

  void onSubscribed(String topic) {
    print("Subscribed to topic: $topic");
  }

  void disConnectMqtt() {
    client.disconnect();
  }

  void sendMessage(String message, {MessageType type = MessageType.text}) {
    if (client.connectionStatus!.state != MqttConnectionState.connected) {
      print("Not connected to MQTT broker");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('MQTT bağlantısı yok!')),
      );
      return;
    }
    
    if (message.trim().isEmpty) {
      return;
    }
    
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final fullMessage = "$clientID|${type.toString().split('.').last}|$message|$timestamp|$messageId";
    
    final MqttClientPayloadBuilder builder = MqttClientPayloadBuilder();
    builder.addString(fullMessage);
    client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
    
    // Kendi mesajımızı yerel olarak ekle
    setState(() {
      messages.add(ChatMessage(
        id: messageId,
        message: message,
        timestamp: timestamp,
        isMe: true,
        senderID: clientID,
        type: type,
      ));
    });
    
    print("Sent message: $message to topic: $topic");
    _messageController.clear();
  }

  void deleteMessage(String messageId) {
    if (client.connectionStatus!.state != MqttConnectionState.connected) {
      return;
    }
    
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final fullMessage = "$clientID|DELETE|$messageId|$timestamp";
    
    final MqttClientPayloadBuilder builder = MqttClientPayloadBuilder();
    builder.addString(fullMessage);
    client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
    
    // Yerel olarak sil
    setState(() {
      messages.removeWhere((msg) => msg.id == messageId);
    });
  }

//#endregion
  
  void _sendCurrentMessage() {
    sendMessage(_messageController.text);
  }

  void _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 600,
      imageQuality: 85,
    );
    
    if (image != null) {
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
      sendMessage(base64Image, type: MessageType.image);
    }
  }

  void _takePhoto() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800,
      maxHeight: 600,
      imageQuality: 85,
    );
    
    if (image != null) {
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
      sendMessage(base64Image, type: MessageType.image);
    }
  }

  void _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', 'ppt', 'pptx'],
    );

    if (result != null) {
      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();
      final base64File = base64Encode(bytes);
      final fileName = result.files.single.name;
      sendMessage('$fileName|$base64File', type: MessageType.file);
    }
  }

  void _showMediaPicker() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo, color: Colors.blue),
                title: const Text('Galeriden Fotoğraf'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.green),
                title: const Text('Kamera'),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_file, color: Colors.orange),
                title: const Text('Dosya'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFile();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _insertEmoji(String emoji) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    final newText = text.replaceRange(selection.start, selection.end, emoji);
    _messageController.text = newText;
    _messageController.selection = TextSelection.collapsed(
      offset: selection.start + emoji.length,
    );
  }

  String _formatTimestamp(String timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp));
    return "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
  }

  Widget _buildMessageContent(ChatMessage message) {
    switch (message.type) {
      case MessageType.text:
        return Text(
          message.message,
          style: TextStyle(
            color: message.isMe ? Colors.white : Colors.black,
            fontSize: 16,
          ),
        );
      case MessageType.image:
        try {
          final bytes = base64Decode(message.message);
          return Container(
            constraints: const BoxConstraints(maxWidth: 250, maxHeight: 300),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                bytes,
                fit: BoxFit.cover,
              ),
            ),
          );
        } catch (e) {
          return const Text('Fotoğraf yüklenemedi');
        }
      case MessageType.file:
        final parts = message.message.split('|');
        final fileName = parts.isNotEmpty ? parts[0] : 'Dosya';
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: message.isMe ? Colors.white.withOpacity(0.2) : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.attach_file, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  fileName,
                  style: TextStyle(
                    color: message.isMe ? Colors.white : Colors.black,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(
              isConnected ? Icons.wifi : Icons.wifi_off,
              color: isConnected ? Colors.green : Colors.red,
            ),
            onPressed: isConnected ? disConnectMqtt : connectMqtt,
          ),
        ],
      ),
      body: Column(
        children: [
          // Bağlantı durumu
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8.0),
            color: isConnected ? Colors.green.shade100 : Colors.red.shade100,
            child: Text(
              isConnected ? 'Bağlı' : 'Bağlantı Yok',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isConnected ? Colors.green.shade800 : Colors.red.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Mesaj listesi
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[messages.length - 1 - index];
                return GestureDetector(
                  onLongPress: () {
                    if (message.isMe) {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Mesaj Seçenekleri'),
                            content: const Text('Bu mesajı silmek istiyor musunuz?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('İptal'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  deleteMessage(message.id);
                                },
                                child: const Text('Sil', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          );
                        },
                      );
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Row(
                      mainAxisAlignment: message.isMe 
                          ? MainAxisAlignment.end 
                          : MainAxisAlignment.start,
                      children: [
                        Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: message.isMe 
                                ? Colors.blue.shade500 
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!message.isMe)
                                Text(
                                  message.senderID.substring(0, 8),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              _buildMessageContent(message),
                              const SizedBox(height: 4),
                              Text(
                                _formatTimestamp(message.timestamp),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: message.isMe 
                                      ? Colors.white70 
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Emoji seçici
          if (_showEmojiPicker)
            Container(
              height: 200,
              color: Colors.grey.shade100,
              child: GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  childAspectRatio: 1,
                ),
                itemCount: _popularEmojis.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () => _insertEmoji(_popularEmojis[index]),
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          _popularEmojis[index],
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          
          // Mesaj yazma alanı
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(
                top: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: isConnected ? _showMediaPicker : null,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Mesajınızı yazın...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (value) => _sendCurrentMessage(),
                    enabled: isConnected,
                    maxLines: null,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions,
                  ),
                  onPressed: () {
                    setState(() {
                      _showEmojiPicker = !_showEmojiPicker;
                    });
                  },
                ),
                const SizedBox(width: 4),
                FloatingActionButton(
                  onPressed: isConnected ? _sendCurrentMessage : null,
                  mini: true,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Mesaj türleri
enum MessageType {
  text,
  image,
  file,
}

// Mesaj sınıfı
class ChatMessage {
  final String id;
  final String message;
  final String timestamp;
  final bool isMe;
  final String senderID;
  final MessageType type;

  ChatMessage({
    required this.id,
    required this.message,
    required this.timestamp,
    required this.isMe,
    required this.senderID,
    required this.type,
  });
}