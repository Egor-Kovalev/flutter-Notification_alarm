import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:core';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging();
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      new FlutterLocalNotificationsPlugin();
  String serverToken;
  String nickName;
  final TextEditingController _nicknameControl = new TextEditingController();
  final TextEditingController _titleControl = new TextEditingController();
  final TextEditingController _bodyControl = new TextEditingController();
  List<MemberItem> memberItems = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    var initializationSettingsAndroid =
        new AndroidInitializationSettings('@mipmap/ic_launcher');

    var initializationSettingsIOS = new IOSInitializationSettings(
        onDidReceiveLocalNotification: onDidRecieveLocalNotification);

    var initializationSettings = new InitializationSettings(
        android: initializationSettingsAndroid, iOS: initializationSettingsIOS);

    flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onSelectNotification: onSelectNotification);

    _firebaseMessaging.configure(
      onMessage: (Map<String, dynamic> message) async {
        print('on message ${message}');
        // initialise the plugin. app_icon needs to be a added as a drawable resource to the Android head project
        displayNotification(message);
        // _showItemDialog(message);
      },
      onResume: (Map<String, dynamic> message) async {
        print('on resume $message');
      },
      onLaunch: (Map<String, dynamic> message) async {
        print('on launch $message');
      },
    );
    _firebaseMessaging.requestNotificationPermissions(
        const IosNotificationSettings(sound: true, badge: true, alert: true));
    _firebaseMessaging.onIosSettingsRegistered
        .listen((IosNotificationSettings settings) {
      print("Settings registered: $settings");
    });
    _firebaseMessaging.getToken().then((String token) {
      serverToken = token;
      getNickname();
      getDocuments();
      print('size = ${memberItems.length}');
      assert(token != null);
      print("toke = $token");
    });
  }

  void sendAndRetrieveMessage(String title, String body) async {
    String token =
        'AAAAcFlkEe0:APA91bGhGnzjRFbESIOxhdh_dMWpPhHlSO9DfJNtaXz185eX8GgL07lKL5fWZLlAH1-KtZLVyRDv59vUkhob0leFj_YUr2003EOXuUQGCOUQgwAE4eJ1X9WGqg6YgO9hKIRqs1O7B0Gg';
    for (int i = 0; i < memberItems.length; i++) {
      if (!memberItems[i].select) continue;
      final response = http
          .post(
        'https://fcm.googleapis.com/fcm/send',
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'key=$token',
        },
        body: jsonEncode(
          <String, dynamic>{
            'notification': <String, dynamic>{'body': body, 'title': title},
            'priority': 'high',
            'data': <String, dynamic>{
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              'id': '1',
              'status': 'done'
            },
            'to': memberItems[i]
                .token //serverToken//'com.example.flutter_firebase_example'//,//await firebaseMessaging2.getToken(),
          },
        ),
      )
          .then((response) {
        print(
            'nickname = ${memberItems[i].nickname}, response = ${response.statusCode}');
      });
    }
  }

  Future displayNotification(Map<String, dynamic> message) async {
    var androidPlatformChannelSpecifics = new AndroidNotificationDetails(
        'channelid', 'flutterfcm', 'your channel description',
        importance: Importance.max, priority: Priority.high);
    var iOSPlatformChannelSpecifics = new IOSNotificationDetails();
    var platformChannelSpecifics = new NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      0,
      message['notification']['title'],
      message['notification']['body'],
      platformChannelSpecifics,
      payload: 'hello',
    );
  }

  Future onSelectNotification(String payload) async {
    if (payload != null) {
      debugPrint('notification payload: ' + payload);
    }
    await Fluttertoast.showToast(
        msg: "Notification Clicked",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIos: 1,
        backgroundColor: Colors.black54,
        textColor: Colors.white,
        fontSize: 16.0);
    /*Navigator.push(
      context,
      new MaterialPageRoute(builder: (context) => new SecondScreen(payload)),
    );*/
  }

  Future onDidRecieveLocalNotification(
      int id, String title, String body, String payload) async {
    // display a dialog with the notification details, tap ok to go to another page
    showDialog(
      context: context,
      builder: (BuildContext context) => new CupertinoAlertDialog(
        title: new Text(title),
        content: new Text(body),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: new Text('Ok'),
            onPressed: () async {
              Navigator.of(context, rootNavigator: true).pop();
              await Fluttertoast.showToast(
                  msg: "Notification Clicked",
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.BOTTOM,
                  timeInSecForIos: 1,
                  backgroundColor: Colors.black54,
                  textColor: Colors.white,
                  fontSize: 16.0);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Container(
          child: !isLoading
              ? Center(
                  child: CircularProgressIndicator(),
                )
              : ListView.builder(
                  padding: EdgeInsets.only(
                      left: 10.0, top: 10.0, right: 10.0, bottom: 0),
                  itemBuilder: (context, index) => buildItem(context, index),
                  itemCount: memberItems.length + 1,
                )),
    );
  }

//  final String serverToken = '<Test_Alarm>';
//  final FirebaseMessaging firebaseMessaging2 = FirebaseMessaging();

  Widget textEditBox(
      TextEditingController _control, String hint, IconData icon, bool type) {
    return TextField(
      style: TextStyle(
        fontSize: 15.0,
        color: Colors.black,
      ),
      decoration: InputDecoration(
        contentPadding: EdgeInsets.all(10.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5.0),
          borderSide: BorderSide(
            color: Colors.white,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: type ? Colors.white : Colors.black,
          ),
          borderRadius: BorderRadius.circular(5.0),
        ),
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 15.0,
          color: type ? Colors.white : Colors.grey,
        ),
        prefixIcon: Icon(
          icon,
          color: Colors.black,
        ),
      ),
      maxLines: 1,
      controller: _control,
    );
  }

  void setNickname() async {
    await Firestore.instance
        .collection('Tokens')
        .document(serverToken)
        .updateData({'token': serverToken, 'nickname': nickName});
  }

  Future<bool> getNickname() async {
    final QuerySnapshot result = await Firestore.instance
        .collection('Tokens')
        .where('token', isEqualTo: serverToken)
        .getDocuments();
    if (result.documents.length != 0) {
      nickName = result.documents[0]['nickname'];
      return true;
    }
    nickName = 'noname';
    await Firestore.instance
        .collection('Tokens')
        .document(serverToken)
        .setData({'token': serverToken, 'nickname': nickName});
    return false;
  }

  Future getDocuments() async {
    memberItems = [];
    isLoading = false;
    QuerySnapshot docs = await Firestore.instance
        .collection('Tokens')
        .getDocuments()
        .then((docs) {
      for (int i = 0; i < docs.documents.length; i++)
        if (serverToken != docs.documents[i].data['token'])
          memberItems.add(new MemberItem(docs.documents[i].data['token'],
              docs.documents[i].data['nickname']));
      setState(() {
        isLoading = true;
      });
      return null;
    });
  }

  Widget buildItem(BuildContext context, int index) {
    if (index == 0) return statusView();
    return Container(
      padding: EdgeInsets.only(top: 0),
      child: FlatButton(
        child: Text(memberItems[index - 1].nickname),
        onPressed: () => setState(() {
          memberItems[index - 1].select = !memberItems[index - 1].select;
        }),
        color: memberItems[index - 1].select ? Colors.blue : Colors.grey,
        padding: EdgeInsets.fromLTRB(10.0, 10.0, 25.0, 10.0),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      ),
    );
  }

  Widget statusView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        new Row(
          children: [
            Container(
              width: MediaQuery.of(context).size.width - 150,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.all(
                  Radius.circular(5.0),
                ),
              ),
              child: textEditBox(_nicknameControl, "change nickname",
                  Icons.perm_identity, true),
            ),
            SizedBox(width: 10),
            FlatButton.icon(
                onPressed: () {
                  if (_nicknameControl.text.isEmpty) return;
                  nickName = _nicknameControl.text;
                  setState(() {
                    setNickname();
                  });
                },
                icon: Icon(Icons.account_circle, size: 30, color: Colors.green),
                label: Text('Change'))
          ],
        ),
        SizedBox(height: 10),
        Text('nickname : $nickName',
            style: TextStyle(color: Colors.green, fontSize: 20)),
        SizedBox(height: 20),
        new Row(
          children: [
            Container(
              width: MediaQuery.of(context).size.width - 170,
              child: new Column(
                children: [
                  textEditBox(_titleControl, "title", Icons.title, false),
                  SizedBox(height: 10),
                  textEditBox(_bodyControl, "message", Icons.mail, false),
                ],
              ),
            ),
            SizedBox(width: 10),
            FlatButton.icon(
                onPressed: () {
                  if (_titleControl.text.isNotEmpty &&
                      _bodyControl.text.isNotEmpty) {
                    sendAndRetrieveMessage(
                        _titleControl.text, _bodyControl.text);
                  }
                },
                icon: Icon(Icons.chat, size: 60, color: Colors.green),
                label: Text('Send', style: TextStyle(fontSize: 15))),
          ],
        ),
        SizedBox(height: 20),
        FlatButton.icon(
            color: Colors.grey,
            onPressed: () {
              getDocuments();
            },
            icon: Icon(Icons.refresh, size: 40, color: Colors.blue),
            label: Text('MEMBERS',
                style: TextStyle(color: Colors.black, fontSize: 30)))
      ],
    );
  }
}

class MemberItem {
  String token;
  String nickname;
  bool select;
  MemberItem(String tk, String nn) {
    token = tk;
    nickname = nn;
    select = false;
  }
}
