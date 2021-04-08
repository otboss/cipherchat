import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:share/share.dart';
import '../main.dart';
import 'dart:convert';

class Chat extends StatefulWidget {
  ChatState createState() => ChatState();
}

class ChatState extends State<Chat> {
  TextEditingController messageTextController = TextEditingController();
  TextEditingController groupChatTextController = TextEditingController();
  Map participants = {}; 
  Map messages = {};
  List<Widget> messagesContainer = [];
  String passphrase = "";
  TextEditingController passphraseFieldController = TextEditingController();
  TextEditingController groupNameFieldController = TextEditingController();
  int offsetForMessages = -1;
  String currentServerUrl = "https://" + currentServer + ":" + currentPort.toString() + "/";
  bool connected = false;
  bool isGroupChat = false;


  

  Future<bool> updateProfilePic(int participantId) async {
    try {
      File image = await FilePicker.getFile(type: FileType.IMAGE);
      String base64ProfilePic = base64.encode(await image.readAsBytes());
      await databaseManager.updateProfilePicture(base64ProfilePic, false,
          gid: currentGroupId, pid: participantId);
      Navigator.pop(context);
      setState(() {});
      toastMessageBottomShort("Profile Updated", context);
    } catch (err) {
      return false;
    }
    return true;
  }


  Future<bool> joinGroup(String ip, int port, Map signature, String encryptedMessage, String joinKey, String publicKey, String publicKey2, String username) async{
    try{
      print("THE JOIN KEY WHILE CONNECTING TO SERVER IS: ");
      print(joinKey);
      if(await databaseManager.isGroupSaved(joinKey) > -1)
        return true;
      String currentServerUrl = "https://" + ip + ":" + port.toString() + "/";
      Response response = await dio.post(currentServerUrl+"joingroup", data: {
        "encryptedMessage": encryptedMessage,
        "signature": json.encode(signature),
        "username": username,
        "publicKey": publicKey,
        "publicKey2": publicKey2,
        "joinKey": joinKey,
      });
      if(response.data == "1" || response.data == "-3")
        return true;
    }
    catch(err){
      return false;
    }
    return false;
  }  



  ///Parses a join key received from another peer (join keys are base64 encoded)
  Map parseJoinKey(String joinKey) {
    try {
      return json.decode(
          utf8.decode(json.decode(utf8.decode(base64.decode(joinKey)))));
    } catch (err) {
      return null;
    }
  }

  Future<Map> getPrivateKey() async {
    Map groupInfo = await databaseManager.getGroupInfo(currentGroupId);
    return groupInfo["privateKey"];
  }

  ///Retrieves the Admob ID from the server. Also tests for connection to the server
  Future<String> getAdmodId() async {
    while (true) {
      try {
        Response response = await dio.get(currentServerUrl + "/ads");
        return response.data;
      } catch (err) {}
      await Future.delayed(Duration(seconds: 4));
    }
  }

  Future<Map> getParticipants() async {
    try {
      String message = secp256k1EllipticCurve.generateRandomString(100);
      String messageHash = sha256.convert(utf8.encode(message)).toString();
      Map signature = await secp256k1EllipticCurve.signMessage(messageHash, currentPrivateKey);
      String joinKey = await databaseManager.getGroupJoinKey(currentGroupId);
      String username = await databaseManager.getUsername();
      Response response = await dio.get(currentServerUrl + "participants", data: {
        "encryptedMessage": message,
        "signature": json.encode(signature),
        "joinKey": joinKey,
        "username": username
      });
      return json.decode(json.encode(response.data));
    } catch (err) {
      print(err);
    }
    return null;
  }

  Future<bool> muteChat() async {

  }


  Future<bool> updateParticipants() async {
    try{
      Map participants = await getParticipants();
      List usernames = participants.keys.toList();
      for (var x = 0; x < usernames.length; x++) {
        try {
          await databaseManager.saveParticipant(currentGroupId, usernames[x], databaseManager.defaultProfilePicBase64, BigInt.parse(participants[usernames[x]]["publicKey"]), BigInt.parse(participants[usernames[x]]["publicKey2"]), int.parse(participants[usernames[x]]["joined"].toString()));
        } catch (err) {
          print(err);
        }
      }
    }
    catch(err){
      print("ERROR HERE!!!");
      print(err);
    }
    return true;
  }


  Future<int> sendMessage(String message) async {
    try {
      Map compositeKeys = await databaseManager.generateCompositeKeysForRecipients(currentGroupId);
      print("THE MESSAGE FOR SENDING IS: ");
      print(message); 
      print("THE COMPOSITE KEYS ARE: ");
      print(compositeKeys);
      if(compositeKeys.keys.length == 0)
        return 0;      
      if(message.length == 0)
        return -2;
      BigInt symmetricKey = await databaseManager.getSymmetricKey(currentGroupId);
      String username = await databaseManager.getUsername();
      String encryptedMessage = await secp256k1EllipticCurve.encryptMessage(databaseManager.addslashes2(message), symmetricKey);
      String encryptedMessageHash = sha256.convert(utf8.encode(encryptedMessage)).toString();
      Map signature = await secp256k1EllipticCurve.signMessage(encryptedMessageHash, currentPrivateKey);
      String joinKey = await databaseManager.getGroupJoinKey(currentGroupId);
      Response response = await dio.post(currentServerUrl + "message", data: {
        "encryptedMessage": encryptedMessage, 
        "signature": json.encode(signature),
        "joinKey": joinKey,
        "username": username,
        "compositeKeys": json.encode(compositeKeys)
      });
      if (response.data == "-1") 
        return -1;
      else{
        Map responseData = json.decode(json.encode(response.data));
        print("THE MESSAGE RESPONSE IS: ");
        print(response.data["mid"]);
        String currentUsername = await databaseManager.getUsername();
        SentMessageResponse result = SentMessageResponse(int.parse(responseData["mid"].toString()), int.parse(responseData["timestamp"].toString()));
        await databaseManager.saveMessage(currentGroupId, result.messageId, message, currentUsername, result.timestamp, 1);
        return 1;
      }     
    } catch (err) {
      print(err);
      return -2;
    }
  }

