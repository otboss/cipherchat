import 'package:cipherchat/main.dart';
import 'package:flutter/material.dart';

///Displays the profile information of the peer currently connected to
class Profile extends StatefulWidget {
  ProfileState createState() => ProfileState();
}

class ProfileState extends State<Profile> {
  @override
  Widget build(BuildContext context) {
  
    FutureBuilder username = FutureBuilder<Map>(
      future: null, 
      builder: (BuildContext context, AsyncSnapshot<Map> snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.none:
            break;
          case ConnectionState.active:
            return Container();
          case ConnectionState.waiting:
            return Container();
          case ConnectionState.done:
            if (snapshot.hasError) {
              print(snapshot.error);
              return Text('Error: ${snapshot.error}');
            }
            String username = snapshot.data["username"];
            return Text(
              username,
              style: TextStyle(color: Colors.black, fontSize: 19),
            );
        }
        return null; // unreachable
      },
    );

    FutureBuilder profilePic = FutureBuilder<Map>(
      future: null, // a previously-obtained Future<String> or null
      builder: (BuildContext context, AsyncSnapshot<Map> snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.none:
            break;
          case ConnectionState.active:
            return Container();
          case ConnectionState.waiting:
            return Container();
          case ConnectionState.done:
            if (snapshot.hasError) {
              print(snapshot.error);
              return Text('Error: ${snapshot.error}');
            }
            Image profilePicture = base64ToImageConverter(snapshot.data["profilePic"]);
            return profilePicture;
        }
        return null; // unreachable
      },
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: themeColor,
        title: Text(
          "Peer Info",
          style: TextStyle(
            color: appBarTextColor,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(0, 0, 0, 10),
        children: <Widget>[
          Container(
            height: 250,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  height: 200,
                  width: 200,
                  child: FittedBox(
                    fit: BoxFit.fill,
                    child: profilePic,
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: username,
          ),
          Center(
            child: Text("IP Address: 013.213.354.533"),
          ),
          Center(
            child: Text("Port: 6333"),
          ),
          //Text("Other Info"),
          Container(
            padding: EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: Table(
              //border: TableBorder.all(color: themeColor),
              columnWidths: {
                0: FractionColumnWidth(0.16)
              },
              children: [
                TableRow(
                  children: [
                    Text(
                      "Country: ",
                      style: TextStyle(
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.end,
                    ),
                    Container(
                      padding: EdgeInsets.fromLTRB(5, 0, 0, 0),
                      child: Text("China", style: TextStyle(fontSize: 16),),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    Text(
                      "Region: ",
                      style: TextStyle(
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.end,
                    ),
                    Container(
                      padding: EdgeInsets.fromLTRB(5, 0, 0, 0),
                      child: Text("Jiangsu", style: TextStyle(fontSize: 16),),
                    ),
                    
                  ],
                ),
                TableRow(
                  children: [
                    Text(
                      "City: ",
                      style: TextStyle(
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.end,
                    ),
                    Container(
                      padding: EdgeInsets.fromLTRB(5, 0, 0, 0),
                      child: Text("Suzhou", style: TextStyle(fontSize: 16),),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    Text(
                      "ISP: ",
                      style: TextStyle(
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.end,
                    ),
                    Container(
                      padding: EdgeInsets.fromLTRB(5, 0, 0, 0),
                      child: Text("China Mobile", style: TextStyle(fontSize: 16),),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
