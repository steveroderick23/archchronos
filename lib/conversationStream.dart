import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'common.dart';

enum DialogActions {
  cancel,
  discard,
  disagree,
  agree,
}

class ConversationStream extends StatefulWidget {

  ConversationStream({Key key,
    this.archChronosUser,
    this.tenantID,
    this.conversationWithNames,
    this.conversationWithUIDs,})
      : super(key: key);

  ArchChronosUser archChronosUser;
  String tenantID;
  String conversationWithUIDs;
  String conversationWithNames;

  @override
  MessengerState createState() => new MessengerState();
}

class _ChipsTile extends StatelessWidget {
  const _ChipsTile({
    Key key,
    this.children,
  }) : super(key: key);

  final List<Widget> children;

  // Wraps a list of chips into a ListTile for display as a section in the demo.
  @override
  Widget build(BuildContext context) {
    return new ListTile(
      subtitle: children.isEmpty
          ? new Center(
        child: new Padding(
          padding: const EdgeInsets.all(8.0),
          child: new Text(
            'No Recipients Selected',
            style: Theme.of(context).textTheme.caption.copyWith(fontStyle: FontStyle.italic, fontSize: 14.0, color: Colors.red,),
          ),
        ),
      )
          : new Wrap(
        children: children
            .map((Widget chip) => new Padding(
          padding: const EdgeInsets.all(4.0),
          child: chip,
        ))
            .toList(),
      ),
    );
  }
}

class MessengerState extends State<ConversationStream> {

  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  MessengerState();

  ArchChronosUser _selectedEmployee;
  String _message;
  final GlobalKey<FormState> _formKey = new GlobalKey<FormState>();
  bool _autovalidate = false;
  TextEditingController _messageController;
  ScrollController _scrollController;
  List<Message> messages = new List<Message>();

  int initialMessageTimestamp;

  final List<ArchChronosUser> _selectedRecipients = new List<ArchChronosUser>();
  final List<ArchChronosUser> _allArchChronosUsers = new List<ArchChronosUser>();