  Future<List> getNewMessages() async {
    String message = secp256k1EllipticCurve.generateRandomString(100);
    String messageHash = sha256.convert(utf8.encode(message)).toString();
    Map signature = await secp256k1EllipticCurve.signMessage(messageHash, currentPrivateKey);
    String joinKey = await databaseManager.getGroupJoinKey(currentGroupId);
    String username = await databaseManager.getUsername();
    int offset = await databaseManager.getLastMessageId(currentGroupId);
    Response response;
    try {
      response = await dio.get(currentServerUrl + "messages", data: {
        "encryptedMessage": message,
        "signature": json.encode(signature),
        "joinKey": joinKey,
        "username": username,
        "offset": offset
      });
    } catch (err) {
      return null;
    }
    List result = [];
    print(response.data);
    Map data = json.decode(json.encode(response.data));
    print("THE RESPONSE FROM THE SERVER IS: ");
    print(data);
    List messageIds = data.keys.toList();
    for(var x = 0; x < messageIds.length; x++){
      result.add(NewMessagesResponse(int.parse(messageIds[x].toString()), data[messageIds[x]]["sender"], data[messageIds[x]]["encryptedMessage"], BigInt.parse(data[messageIds[x]]["compositeKey"]), int.parse(data[messageIds[x]]["ts"].toString())));
    } 
    result.sort((a, b) => a.messageId.compareTo(b.messageId)); 
    return result;
  } 

  Future<Map> getOlderMessages() async {
    Map oldMessages = {};
    try{
      oldMessages = await databaseManager.getMessages(currentGroupId, offset: offsetForMessages);
      print("THE MESSAGES OFFSET IS: ");
      print(offsetForMessages);
      print("THE OLD MESSAGES ARE: ");
      print(oldMessages);
      List messageIds = oldMessages.keys.toList();
      messageIds.sort();
      offsetForMessages = int.parse(messageIds[messageIds.length - 1]);
    }
    catch(err){

    }
    return oldMessages;
  }

  Future<Map> getMessagesForInitialDisplaying() async {
    int lastMessageId = await databaseManager.getLastMessageId(currentGroupId);
    Map oldMessages = await databaseManager.getMessages(currentGroupId,
        offset: lastMessageId);
    return oldMessages;
  }

  Map<String, bool> participantCheckboxIndicators = {};

  bool passphrasePromptOpen = false;

  Map currentServerInfo = {};


  Future<bool> fetchAndSaveNewMessages() async{
    try{ 
      print("FETCHING MESSAGES FROM SERVER");
      List newMessages = await getNewMessages(); 
      print("THE NEW MESSAGES RESPONSE IS: ");
      print(newMessages);
      for(var x = 0; x < newMessages.length; x++){
        try{
          NewMessagesResponse currentMessage = newMessages[x];
          BigInt compositeKey = currentMessage.compositeKey;
          BigInt symmetricKey = await secp256k1EllipticCurve.generateSymmetricKey(currentPrivateKey, [compositeKey]);
          String decryptedMessage = await secp256k1EllipticCurve.decryptMessage(currentMessage.encryptedMessage, symmetricKey);
          print("THE DECRYPTED MESSAGE IS: ");
          print(decryptedMessage);
          if(decryptedMessage != "")
            await databaseManager.saveMessage(currentGroupId, currentMessage.messageId, decryptedMessage, currentMessage.sender, currentMessage.timestamp, 0);
        }
        catch(err){
          print(err);
          continue;
        }
      }
    }
    catch(err){
      print(err);
      return false;
    }    
    return true;
  }

  Future newMessageListener() async{
    print("Message listener started..");
    while(context.toString().split("(")[0] == "Chat"){
      try{
        print("Getting new messages"); 
        fetchAndSaveNewMessages().then((val){
          updateParticipants();
        });
      } 
      catch(err){
        
      }
      await Future.delayed(Duration(seconds: 5));
    }
  }

  Future<bool> newGroupConnector(BuildContext conext) async {
    String username = await databaseManager.getUsername();
    if(connected == false){
      while (context.toString().split("(")[0] == "Chat") {
        try {
          Response response = await dio.post(currentServerUrl + "newgroup", data: {
            "username": username,
            "publicKey": currentPublicKey["x2"],
            "publicKey2": currentPublicKey["x"],
            "passphrase": passphrase
          });
          if (response.data == "0") { 
            if (passphrasePromptOpen == false)
              showPrompt("Passphrase Required", context, passphraseFieldController, () {
                passphrasePromptOpen = false;
                setState(() {
                  passphrase = passphraseFieldController.text;
                });
                passphrase = passphraseFieldController.text;
              });
            passphrasePromptOpen = true;
          } 
          else {
            if (response.data != "-1") {
              //Connection Successful, New group created
              String joinKey = response.data;
              await databaseManager.saveGroup(currentServer, currentPort, currentServer, currentPrivateKey.toString(), joinKey, username);
              currentGroupId = await databaseManager.getLastGroupId();
              connected = true;
              //newMessageListener();
              return true;
            }
          }
        } catch (err) {
          print(err);
        }
        await Future.delayed(Duration(seconds: 4));
      }
    }
    else{
      try{
        return await checkServerRoutes(currentServer, currentPort);
      }
      catch(err){
        return false;
      }
    }
  }

