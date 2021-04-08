
import 'dart:async';
import 'dart:io';
import 'package:cipherchat/main.dart';
import 'package:flutter/material.dart';
import '../main.dart';

class Home extends StatefulWidget {
  HomeState createState() => HomeState();
}

class Conversation {
  int timestamp;
}

class HomeState extends State<Home> {
  TextEditingController accountIpInputController = TextEditingController();
  TextEditingController accountPortInputController = TextEditingController();
  TextEditingController accountUsernameInputController = TextEditingController();
  TextEditingController peerIpInputController = TextEditingController();
  Widget loadedGroupsWidget = Center(
    child: ListView(
      shrinkWrap: true,
      padding: EdgeInsets.fromLTRB(20, 15, 20, 30),
      children: [
        Center(
          child: Text(
            'Your past conversations will show here',
            style: TextStyle(
              color: themeColor,
            ),
          ),
        ),
      ],
    ),
  );
  Widget generateRecentConvoCard(String label, String profilePic, int timestamp, String lastMessage, String lastSender, String serverIp, int port, bool isGroup, BigInt privateKey, String joinKey, int groupId) {
    try {
      base64ToImageConverter(profilePic);
    } catch (err) {
      profilePic = databaseManager.defaultProfilePicBase64;
    }
    String date = "";
    int timeDiff = DateTime.now().millisecondsSinceEpoch - timestamp;
    if(timeDiff < 8640000){
      String hour = DateTime.fromMillisecondsSinceEpoch(timestamp).hour.toString();
      if(int.parse(hour) < 10)
        hour = "0"+hour;
      date = hour+":"+DateTime.fromMillisecondsSinceEpoch(timestamp).minute.toString();
    }
    else{
      date = DateTime.fromMillisecondsSinceEpoch(timestamp).day.toString()+"/"+DateTime.fromMillisecondsSinceEpoch(timestamp).month.toString()+"/"+DateTime.fromMillisecondsSinceEpoch(timestamp).year.toString();
    }
    isGroup = true;
    if(isGroup){
      return Card(
        color: cardColor,
        child: SizedBox(
          width: double.infinity,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async{
                //Navigate to chat screen and show previous messages
                await showCustomProcessDialog("Please Wait", context, dissmissable: true);          
                int joinStatus = await joinOldChat(await generateJoinKey(groupId), false, groupId: groupId);
                await Future.delayed(Duration(seconds: 2));  
                Navigator.pop(context);
                switch(joinStatus){
                  case 1:
                    Navigator.pushNamed(context, "/chat");
                    break;                                
                  case -1:
                    toastMessageBottomShort("Invalid Join Key", context);
                    break;
                  case -2:
                    toastMessageBottomShort("Username Taken For Server", context);
                    break;
                  case -3:
                    toastMessageBottomShort("Invalid Join Key", context);
                    break;
                }
              },
              child: Container(
                padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: Row(
                  children: <Widget>[
                    Container(
                      margin: EdgeInsets.fromLTRB(0, 0, 7, 0),
                      height: 34,
                      width: 34,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white,
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: base64ToImageConverter(profilePic),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.fromLTRB(10, 0, 10, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              label,
                              style: TextStyle(
                                  fontSize: 18, color: Colors.grey[700]),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            Row(
                              children: <Widget>[
                                ConstrainedBox( 
                                  constraints: BoxConstraints(
                                    maxWidth: 80
                                  ), 
                                  child: Text(lastSender, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600],),),
                                ),
                                Text(": ", maxLines: 1),
                                Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600],),),                              
                              ],
                            ),
                            Container(
                              alignment: Alignment.bottomRight,
                              child: Text(
                                date,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                                textAlign: TextAlign.left,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    else{
      return Card(
        color: cardColor,
        child: SizedBox(
          width: double.infinity,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async{
                //Navigate to chat screen and show previous messages 
              await showCustomProcessDialog("Please Wait", context, dissmissable: true);
                int joinStatus = await joinOldChat(await generateJoinKey(groupId), false, groupId: groupId);
                await Future.delayed(Duration(seconds: 2));  
                Navigator.pop(context);                              
                switch(joinStatus){
                  case 1:
                    Navigator.pushNamed(context, "/chat");
                    break;                                
                  case -1:
                    toastMessageBottomShort("Invalid Join Key", context);
                    break;
                  case -2:
                    toastMessageBottomShort("Username Taken For Server", context);
                    break;
                  case -3:
                    toastMessageBottomShort("Invalid Join Key", context);
                    break;
                }
              },
              child: Container(
                padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: Row(
                  children: <Widget>[
                    Container(
                      margin: EdgeInsets.fromLTRB(0, 0, 7, 0),
                      height: 34,
                      width: 34,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white,
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: base64ToImageConverter(profilePic),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.fromLTRB(10, 0, 10, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              lastSender,
                              style: TextStyle(
                                  fontSize: 18, color: Colors.grey[700]),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            Row(
                              children: <Widget>[
                                Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600],),),                              
                              ],
                            ),
                            Container(
                              alignment: Alignment.bottomRight,
                              child: Text(
                                date,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                                textAlign: TextAlign.left,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
  }

  Future<void> showAccountSettings(
      String title,
      BuildContext context,
      TextEditingController usernameController,
      TextEditingController ipController,
      TextEditingController portController,
      Future<dynamic> callback()) {
    databaseManager.getUsername().then((username) {
      accountUsernameInputController.text = username;
    });
    Widget alert = AlertDialog(
      title: Text(
        title,
      ),
      content: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            Theme(
              data: ThemeData(cursorColor: materialGreen),
              child: TextField(
                obscureText: false,
                controller: accountUsernameInputController,
                autofocus: true,
                decoration: InputDecoration(
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: materialGreen),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: materialGreen, width: 2.0),
                  ),
                  labelText: "Username",
                  border: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.red
                      ),
                  ),
                  labelStyle: Theme.of(context).textTheme.caption.copyWith(
                        color: materialGreen,
                        fontSize: 16,
                      ),
                  errorText: null,
                ),
                style: TextStyle(
                  color: materialGreen,
                  fontSize: 16,
                ),
                onEditingComplete: () async {
                  //UPDATE USERNAME
                },
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        /*FlatButton(
        child: Text("SUPPORT", style: TextStyle(color: materialGreen)),
        onPressed: () async {
          Navigator.pop(context);
          await Future.delayed(Duration(seconds: 2));
          //showDonationAlert(context);
        },
      ),*/
        FlatButton(
          child: Text("SAVE", style: TextStyle(color: materialGreen)),
          onPressed: () async{
            callback();
          },
        )
      ],
    );
    showDialog(context: context, barrierDismissible: true, child: alert);
    Completer<Null> completer = Completer();
    completer.complete();
    return completer.future;
  }

  Future<List> loadConversations(int offset) async{
    Map query = await databaseManager.getPastConversations(offset, searchFieldController.text);
    List queryResults = query["results"];
    bool moreConversations = query["hasMoreGroups"];
    List<Widget> results = [];
    for (var x = 0; x < queryResults.length; x++) {
      try{
        results.add(generateRecentConvoCard(queryResults[x]["label"], queryResults[x]["profilePic"], int.parse(queryResults[x]["tme"].toString()), queryResults[x]["msg"], queryResults[x]["username"], queryResults[x]["serverIp"], int.parse(queryResults[x]["serverPort"].toString()), true, BigInt.parse(queryResults[x]["privateKey"]), queryResults[x]["joinKey"], int.parse(queryResults[x]["gid"].toString())));
      }
      catch(err){
        print(err);
      }
    }
    try{
      for(var x= 0; x < results.length; x++){
        loadedConversationsWidgets.add(results[x]);
      }
      List gidArray = [];
      for(var x = 0; x < queryResults.length; x++){
        gidArray.add(queryResults[x]["gid"]);
      }
      int maxGid = largest(gidArray);
      groupsOffset = maxGid; 
    }
    catch(err){
      //No more conversations to load
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
                await loadConversations(groupsOffset);
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
    if(results.length > 0 && moreConversations){
      List loadConversationsWisgetsWithButton = loadedConversationsWidgets;
      loadConversationsWisgetsWithButton.add(loadMoreButton);
      return loadConversationsWisgetsWithButton; 
    }
    else{
      return loadedConversationsWidgets; 
    }
  }

  var loadProfilePicForSettingsMenu;

  TextEditingController usernameFieldController = TextEditingController();
  TextEditingController ipFieldController = TextEditingController();
  TextEditingController portFieldController = TextEditingController();
  TextEditingController searchFieldController = TextEditingController();

  int groupsOffset = -1;
  List<Widget> loadedConversationsWidgets = [];
  List<Map> loadedConversations = [];
  

  @override
  void initState() {
    databaseManager.getUsername().then((username) {
      accountUsernameInputController.text = username;
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    dio.onHttpClientCreate = (HttpClient client) {
      client.badCertificateCallback = (X509Certificate cert, String host, int port) {
        return true;
      };
    };

    //print(Localizations.localeOf(context));
    

    FutureBuilder loadRecentConversations = FutureBuilder<List>(
      future: loadConversations(groupsOffset),
      builder: (BuildContext context, AsyncSnapshot<List> snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.none:
            return loadingIndicator(color: Colors.blue);
          case ConnectionState.active:
            return loadingIndicator(color: Colors.blue);
          case ConnectionState.waiting:
            return loadingIndicator(color: Colors.blue);
          case ConnectionState.done:
            if (snapshot.hasError) 
              return Text('Error: ${snapshot.error}');
            List pastConvos = snapshot.data;
            print(loadedConversations); 
            if (pastConvos.length == 0 && loadedConversationsWidgets.length == 0) {
              loadedGroupsWidget = Center(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.fromLTRB(20, 15, 20, 30),
                  children: [
                    Center(
                      child: Text(
                        'Your past conversations will show here',
                        style: TextStyle(
                          color: themeColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
              return loadedGroupsWidget;
            }
            return ListView(
              shrinkWrap: true,
              padding: EdgeInsets.fromLTRB(4, 4, 4, 4),
              children: loadedConversationsWidgets,
            );
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: themeColor,
        title: Text("CipherChat"),
        actions: <Widget>[
          IconButton(
            icon: Icon(
              Icons.search,
            ),
            color: Colors.white,
            onPressed: () {
              showPrompt("Enter Filter", context, searchFieldController, (){
                setState(() {});
              });
            },
          ),
          IconButton(
            icon: Icon(
              Icons.settings,
            ),
            color: Colors.white,
            onPressed: () async {
              showAccountSettings("Settings", context, usernameFieldController,
                  ipFieldController, portFieldController, () async {
                if (accountUsernameInputController.text.length > 0){
                  if (await databaseManager.updateUsername(accountUsernameInputController.text)){
                    toastMessageBottomShort("Updated Successfully", context);
                  }
                  Navigator.pop(context);  
                }
              });
            },
          )
        ],
      ),
      body: loadRecentConversations,
      floatingActionButton: FloatingActionButton(
        backgroundColor: themeColor,
        onPressed: () {
          Navigator.pushNamed(context, '/start');
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
