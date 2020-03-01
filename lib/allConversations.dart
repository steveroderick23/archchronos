import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'archChronosDrawer.dart';
import 'common.dart';
import 'conversationStream.dart';

class AllConversations extends StatefulWidget {

  static String routeName = "allConversations";

  AllConversations({Key key,
    this.archChronosUser,
    this.archChronosDrawer,
    this.onChangeRouteTapped,
    this.tenant})
      : super(key: key);

  ArchChronosUser archChronosUser;
  ArchChronosDrawer archChronosDrawer;
  final BuildContextCallback onChangeRouteTapped;
  Tenant tenant;

  @override
  AllConversationsState createState() => new AllConversationsState(archChronosDrawer, onChangeRouteTapped);
}

class AllConversationsState extends State<AllConversations> {

  AllConversationsState(this._archChronosDrawer, this._onChangeRouteTapped);

  ScrollController _scrollController;
  ArchChronosDrawer _archChronosDrawer;
  final BuildContextCallback _onChangeRouteTapped;
  Map<String, ArchChronosUser> users = new Map();

  @override
  void initState() {

  }

  Widget build(BuildContext context) {

    return new Scaffold(
      backgroundColor: Colors.white,
      drawer: _archChronosDrawer,
      appBar: new AppBar(
        title: new Text("Messenger Conversations"),
      ),
      body: buildConversationsWidget(widget.archChronosUser),
      floatingActionButton: new FloatingActionButton(
        onPressed: () {
          Navigator.push(context, new MaterialPageRoute<DismissDialogAction>(
            builder: (BuildContext context) => new ConversationStream(archChronosUser: widget.archChronosUser, tenantID: widget.tenant.tenantID, conversationWithNames: "", conversationWithUIDs: "",),
            fullscreenDialog: true,
          ));
        },
        tooltip: 'New Message',
        child: new Icon(
          Icons.add,
          color: Colors.white,
        ),
      ),
    );
  }

  String buildMessageText(String message, String sender, int numInGroup)
  {
    if (sender == widget.archChronosUser.displayName)
      return "You: " + message;
    else if (numInGroup > 2)
      return sender + ": " + message;
    else
      return message;
  }

  Widget buildLoadingIndicator()
  {
    return new Container(
      padding: const EdgeInsets.only(
        top: 30.0,
      ),
      child: new Center(
        child: new Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            new Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                new Text(
                  "Loading ...",
                  style: new TextStyle(fontSize: 14.0),
                ),
                new Text(
                  "       ",
                  style: new TextStyle(fontSize: 14.0),
                ),
                new CircularProgressIndicator(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  buildConversationsWidget(ArchChronosUser archChronosUser) {

    CollectionReference messagesRef  = firestoreDB.collection('tenants').document(widget.tenant.tenantID).collection("users").document(widget.archChronosUser.uid).collection("messages");
    Stream<QuerySnapshot> snapshot = messagesRef.snapshots();
    snapshot.listen(onData);

    return new StreamBuilder<QuerySnapshot>(
      stream: snapshot,
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {

        if (!snapshot.hasData) return buildLoadingIndicator();

        // loop through the snapshot to build a hash of conversation streams
        Map<String, List<Message>> commStreamMap = new Map<String, List<Message>>();
        for (DocumentSnapshot commInstance in snapshot.data.documents) {
          Message message = initMessageFromMap(commInstance.data);


          if (!commStreamMap.containsKey(message.conversationWithUIDs))
            commStreamMap[message.conversationWithUIDs] = new List<Message>();

          commStreamMap[message.conversationWithUIDs].add(message);
        }

        // then create a ListTile for each stream

        _scrollController = new ScrollController(initialScrollOffset: commStreamMap.length*200.0, keepScrollOffset: true,);

        ListView lv = new ListView.builder(

          itemBuilder: (context, index) {

            List<Message> messages = commStreamMap.values.elementAt(index);
            Message latestMessage = messages.elementAt(messages.length -1);
            TextStyle ts;
            if (latestMessage.hasBeenRead)
              ts = new TextStyle(fontWeight: FontWeight.normal, fontSize: 14.0,);
            else
              ts = new TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0, color: Colors.red);

              return new ListTile(
                onTap: () {
                  Navigator.push(context, new MaterialPageRoute<DismissDialogAction>(
                    builder: (BuildContext context) => new ConversationStream(
                        archChronosUser: widget.archChronosUser,
                        tenantID: widget.tenant.tenantID,
                        conversationWithNames: latestMessage.conversationWithNames,
                        conversationWithUIDs: latestMessage.conversationWithUIDs,),
                    fullscreenDialog: true,
                  ));
                },
                isThreeLine: true,
                leading: new CircleAvatar(
                  child: new Text(pullFirstLetterFromNames(removeSelfFromNames(latestMessage.conversationWithNames, latestMessage.conversationWithUIDs, widget.archChronosUser))),
                ),
                title: new Text(formatNamesForDisplay(removeSelfFromNames(latestMessage.conversationWithNames, latestMessage.conversationWithUIDs, widget.archChronosUser))),
                subtitle: new Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    new Text(
                      buildMessageText(latestMessage.message, latestMessage.sender, latestMessage.conversationWithUIDs.split(",").length),
                      style: ts,
                    ),
                    new Text(
                      formatTimeForLocalTimezone(latestMessage.utcMillisSinceEpoch),
                      style: new TextStyle(
                        fontWeight: FontWeight.normal,
                        fontStyle: FontStyle.italic,
                        fontSize: 9.0,
                      ),
                    ),
                  ],
                ),
              );
          },
          controller: _scrollController,
          itemCount: commStreamMap.length,

        );

        return lv;
      },
    );
  }

  void onData(QuerySnapshot event) {
    if (_scrollController != null &&_scrollController.positions.isNotEmpty) {
      _scrollController.animateTo( // NEW
        _scrollController.position.maxScrollExtent + 200, // NEW
        duration: const Duration(milliseconds: 500), // NEW
        curve: Curves.ease, // NEW
      );
    }
  }
}