  Future<bool> oldGroupConnector(BuildContext conext) async {
    if(connected == false){
      while (context.toString().split("(")[0] == "Chat") {
        try {
          assert(await joinGroup(currentServer, currentPort, globalGroupJoinKey.signature, globalGroupJoinKey.encryptedMessage, globalGroupJoinKey.joinKey, globalGroupJoinKey.publicKey.toString(), globalGroupJoinKey.publicKey2.toString(), globalGroupJoinKey.username), "Error while joining group");
          currentGroupId = await databaseManager.saveGroup(globalGroupJoinKey.ip, globalGroupJoinKey.port, globalGroupJoinKey.ip, currentPrivateKey.toString(), globalGroupJoinKey.joinKey, globalGroupJoinKey.username);
          connected = true;
          //newMessageListener();          
          return true;
        } catch (err) { 
          print(err);
        }
        await Future.delayed(Duration(seconds: 4));
      }
    }
    else{
      try{
        return await checkServerRoutes(currentServer, currentPort);
      }
      catch(err){
        return false;
      }
    }
  }


  Widget generateRecipientRow(String username, bool isRecipient) {
    if (participantCheckboxIndicators[username] == null)
      participantCheckboxIndicators[username] = false;
    if (isRecipient)
      participantCheckboxIndicators[username] = true;
    else
      participantCheckboxIndicators[username] = false;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(username),
        Checkbox(
          value: participantCheckboxIndicators[username],
          activeColor: materialGreen,
          onChanged: (val) async {
            await databaseManager.updateChatRecipient(currentGroupId, username, val);
            setState(() {
              participantCheckboxIndicators[username] = val;
            });
          },
        )
      ],
    );
  }


  Widget generateSentMessageWidget(String username, String message, int timestamp, String profilePic) {
    return Container(
      margin: EdgeInsets.fromLTRB(0, 5, 0, 5),
      child: Stack(
        overflow: Overflow.visible,
        children: <Widget>[
          GestureDetector(
            child: Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: sentMessageWidgetColor)
              ),
              margin: EdgeInsets.fromLTRB(0, 0, 5, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: base64ToImageConverter(profilePic),
              ),
            ),
            onTap: () async{
              File image = await FilePicker.getFile(type: FileType.ANY);
              String base64profilePic = base64.encode(image.readAsBytesSync()).toString();
              await databaseManager.updateProfilePicture(base64profilePic, true);
              setState(() {});
            },
          ),
          Container(
            margin: EdgeInsets.fromLTRB(50, 20, 0, 0),
            width: 7,
            height: 10,
            color: sentMessageWidgetColor,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: 150,
                ),
                child: Container(
                  margin: EdgeInsets.fromLTRB(50, 2, 0, 2),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    username,
                    style: TextStyle(
                      color: sentMessageWidgetColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Container(
                  padding: EdgeInsets.fromLTRB(10, 10, 10, 8),
                  margin: EdgeInsets.fromLTRB(56, 0, 0, 0),
                  decoration: BoxDecoration(
                      color: sentMessageWidgetColor,
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(5),
                        bottomRight: Radius.circular(5),
                        bottomLeft: Radius.circular(5),
                      ),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          message,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                          ),
                        ),
                        Container(
                          width: 95,
                          padding: EdgeInsets.fromLTRB(0, 5, 0, 0),
                          alignment: Alignment.centerRight,
                          child: Text(
                            DateTime.fromMillisecondsSinceEpoch(timestamp).toUtc().toString().split(":")[0]+":"+DateTime.fromMillisecondsSinceEpoch(timestamp).toUtc().toString().split(":")[1],
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        )
                      ],
                    ),
                  )),
            ],
          )
        ],
      ),
    );
  }

  Widget generateReceivedMessageWidget(String username, String message, int timestamp, String profilePic, int userJoinNumber) {
    return Container(
      margin: EdgeInsets.fromLTRB(0, 5, 0, 5),
      child: Stack(
        alignment: Alignment.topRight,
        overflow: Overflow.visible,
        children: <Widget>[
          GestureDetector(
            child: Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: receivedMessageUserIndicatorColor[userJoinNumber%receivedMessageUserIndicatorColor.length])
              ),                                  
              margin: EdgeInsets.fromLTRB(0, 0, 0, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: base64ToImageConverter(profilePic),
              ),
            ),
            onTap: () async{
              File image = await FilePicker.getFile(type: FileType.ANY);
              String base64profilePic = base64.encode(image.readAsBytesSync()).toString();
              Map userInfo = await databaseManager.getParticipants(currentGroupId);
              await databaseManager.updateProfilePicture(base64profilePic, false, pid: userInfo[username]["pid"], gid: currentGroupId);
              setState(() {});
            },
          ),
          Container(
            margin: EdgeInsets.fromLTRB(0, 20, 49, 0),
            width: 7,
            height: 10,
            color: receivedMessageWidgetColor
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: 150,
                ),
                child: Container(
                  margin: EdgeInsets.fromLTRB(0, 2, 49, 2),
                  alignment: Alignment.centerRight,
                  child: Text(
                    username,
                    style: TextStyle(
                      color: receivedMessageUserIndicatorColor[userJoinNumber%receivedMessageUserIndicatorColor.length],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Container(
                  padding: EdgeInsets.fromLTRB(10, 10, 10, 8),
                  margin: EdgeInsets.fromLTRB(0, 0, 55, 0),
                  decoration: BoxDecoration(
                      color: receivedMessageWidgetColor,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(5),
                        bottomRight: Radius.circular(5),
                        bottomLeft: Radius.circular(5),
                      ),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.55),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          message,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 17,
                          ),
                        ),
                        Container(
                          width: 95,
                          padding: EdgeInsets.fromLTRB(0, 5, 0, 0),
                          alignment: Alignment.centerRight,
                          child: Text(
                            DateTime.fromMillisecondsSinceEpoch(timestamp).toUtc().toString().split(":")[0]+":"+DateTime.fromMillisecondsSinceEpoch(timestamp).toUtc().toString().split(":")[1],
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
            ],
          )
        ],
      ),
    );
  }


  Widget serverInfoTable(String publicIp, String port, String latitude, String longitude, String country, String city, String region, String isp){
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(30, 10, 30, 40),                    
      children: <Widget>[
        Container(
          padding: EdgeInsets.fromLTRB(0, 0, 0, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                "IP",
                style: TextStyle(
                  color: sentMessageWidgetColor,
                  fontSize: 20, 
                ),
              ),
              ConstrainedBox( 
                constraints: BoxConstraints( 
                  maxWidth: MediaQuery.of(context).size.width * 0.57,
                ),
                child: Text(
                  publicIp,
                  style: TextStyle(
                    color: sentMessageWidgetColor,
                    fontSize: 20, 
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,                                
                ),
              ),
            ],
          ),
        ),   
        Container(
          padding: EdgeInsets.fromLTRB(0, 0, 0, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                "Port",
                style: TextStyle(
                  color: sentMessageWidgetColor,
                  fontSize: 20, 
                ),
              ),
              ConstrainedBox( 
                constraints: BoxConstraints( 
                  maxWidth: MediaQuery.of(context).size.width * 0.57,
                ),
                child: Text(
                  port,
                  style: TextStyle(
                    color: sentMessageWidgetColor,
                    fontSize: 20, 
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,                                
                ),
              ),
            ],
          ),
        ),             
        Container(
          padding: EdgeInsets.fromLTRB(0, 0, 0, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                "LAT",
                style: TextStyle(
                  color: sentMessageWidgetColor,
                  fontSize: 20, 
                ),
              ),
              ConstrainedBox( 
                constraints: BoxConstraints( 
                  maxWidth: MediaQuery.of(context).size.width * 0.57,
                ),
                child: Text(
                  latitude,
                  style: TextStyle(
                    color: sentMessageWidgetColor,
                    fontSize: 20, 
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,                                
                ),
              ),
            ],
          ),
        ), 
        Container(
          padding: EdgeInsets.fromLTRB(0, 0, 0, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                "LON",
                style: TextStyle(
                  color: sentMessageWidgetColor,
                  fontSize: 20, 
                ),
              ),
              ConstrainedBox( 
                constraints: BoxConstraints( 
                  maxWidth: MediaQuery.of(context).size.width * 0.57,
                ),
                child: Text(
                  longitude,
                  style: TextStyle(
                    color: sentMessageWidgetColor,
                    fontSize: 20, 
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,                                
                ),
              ), 
            ],
          ),
        ),                                                
        Container(
          padding: EdgeInsets.fromLTRB(0, 0, 0, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                "Country",
                style: TextStyle(
                  color: sentMessageWidgetColor,
                  fontSize: 20, 
                ),
              ),
              ConstrainedBox( 
                constraints: BoxConstraints( 
                  maxWidth: MediaQuery.of(context).size.width * 0.57,
                ),
                child: Text(
                  country,
                  style: TextStyle(
                    color: sentMessageWidgetColor,
                    fontSize: 20, 
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,                                
                ),
              ),
            ],
          ),
        ),  
        Container(
          padding: EdgeInsets.fromLTRB(0, 0, 0, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                "City",
                style: TextStyle(
                  color: sentMessageWidgetColor,
                  fontSize: 20, 
                ),
              ),
              ConstrainedBox( 
                constraints: BoxConstraints( 
                  maxWidth: MediaQuery.of(context).size.width * 0.57,
                ),
                child: Text(
                  city,
                  style: TextStyle(
                    color: sentMessageWidgetColor,
                    fontSize: 20, 
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,                                
                ),
              ),
            ],
          ),
        ),    
        Container(
          padding: EdgeInsets.fromLTRB(0, 0, 0, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                "Region",
                style: TextStyle(
                  color: sentMessageWidgetColor,
                  fontSize: 20, 
                ),
              ),
              ConstrainedBox( 
                constraints: BoxConstraints( 
                  maxWidth: MediaQuery.of(context).size.width * 0.57,
                ),
                child: Text(
                  region,
                  style: TextStyle(
                    color: sentMessageWidgetColor,
                    fontSize: 20, 
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,                                
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(0, 0, 0, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                "ISP",
                style: TextStyle(
                  color: sentMessageWidgetColor,
                  fontSize: 20, 
                ),
              ),
              ConstrainedBox( 
                constraints: BoxConstraints( 
                  maxWidth: MediaQuery.of(context).size.width * 0.57,
                ),
                child: Text(
                  isp,
                  style: TextStyle(
                    color: sentMessageWidgetColor,
                    fontSize: 20, 
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),                                                                     
      ],
    );
  }

  String chatLabel = "";

  @override
  void initState() {
    offsetForMessages = -1;
    chatLabel = currentServer;
    newMessageListener();
    super.initState();
  }


  @override
  Widget build(BuildContext context) {
    dio.onHttpClientCreate = (HttpClient client) {
      client.badCertificateCallback = (X509Certificate cert, String host, int port) {
        return true;
      };
    };
  
    var loadConnectionStatus;
    if(newGroupConnection){
      loadConnectionStatus = FutureBuilder<bool>(
        future: newGroupConnector(context),
        builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
          Widget connectingIndicator = Text(
            "Connecting..",
            style: TextStyle(
              fontSize: 12,
            ),
          );
          switch (snapshot.connectionState) {
            case ConnectionState.none:
              return connectingIndicator;
            case ConnectionState.active:
              return connectingIndicator;
            case ConnectionState.waiting:
              return connectingIndicator;
            case ConnectionState.done:
              if (snapshot.hasError) return Text('Error: ${snapshot.error}');
              return Text(
                "Connected",
                style: TextStyle(
                  fontSize: 12,
                ),
              );
          }
        },
      );
    }
    else{
      loadConnectionStatus = FutureBuilder<bool>(
        future: oldGroupConnector(context),
        builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
          Widget connectingIndicator = Text(
            "Connecting..",
            style: TextStyle(
              fontSize: 12,
            ),
          );
          switch (snapshot.connectionState) {
            case ConnectionState.none:
              return connectingIndicator;
            case ConnectionState.active:
              return connectingIndicator;
            case ConnectionState.waiting:
              return connectingIndicator;
            case ConnectionState.done:
              if (snapshot.hasError) return Text('Error: ${snapshot.error}');
              return Text(
                "Connected",
                style: TextStyle(
                  fontSize: 12,
                ),
              );
          }
        },
      );
    }

    
    FutureBuilder loadChatLabel = FutureBuilder<String>(
      future: databaseManager.getGroupName(currentGroupId), // a previously-obtained Future<String> or null
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.none:
            return Text(chatLabel);
          case ConnectionState.active:
            return Text(chatLabel);
          case ConnectionState.waiting:
            return Text(chatLabel);
          case ConnectionState.done:
            if (snapshot.hasError)
              return Text('Error: ${snapshot.error}');
            chatLabel = snapshot.data;
            return Text(chatLabel);
        }
      },
    );

    FutureBuilder loadParticipants = FutureBuilder<Map>(
      future: databaseManager.getParticipants(currentGroupId),
      builder: (BuildContext context, AsyncSnapshot<Map> snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.none:
            return loadingIndicator(color: Colors.blue);
          case ConnectionState.active:
            return loadingIndicator(color: Colors.blue);
          case ConnectionState.waiting:
            return loadingIndicator(color: Colors.blue);
          case ConnectionState.done:
            if (snapshot.hasError) return Text('Error: ${snapshot.error}');
            Map result = snapshot.data;
            List<Widget> users = [];
            try{
              List usernames = result.keys.toList();
              if(usernames.length > 2)
                isGroupChat = true;
              for (var x = 0; x < usernames.length; x++) {        
                if (result[usernames[x]]["currentUser"] == true) {
                  users.insert(0, Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        usernames[x],
                        style: TextStyle(
                          color: sentMessageWidgetColor,
                        ),
                      ),
                      Checkbox(
                        value: true,
                        activeColor: Colors.grey[400],
                        onChanged: (val) {},
                      )
                    ],
                  ));
                } else
                  users.add(generateRecipientRow(usernames[x], result[usernames[x]]["isRecipient"]));
              }
            }
            catch(err){
              print("AN ERROR OCCURRED");
              print(err);
              return loadingIndicator(color: Colors.blue);
            }
            return RefreshIndicator(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(30, 20, 23, 40),
                children: [
                  Column(
                    children: users,
                  ),
                ],
              ),
              onRefresh: () async{
                await updateParticipants();
              },
            );
        }
      },
    );

    var loadInitialMessages;
    if(messagesContainer.length == 0){

    }
    else{
      loadInitialMessages = GestureDetector(
        child: Container(
          child: ListView(
              reverse: true,
              padding: EdgeInsets.fromLTRB(10, 10, 10, 70),
              children: messagesContainer.reversed.toList(),
            ),
        ),
        onTap: (){
          fetchAndSaveNewMessages();
        },        
      );
    }

    loadInitialMessages = FutureBuilder<Map>(
      future: databaseManager.getMessages(currentGroupId, offset: offsetForMessages),
      builder: (BuildContext context, AsyncSnapshot<Map> snapshot) {
        Widget finalResult = Container(
          child: ListView(
            reverse: true,
            padding: EdgeInsets.fromLTRB(10, 10, 10, 70),
            children: messagesContainer.reversed.toList(),
          ),
        );
        switch (snapshot.connectionState) {
          case ConnectionState.none:
            if(messagesContainer.length > 0)
              return finalResult;
            else
              return loadingIndicator(color: Colors.blue);
            break;
          case ConnectionState.active:
            if(messagesContainer.length > 0)
              return finalResult;
            else
              return loadingIndicator(color: Colors.blue);
            break;
          case ConnectionState.waiting:
            if(messagesContainer.length > 0)
              return finalResult;
            else
              return loadingIndicator(color: Colors.blue);
            break;
          case ConnectionState.done:
            if (snapshot.hasError) 
              return Text('Error: ${snapshot.error}');
            if(messagesContainer.length + snapshot.data.keys.toList().length == 0){
              return Center(
                child: GestureDetector(
                  child: Container(
                    margin: EdgeInsets.fromLTRB(0, 0, 0, 35),
                    child: ListView(
                      shrinkWrap: true, 
                      padding: EdgeInsets.all(20.0),
                      children: [
                        Container(
                          child: Icon(Icons.bubble_chart, color: Colors.grey[400], size: 25,),
                          padding: EdgeInsets.fromLTRB(0, 10, 0, 0),
                        ),
                        Container(
                          alignment: Alignment.center,
                          child: Text(
                            'This Chat is Empty', 
                            style: TextStyle(
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.fromLTRB(0, 2, 0, 0),
                          alignment: Alignment.center,
                          child: Text(
                            '(Tap to Refresh)', 
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12
                            ),
                          ),
                        ),
                      ]
                    ),
                  ),
                  onTap: () async{
                    try{
                      fetchAndSaveNewMessages();
                      Map olderMessages = await getOlderMessages();
                      if(olderMessages.keys.length > 0){
                        List messageIds = olderMessages.keys.toList();
                        messageIds.sort();
                        offsetForMessages = int.parse(messageIds[messageIds.length - 1]);
                        for(var x = 0; x < messageIds.length; x++){
                          if(olderMessages[messageIds[x]]["isSentMessage"]){
                            messagesContainer.insert(0, generateSentMessageWidget(olderMessages[messageIds[x]]["sender"], olderMessages[messageIds[x]]["message"], int.parse(olderMessages[messageIds[x]]["ts"].toString()), olderMessages[messageIds[x]]["profilePic"]));
                          }
                          else{
                            messagesContainer.insert(0, generateReceivedMessageWidget(olderMessages[messageIds[x]]["sender"], olderMessages[messageIds[x]]["message"], int.parse(olderMessages[messageIds[x]]["ts"].toString()), olderMessages[messageIds[x]]["profilePic"], olderMessages[messageIds[x]]["num"]));
                          }
                        }                        
                      }
                    }
                    catch(err){
                      print(err);
                    }
                  },
                ),
              );
            }
            Map initialMessages = snapshot.data;
            List messageIds = initialMessages.keys.toList();
            messageIds.sort();
            try{
              offsetForMessages = int.parse(messageIds[messageIds.length - 1].toString());
            }
            catch(err){
              //RANGE ERROR
            }
            Widget loadMoreButton = Row(
              children: <Widget>[
                Flexible(
                  flex: 1,
                  child: Container(),
                ),
                Container(
                  margin: EdgeInsets.fromLTRB(0, 0, 0, 10),
                  decoration: BoxDecoration(
                    color: sentMessageWidgetColor,
                    borderRadius: BorderRadius.circular(100)
                  ),
                  child: IconButton( 
                    padding: EdgeInsets.all(0),
                    highlightColor: sentMessageWidgetColor,
                    icon: Icon(Icons.restore, color: Colors.white,),
                    onPressed: () async{
                      try{
                        fetchAndSaveNewMessages();
                        Map olderMessages = await getOlderMessages();
                        if(olderMessages.keys.length > 0){
                          List messageIds = olderMessages.keys.toList();
                          messageIds.sort();
                          offsetForMessages = int.parse(messageIds[messageIds.length - 1]);
                          for(var x = 0; x < messageIds.length; x++){
                            if(olderMessages[messageIds[x]]["isSentMessage"]){
                              messagesContainer.insert(0, generateSentMessageWidget(olderMessages[messageIds[x]]["sender"], olderMessages[messageIds[x]]["message"], int.parse(olderMessages[messageIds[x]]["ts"].toString()), olderMessages[messageIds[x]]["profilePic"]));
                            }
                            else{
                              messagesContainer.insert(0, generateReceivedMessageWidget(olderMessages[messageIds[x]]["sender"], olderMessages[messageIds[x]]["message"], int.parse(olderMessages[messageIds[x]]["ts"].toString()), olderMessages[messageIds[x]]["profilePic"], olderMessages[messageIds[x]]["num"]));
                            }
                          }                        
                        }
                        setState(() {});
                      }
                      catch(err){
                        print(err);
                      }
                    },
                  )
                ),
                Flexible(
                  flex: 1,
                  child: Container(),
                )
              ],
            );

            print("NEW MESSAGES ARE: ");
            print(initialMessages.keys);               
            for(var x = 0; x < messageIds.length; x++){
              if(x == 0)
                if(initialMessages[messageIds[x]]["hasMoreMessages"])
                  messagesContainer.insert(0, loadMoreButton);
              print(initialMessages[messageIds[x]]);
              print([initialMessages[messageIds[x]]["sender"], initialMessages[messageIds[x]]["message"], int.parse(initialMessages[messageIds[x]]["ts"].toString())]);
              if(initialMessages[messageIds[x]]["isSentMessage"]){
                messagesContainer.add(generateSentMessageWidget(initialMessages[messageIds[x]]["sender"], initialMessages[messageIds[x]]["message"], int.parse(initialMessages[messageIds[x]]["ts"].toString()), initialMessages[messageIds[x]]["profilePic"]));
              }
              else{
                messagesContainer.add(generateReceivedMessageWidget(initialMessages[messageIds[x]]["sender"], initialMessages[messageIds[x]]["message"], int.parse(initialMessages[messageIds[x]]["ts"].toString()), initialMessages[messageIds[x]]["profilePic"], initialMessages[messageIds[x]]["num"]));
              }
            }
            return finalResult;
        }
      },
    );
  
    var loadServerDetails;
    if(json.encode(currentServerInfo) == "{}"){
      loadServerDetails = FutureBuilder<Map>(
        future: getServerInfo(currentServer),
        builder: (BuildContext context, AsyncSnapshot<Map> snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.none:
              return serverInfoTable("", currentPort.toString(), "", "", "", "", "", "");
            case ConnectionState.active:
              return serverInfoTable("", currentPort.toString(), "", "", "", "", "", "");
            case ConnectionState.waiting:
              return serverInfoTable("", currentPort.toString(), "", "", "", "", "", "");
            case ConnectionState.done:
              if (snapshot.hasError)
                return Text('Error: ${snapshot.error}');
              currentServerInfo = snapshot.data;
              if(currentServerInfo == null || json.encode(currentServerInfo) == "{}")
                return serverInfoTable("", currentPort.toString(), "", "", "", "", "", "");
              return serverInfoTable(currentServerInfo["query"], currentPort.toString(), currentServerInfo["lat"], currentServerInfo["lon"], currentServerInfo["country"], currentServerInfo["city"], currentServerInfo["region"], currentServerInfo["isp"]);
          }
        },
      );
    }
    else{
      loadServerDetails = serverInfoTable(currentServerInfo["query"], currentPort.toString(), currentServerInfo["lat"], currentServerInfo["lon"], currentServerInfo["country"], currentServerInfo["city"], currentServerInfo["region"], currentServerInfo["isp"]);
    }



    /*client.receivedMessages = [
      generateSentMessageWidget(
          "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
          "d"),
      generateReceivedMessageWidget(
          "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
          "d")
    ];*/

    /*
    secp256k1EllipticCurve.generatePrivateKey().then((prkey1) {
      secp256k1EllipticCurve.generatePrivateKey().then((prkey2) {
        secp256k1EllipticCurve.generatePrivateKey().then((prkey3) async{
          print("THE Private KEY 1 IS :");
          print(prkey1);
          print("THE Private KEY 2 IS :");
          print(prkey2);
          print("THE Private KEY 3 IS :");
          print(prkey3);
          var pubKey1 = await secp256k1EllipticCurve.generatePublicKey(prkey1.toString());
          var pubKey2 = await secp256k1EllipticCurve.generatePublicKey(prkey2.toString());
          var pubKey3 = await secp256k1EllipticCurve.generatePublicKey(prkey3.toString());
          String pubk1 = pubKey1["x2"];
          String pubk2 = pubKey2["x2"];
          String pubk3 = pubKey3["x2"];
          print("THE SYMMETRIC KEY A IS :");
          print(await secp256k1EllipticCurve.generateSymmetricKey(prkey1, [BigInt.parse(pubk2), BigInt.parse(pubk3)]));
          print("THE SYMMETRIC KEY B IS :");
          print(await secp256k1EllipticCurve.generateSymmetricKey(prkey2, [BigInt.parse(pubk1), BigInt.parse(pubk3)]));
          print("THE SYMMETRIC KEY C IS :");
          print(await secp256k1EllipticCurve.generateSymmetricKey(prkey3, [BigInt.parse(pubk1), BigInt.parse(pubk2)]));
        });
      });
    });    */

    

    print("NEW WIDGET BUILT");
    print(context.toString().split("(")[0]);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: themeColor,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
            ),
            onPressed: () async {
              Navigator.pop(context);
            },
          ),
          title: GestureDetector(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                loadChatLabel,
                loadConnectionStatus
              ],
            ),
            onTap: () {
              showPrompt("Set Label", context, groupChatTextController, () async{
                await databaseManager.setGroupName(currentGroupId, groupChatTextController.text);
                groupChatTextController.text = "";
              });
            },
          ),
          actions: <Widget>[
            IconButton(
              icon: Icon(
                Icons.share,
                color: appBarTextColor,
              ),
              onPressed: () async {
                if (connected) {
                  String joinKey = await generateJoinKey(currentGroupId);
                  print(utf8.decode(base64.decode(joinKey))); 
                  Share.share(joinKey);
                } else {
                  toastMessageBottomShort("Not Connected", context);
                }
              },
            )
          ],
        ),
        body: TabBarView(
          children: [
            Stack(
              children: <Widget>[
                loadInitialMessages,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    Container(
                      padding: EdgeInsets.fromLTRB(10, 5, 5, 5),
                      alignment: Alignment.bottomCenter,
                      constraints: BoxConstraints(
                        maxHeight: 180,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Flexible(
                            flex: 1,
                            child: Container(
                              padding: EdgeInsets.fromLTRB(13, 3, 13, 3),
                              margin: EdgeInsets.fromLTRB(0, 0, 0, 0),
                              decoration: BoxDecoration(
                                color: appBarTextColor,
                                border: Border.all(
                                  color: themeColor,
                                ),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: SingleChildScrollView(
                                child: Theme(
                                  data: ThemeData(cursorColor: materialGreen),
                                  child: TextField(
                                    maxLines: null,
                                    obscureText: false,
                                    controller: messageTextController,
                                    autofocus: false,
                                    decoration: InputDecoration(
                                      enabledBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.transparent,
                                        ),
                                      ),
                                      focusedBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.transparent,
                                          width: 2.0,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(50),
                                      ),
                                      hintText: "type your message here..",
                                      border: new UnderlineInputBorder(
                                          borderSide: new BorderSide(
                                              color: Colors.red)),
                                      labelStyle: Theme.of(context)
                                          .textTheme
                                          .caption
                                          .copyWith(
                                              color: materialGreen,
                                              fontSize: 16),
                                      errorText: null,
                                    ),
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            margin: EdgeInsets.fromLTRB(10, 0, 0, 0),
                            padding: EdgeInsets.fromLTRB(3, 0, 0, 0),
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                                color: themeColor,
                                borderRadius: BorderRadius.circular(30)),
                            child: IconButton(
                              icon: Icon(
                                Icons.send,
                              ),
                              color: appBarTextColor,
                              onPressed: () async {
                                if (connected) {
                                  if(messageTextController.text.length > 0){
                                    int deliveryStatus = await sendMessage(messageTextController.text);
                                    switch (deliveryStatus) {
                                      case 0:
                                        toastMessageBottomShort("No Recipients", context);
                                        break;
                                      case -1:
                                        toastMessageBottomShort("Rejected By Server", context);
                                        break;
                                      case -2:
                                        toastMessageBottomShort("Connection Error", context);
                                        break;
                                      default:
                                        //Sent action
                                        toastMessageBottomShort("Sent!", context);
                                        print("message sent successfully!");
                                        setState(() {
                                          messageTextController.text = "";
                                          setState(() {});
                                        });

                                        break;
                                    }
                                  }
                                } else {
                                  toastMessageBottomShort("Not Connected", context);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Column(
                children: <Widget>[
                  Container(
                    alignment: Alignment.topLeft,
                    height: 60,
                    padding: EdgeInsets.fromLTRB(10, 20, 0, 0),
                    child: SizedBox.expand(
                      child: Column(
                        children: <Widget>[
                          Container(
                            alignment: Alignment.topLeft,
                            child: Text(
                              "Participants",
                              style: TextStyle(
                                color: themeColor,
                                fontSize: 20,
                              ),
                            ),
                          ),
                          Container(
                            alignment: Alignment.topRight,
                            padding: EdgeInsets.fromLTRB(0, 0, 10, 0),
                            child: Text(
                              "Recipients",
                              style: TextStyle(
                                color: themeColor,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Flexible(flex: 10, fit: FlexFit.tight, child: loadParticipants),
                ],
              ),
              Column(
                children: <Widget>[
                  Container(
                    alignment: Alignment.topLeft,
                    height: 55,
                    padding: EdgeInsets.fromLTRB(10, 20, 0, 0),
                    child: SizedBox.expand(
                      child: Column(
                        children: <Widget>[
                          Container(
                            alignment: Alignment.topLeft,
                            child: Text( 
                              "Server Details",
                              style: TextStyle(
                                color: themeColor,
                                fontSize: 20,
                              ),
                            ),
                          ),                          
                        ],
                      ),
                    ),
                  ),
                  Flexible(
                    flex: 10, 
                    fit: FlexFit.tight, 
                    child: loadServerDetails
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

///Class responsible for handling incomming messages from the server
class NewMessagesResponse{
  int messageId;
  String sender;
  String encryptedMessage;  
  BigInt compositeKey;  
  int timestamp;
  NewMessagesResponse(int messageId, String sender, String encryptedMessage, BigInt compositeKey, int timestamp){
    this.messageId = messageId;
    this.sender = sender;
    this.encryptedMessage = encryptedMessage;
    this.compositeKey = compositeKey;
    this.timestamp = timestamp;
  }
  Map toJSON(){
    return {
      "messageId": messageId,
      "sender": sender,
      "encryptedMessage": encryptedMessage,
      "compositeKeys": compositeKey,
      "timestamp": timestamp,
    };
  }
}


class SentMessageResponse{
  int messageId;
  int timestamp;
  SentMessageResponse(messageId, timestamp){
    this.messageId = messageId;
    this.timestamp = timestamp;
  }
}

class RequestPayload{
  String username, encryptedMessage, joinKey, publicKey, publicKey2, passphrase;
  Map signature, compositeKeys;
  int messagesOffset;
  BigInt symmetricKey;

  Future<RequestPayload> init({String message, String passphrase}) async{
      if(passphrase == null)
        passphrase = "";    
      this.symmetricKey = await databaseManager.getSymmetricKey(currentGroupId);
      if(message == null){
        message = secp256k1EllipticCurve.generateRandomString(100);
        this.encryptedMessage = message;
      }
      else
        this.encryptedMessage = await secp256k1EllipticCurve.encryptMessage(message, symmetricKey);
      String encryptedMessageHash = sha256.convert(utf8.encode(encryptedMessage)).toString();
      this.username = await databaseManager.getUsername();
      this.signature = await secp256k1EllipticCurve.signMessage(encryptedMessageHash, currentPrivateKey);
      this.compositeKeys = await databaseManager.generateCompositeKeysForRecipients(currentGroupId);
      this.messagesOffset = await databaseManager.getLastMessageId(currentGroupId);
      this.joinKey = await databaseManager.getGroupJoinKey(currentGroupId);
      if(newGroupConnection){
        this.publicKey = currentPublicKey["x2"]; 
        this.publicKey2 = currentPublicKey["x"];        
      }
      else{
        this.publicKey = globalGroupJoinKey.publicKey.toString(); 
        this.publicKey2 = globalGroupJoinKey.publicKey2.toString();
      }
      this.passphrase = passphrase;
      return this;
  }

  toJSON(){
    return {
      "encryptedMessage": encryptedMessage,
      "signature": json.encode(signature),
      "joinKey": joinKey,
      "username": username,
      "compositeKeys": json.encode(compositeKeys),
      "publicKey": publicKey,
      "publicKey2": publicKey2,
      "passphrase": passphrase,
      "offset": messagesOffset    
    };    
  }

  toMessageJSON(){
    return {
      "encryptedMessage": encryptedMessage,
      "signature": json.encode(signature),
      "joinKey": joinKey,
      "username": username,
      "compositeKeys": json.encode(compositeKeys)
    };
  }

  toNewGroupJSON(){
    return {
      "username": username,
      "publicKey": currentPublicKey["x2"],
      "publicKey2": currentPublicKey["x"],
      "passphrase": passphrase
    };
  }

  toJoinGroupJSON(){
    return {
      "encryptedMessage": encryptedMessage,
      "signature": json.encode(signature),
      "username": username,
      "publicKey": publicKey,
      "publicKey2": publicKey2,
      "joinKey": joinKey,
    };
  }  

  toGetParticipantsJSON(){
    return {
      "encryptedMessage": encryptedMessage,
      "signature": json.encode(signature),
      "joinKey": joinKey,
      "username": username
    };    
  }

  toGetNewMessagesJSON(){
    return {
      "encryptedMessage": encryptedMessage,
      "signature": json.encode(signature),
      "joinKey": joinKey,
      "username": username,
      "offset": messagesOffset
    };
  }
}