import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:realtime_chat/src/models/message_response.dart';
import 'package:realtime_chat/src/services/auth_service.dart';
import 'package:realtime_chat/src/services/chat_service.dart';
import 'package:realtime_chat/src/services/socket_service.dart';
import 'package:realtime_chat/src/widgets/chat_message_widget.dart';

class ChatPage extends StatefulWidget {
  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
  final TextEditingController _textEditingController =
      new TextEditingController();

  ChatService chatService;
  SocketService socketService;
  AuthService authService;

  final FocusNode _focusNode = new FocusNode();

  List<ChatMessageWidget> _messages = [];

  bool _isTyping = false;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    this.chatService = Provider.of<ChatService>(context, listen: false);
    this.socketService = Provider.of<SocketService>(context, listen: false);
    this.authService = Provider.of<AuthService>(context, listen: false);

    this.socketService.socket.on('message-personal', _listenMessage);
    _loadHistory(this.chatService.userFor.uid);
  }

  void _loadHistory(String userID) async {
    List<Message> chat = await chatService.getChat(userID);
    final history = chat.map((m) => new ChatMessageWidget(
        text: m.message,
        uid: m.from,
        animationController: new AnimationController(
            vsync: this, duration: Duration(milliseconds: 0))
          ..forward()));

      setState(() {
        _messages.insertAll(0, history);
      });
  }

  void _listenMessage(dynamic data) {
    ChatMessageWidget message = ChatMessageWidget(
      text: data['message'],
      uid: data['from'],
      animationController: AnimationController(
          vsync: this, duration: Duration(milliseconds: 300)),
    );

    setState(() {
      _messages.insert(0, message);
    });

    message.animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final user = this.chatService.userFor;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Column(
          children: [
            CircleAvatar(
              child: Text(
                user.name.substring(0, 2),
                style: TextStyle(fontSize: 12),
              ),
              backgroundColor: Colors.amber,
              maxRadius: 14,
            ),
            SizedBox(
              height: 3,
            ),
            Text(
              user.name,
              style: TextStyle(color: Colors.black, fontSize: 12),
            )
          ],
        ),
      ),
      body: Container(
        child: Column(
          children: [
            Flexible(
              child: ListView.builder(
                itemCount: _messages.length,
                itemBuilder: (context, index) => _messages[index],
                physics: BouncingScrollPhysics(),
                reverse: true,
              ),
            ),
            Divider(
              height: 1,
            ),
            // TODO textfield

            Container(
              color: Colors.white,
              height: 50,
              child: _renderInputChat(),
            )
          ],
        ),
      ),
    );
  }

  Widget _renderInputChat() {
    return SafeArea(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Flexible(
              child: TextField(
                controller: _textEditingController,
                onSubmitted: _handleSubmit,
                onChanged: (value) {
                  setState(() {
                    if (value.trim().length > 0) {
                      _isTyping = true;
                    } else {
                      _isTyping = false;
                    }
                  });
                },
                decoration: InputDecoration(
                    hintText: "Enviar Mensaje",
                    focusedBorder: InputBorder.none),
                focusNode: _focusNode,
              ),
            ),
            Container(
              margin: EdgeInsets.symmetric(horizontal: 4),
              child: Platform.isIOS
                  ? CupertinoButton(
                      child: Text('Enviar'),
                      onPressed: () {},
                    )
                  : Container(
                      margin: EdgeInsets.symmetric(horizontal: 4),
                      child: IconTheme(
                        data: IconThemeData(color: Colors.amber),
                        child: IconButton(
                          highlightColor: Colors.transparent,
                          icon: Icon(
                            Icons.send,
                          ),
                          onPressed: _isTyping
                              ? () => _handleSubmit(_textEditingController.text)
                              : null,
                        ),
                      ),
                    ),
            )
          ],
        ),
      ),
    );
  }

  _handleSubmit(String value) {
    // print(value);
    if (value.length == 0) return;
    final newMessage = ChatMessageWidget(
      text: _textEditingController.text,
      uid: authService.user.uid,
      animationController: AnimationController(
          vsync: this, duration: Duration(milliseconds: 200)),
    );

    setState(() {
      _isTyping = false;
      _messages.insert(0, newMessage);
      newMessage.animationController.forward();
    });

    _textEditingController.clear();
    _focusNode.requestFocus();

    this.socketService.emit('message-personal', {
      'from': this.authService.user.uid,
      'to': this.chatService.userFor.uid,
      'message': value
    });
  }

  @override
  void dispose() {
    // TODO: socket on off
    // TODO: implement dispose

    for (ChatMessageWidget message in _messages) {
      message.animationController.dispose();
    }
    this.socketService.socket.off('message-personal');
    super.dispose();
  }
}