  @override
  void initState() {
    _selectedEmployee = new ArchChronosUser("All");
    _selectedEmployee.messagingToken = "NONE";
    _messageController = new TextEditingController(text: _message);
    _message = "";

    DateTime nowDT =new DateTime.now().toUtc();
    initialMessageTimestamp = nowDT.millisecondsSinceEpoch;

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

  Widget buildConversationsWidget() {

    if (widget.conversationWithUIDs == null || widget.conversationWithUIDs.length == 0)
    {
      return new Container(
        height: 0.0,
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: new Text(""),
      );
    }

    CollectionReference messagesRef  = firestoreDB.collection('tenants')
      .document(widget.tenantID).collection("users").document(widget.archChronosUser.uid)
      .collection("messages");

    Stream<QuerySnapshot> snapshot = messagesRef.where("conversationWithUIDs", isEqualTo: widget.conversationWithUIDs).snapshots();
    snapshot.listen(onData);

    Widget conversationWidget = new StreamBuilder<QuerySnapshot>(
      stream: snapshot,
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {

        if (!snapshot.hasData) return buildLoadingIndicator();

        _scrollController = new ScrollController(initialScrollOffset: snapshot.data.documents.length*200.0, keepScrollOffset: true,);

        initialMessageTimestamp = snapshot.data.documents[0]['initialMessageTimestamp'];

        ListView lv = new ListView.builder(

          itemBuilder: (context, index) {

            if (snapshot.data.documents[index]['hasBeenRead'] == false)
            {
              Message msg =  initMessageFromMap(snapshot.data.documents[index].data);
              msg.firestoreKey = snapshot.data.documents[index].documentID;
              msg.hasBeenRead = true;
              saveMessage(widget.archChronosUser, msg);
            }

            if (snapshot.data.documents[index]['direction'] == "incoming") {
              String senderLine = "From: " +
                  snapshot.data.documents[index]['sender'] + ", " +
                  formatTimeForLocalTimezone(snapshot.data.documents[index]['utcMillisSinceEpoch']);
              return new ListTile(
                leading: new CircleAvatar(
                  child: new Text(snapshot.data.documents[index]['sender'].substring(0,1)),
                ),
                title: new Text(
                  snapshot.data.documents[index]['message'],
                  style: new TextStyle(
                    fontWeight: FontWeight.normal,
                    fontSize: 14.0,
                  ),
                ),
                subtitle: new Text(
                  senderLine,
                  style: new TextStyle(
                    fontWeight: FontWeight.normal,
                    fontSize: 9.0,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              );
            }
            else
            {
              return new ListTile(
                title: new Text(
                  snapshot.data.documents[index]['message'],
                  style: new TextStyle(
                    fontWeight: FontWeight.normal,
                    fontSize: 14.0,
                  ),
                  textAlign: TextAlign.right,
                ),
                subtitle: new Text(
                  formatTimeForLocalTimezone(snapshot.data.documents[index]['utcMillisSinceEpoch']),
                  style: new TextStyle(
                    fontWeight: FontWeight.normal,
                    fontSize: 9.0,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.right,
                ),
              );
            }
          },
          controller: _scrollController,
          itemCount: snapshot.data.documents.length,

        );

        return lv;
      },
    );

    if (widget.conversationWithUIDs != null && widget.conversationWithUIDs.length >0)
    {
      return new Container(
        height: MediaQuery.of(context).size.height - 200.0,
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: conversationWidget,
      );
    }
    else
    {
      return new Container(
        height: MediaQuery.of(context).size.height - 350.0,
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: conversationWidget,
      );
    }
  }

  void showInSnackBar(String value) {
    _scaffoldKey.currentState.showSnackBar(new SnackBar(
        content: new Text(value)
    ));
  }

  Future handleEmployeeChanged(ArchChronosUser newValue) async {
    setState(() {
      _selectedEmployee = newValue;
    });
  }

  void _removeSelectedRecipient(ArchChronosUser user)
  {
    setState(() {
      _selectedRecipients.remove(user);
    });
  }

  void showPopupDialog<T>({ BuildContext context, Widget child }) {
    showDialog<T>(
      barrierDismissible: false,
      context: context,
      child: child,
    );
  }

  void _handleSendMessage() async {

    final FormState form = _formKey.currentState;

    if (!form.validate())
    {
      _autovalidate = true; // Start validating on every change.
    }
    else
    {

      List<ArchChronosUser> allUsers = new List<ArchChronosUser>();
      await loadAllArchChronosUsers(widget.tenantID, allUsers);

      if (widget.conversationWithUIDs != null && widget.conversationWithUIDs.length > 0)
      {
        List<String> uids = removeSelfFromUIDs(widget.conversationWithUIDs, widget.archChronosUser).split(",");
        _selectedRecipients.clear();
        for (ArchChronosUser archChronosUser in allUsers)
        {
          for(String uid in uids) {
            if (archChronosUser.uid == uid) {
              _selectedRecipients.add(archChronosUser);
              break;
            }
          }
        }
        if (_selectedRecipients.length == 0)
        {
          final ThemeData theme = Theme.of(context);
          final TextStyle dialogTextStyle = theme.textTheme.subhead.copyWith(color: theme.textTheme.caption.color);

          showPopupDialog<DialogActions>(
              context: context,
              child: new AlertDialog(
                  content: new Text(
                      "There seems to be an internal problem with this conversation. No further messages can be sent.",
                      style: dialogTextStyle
                  ),
                  actions: <Widget>[
                    new FlatButton(
                        child: const Text('OK'),
                        onPressed: () { Navigator.pop(context, DialogActions.cancel); }
                    ),
                  ]
              )
          );
          return;
        }
      }

      if (_selectedRecipients.length == 0)
      {
        final ThemeData theme = Theme.of(context);
        final TextStyle dialogTextStyle = theme.textTheme.subhead.copyWith(color: theme.textTheme.caption.color);

        showPopupDialog<DialogActions>(
            context: context,
            child: new AlertDialog(
                content: new Text(
                    "You must enter one or more recipients.",
                    style: dialogTextStyle
                ),
                actions: <Widget>[
                  new FlatButton(
                      child: const Text('OK'),
                      onPressed: () { Navigator.pop(context, DialogActions.cancel); }
                  ),
                ]
            )
        );
      }
      else {

        form.save();

        Set<ArchChronosUser> selectedRecipients = new Set<ArchChronosUser>();
        if (_selectedRecipients.length == 1) {
          ArchChronosUser archChronosUser = _selectedRecipients.elementAt(0);
          if (archChronosUser.uid == null || archChronosUser.uid.isEmpty)
            selectedRecipients.addAll(_allArchChronosUsers);
          else
            selectedRecipients.add(archChronosUser);
        }
        else
          selectedRecipients.addAll(_selectedRecipients);

        String conversationWithNames = "";
        String conversationWithUIDs = "";

        if (widget.conversationWithUIDs == null || widget.conversationWithUIDs.length == 0)
        {
          conversationWithNames = widget.archChronosUser.displayName;
          conversationWithUIDs = widget.archChronosUser.uid;

          for (ArchChronosUser recipient in selectedRecipients) {
            conversationWithNames = conversationWithNames + "," + recipient.displayName;
            conversationWithUIDs = conversationWithUIDs + "," + recipient.uid;
          }
        }
        else
        {
          conversationWithNames = widget.conversationWithNames;
          conversationWithUIDs = widget.conversationWithUIDs;
        }

        bool result = sendMessage(
            widget.tenantID, selectedRecipients, "Arch Chronos Messenger",
            _message, widget.archChronosUser,
            conversationWithNames, conversationWithUIDs);

        if (!result)
          showInSnackBar('Failed to send message. Please try again.');
        else {
          if (widget.conversationWithUIDs == null || widget.conversationWithUIDs.length == 0)
            Navigator.pop(context);
          _messageController.clear();
        }
      }
    }

  }

  void _handleAddRecipient() {

    if (_selectedRecipients.length == 1)
    {
     if (_selectedRecipients.elementAt(0).uid == null || _selectedRecipients.elementAt(0).uid.isEmpty)
       _selectedRecipients.clear();
    }

    if (_selectedEmployee.uid == null || _selectedEmployee.uid.isEmpty)
    {
      _selectedRecipients.clear();
    }

    _selectedRecipients.add(_selectedEmployee);

    setState(() {
    });
  }

  List<DropdownMenuItem<ArchChronosUser>> buildMenuItems(AsyncSnapshot<QuerySnapshot> snapshot) {

    List<DropdownMenuItem<ArchChronosUser>> menuItems = new List<DropdownMenuItem<ArchChronosUser>>();

    ArchChronosUser allArchChronosUser = new ArchChronosUser("All");
    allArchChronosUser.messagingToken = "NONE";
    menuItems.add(new DropdownMenuItem<ArchChronosUser>( value: allArchChronosUser, child: new Text("All"),));

    menuItems.addAll(snapshot.data.documents.map((DocumentSnapshot document) {
      
      ArchChronosUser archChronosUser = generateArchChronosUserFromDocumentSnapshot(document);
      if (archChronosUser.messagingToken != null && archChronosUser.messagingToken.isNotEmpty)
      {
        return new DropdownMenuItem<ArchChronosUser>(
          value: archChronosUser, child: new Text(archChronosUser.displayName),);
      }
      else
        return new DropdownMenuItem<ArchChronosUser>(
          value: archChronosUser, child: new Text("NONE"),);
    }).where((mi) => mi.value.messagingToken != null && mi.value.uid != widget.archChronosUser.uid).toList()
    );

    _allArchChronosUsers.clear();
    _allArchChronosUsers.addAll(snapshot.data.documents.map((DocumentSnapshot document) {
      ArchChronosUser archChronosUser = generateArchChronosUserFromDocumentSnapshot(document);
      return archChronosUser;
    }).where((archChronosUser) => archChronosUser.messagingToken != null && archChronosUser.uid != widget.archChronosUser.uid).toList()
    );

    return menuItems;
  }

  Widget buildUserDropdown() {

    CollectionReference usersRef = firestoreDB.collection("tenants").
    document(widget.tenantID).collection("users");

    Stream<QuerySnapshot> usersSnapshot = usersRef.snapshots();
    return new StreamBuilder<QuerySnapshot>(
      stream: usersSnapshot,
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (!snapshot.hasData) return const Text('Loading...');
        return new DropdownButtonHideUnderline(
          child: new DropdownButton<ArchChronosUser>(
            value: _selectedEmployee,
            items: buildMenuItems(snapshot),
            onChanged: handleEmployeeChanged,
          ),
        );
      },
    );
  }

  Future<bool> _warnUserAboutInvalidData() async {
//    final FormState form = _formKey.currentState;
//    if (form == null || !_formWasEdited || form.validate())
//      return true;
//
//    return await showDialog<bool>(
//      context: context,
//      builder: (BuildContext context) {
//        return new AlertDialog(
//          title: const Text('This form has errors'),
//          content: const Text('Really leave this form?'),
//          actions: <Widget> [
//            new RaisedButton(
//              child: const Text('YES'),
//              color: Colors.blueGrey,
//              onPressed: () { Navigator.of(context).pop(true); },
//            ),
//            new RaisedButton(
//              child: const Text('NO'),
//              color: Colors.blueGrey,
//              onPressed: () { Navigator.of(context).pop(false); },
//            ),
//          ],
//        );
//      },
//    ) ?? false;

    return true;
  }

  String _validateMessage(String value) {
    if (value.isEmpty)
      return 'Please provide a message.';
    return null;
  }
  
  Widget buildSendMessageWidget(chips)
  {
    Widget userDropdown = buildUserDropdown();
    if (widget.conversationWithUIDs != null && widget.conversationWithUIDs.length > 0)
    {
      return new Container(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          height: 90.0,
          child: new Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                  new SafeArea(
                  top: false,
                  bottom: false,
                  child: new Form(
                    key: _formKey,
                    autovalidate: _autovalidate,
                    onWillPop: _warnUserAboutInvalidData,
                    child: new SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: new Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[

                          new ListTile(
                            title: new TextFormField(
                              decoration: const InputDecoration(
                                hintText: 'Enter your message ...',
                              ),
                              maxLines: 1,
                              validator: _validateMessage,
                              controller: _messageController,
                              onSaved: (String value) {
                                _message = value;
                              },
                            ),
                            trailing: new Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  new IconButton( // action button
                                    icon: new Icon(
                                      Icons.send,
                                      color: Colors.blue,
                                      size: 32.0,
                                    ),
                                    onPressed: _handleSendMessage,
                                  ),
                                ]
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ]
          )
      );
    }
    else {
      return new Container(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        height: 250.0,
        child: new Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            new SafeArea(
              top: false,
              bottom: false,
              child: new Form(
                key: _formKey,
                autovalidate: _autovalidate,
                onWillPop: _warnUserAboutInvalidData,
                child: new SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: new Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      new ListTile(
                        leading: new Text("To"),
                        title: new Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              userDropdown,
                            ]
                        ),
                        trailing: new IconButton( // action button
                          icon: new Icon(
                            Icons.add_circle_outline,
                            color: Colors.grey,
                          ),
                          onPressed: _handleAddRecipient,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      new _ChipsTile(children: chips),
                      const SizedBox(height: 10.0),
                      new ListTile(
                        title: new TextFormField(
                          decoration: const InputDecoration(
                            hintText: 'Enter your message ...',
                          ),
                          maxLines: 1,
                          validator: _validateMessage,
                          controller: _messageController,
                          onSaved: (String value) {
                            _message = value;
                          },
                        ),
                        trailing: new Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              new IconButton( // action button
                                icon: new Icon(
                                  Icons.send,
                                  color: Colors.blue,
                                  size: 32.0,
                                ),
                                onPressed: _handleSendMessage,
                              ),
                            ]
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget build(BuildContext context) {

    final List<Widget> chips = _selectedRecipients.map<Widget>((ArchChronosUser archChronosUser) {
      return new Chip(
        key: new ValueKey<String>(archChronosUser.displayName),
        backgroundColor: Colors.lightBlueAccent,
        label: new Text(
          archChronosUser.displayName,
          style: new TextStyle(
            fontSize: 14.0,
            color: Colors.white,
          ),
        ),
        onDeleted: () {
          setState(() {
            _removeSelectedRecipient(archChronosUser);
          });
        },
      );
    }).toList();

    String headerText = "New Message";
    if (widget.conversationWithNames == null || widget.conversationWithNames.length == 0 )
      widget.conversationWithNames = "";
    else
      headerText = removeSelfFromNames(widget.conversationWithNames, widget.conversationWithUIDs, widget.archChronosUser);

    return new Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      appBar: new AppBar(
        title: new Text(headerText),
      ),
      body:  new Form(
        child: new ListView(
          reverse: true,
          padding: const EdgeInsets.all(16.0),
          children: <Widget> [

            buildConversationsWidget(),

            buildSendMessageWidget(chips),

         ].reversed.toList(),
        ),
      ),

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