import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'archChronosDrawer.dart';
import 'common.dart';
import 'weekView.dart';
import 'messagingUtil.dart';

enum DialogActions {
  cancel,
  discard,
  disagree,
  agree,
}

class ArchChronosHome extends StatefulWidget {

  static String routeName = "timeEntry";
  String title = "";
  WeekViewEntity weekViewEntity;

  ArchChronosHome(
      {Key key,
        this.tenant,
        this.archChronosDrawer,
        this.archChronosUser,
        this.onChangeRouteTapped,
        this.onShowNewMessageDialog,})
      : super(key: key);

  // This widget is the home page of your application. It is stateful,
  // meaning that it has a State object (defined below) that contains
  // fields that affect how it looks.

  // This class is the configuration for the state. It holds the
  // values (in this case the title) provided by the parent (in this
  // case the App widget) and used by the build method of the State.
  // Fields in a Widget subclass are always marked "final".

  Tenant tenant;
  ArchChronosUser archChronosUser;
  ArchChronosDrawer archChronosDrawer;
  final BuildContextCallback onChangeRouteTapped;
  final SimpleContextCallback onShowNewMessageDialog;
  bool redirectToAllConversations = false;

  @override
  ArchChronosHomeState createState() => new ArchChronosHomeState(archChronosDrawer, onChangeRouteTapped, onShowNewMessageDialog);
}

class ArchChronosHomeState extends State<ArchChronosHome> {

  ArchChronosHomeState(this._archChronosDrawer, this._onChangeRouteTapped, this._onShowNewMessageDialog);

  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  String dateRangeString = "";
  ArchChronosDrawer _archChronosDrawer;
  BuildContextCallback _onChangeRouteTapped;
  final SimpleContextCallback _onShowNewMessageDialog;

  @override
  void initState() {

    super.initState();

    dateRangeString = setupWeekViewEntity(widget.weekViewEntity, getCurrentDaySetToMidnightInUTC());
    pullWeekViewEntityFromCloud(widget.tenant.tenantID, widget.weekViewEntity, widget.archChronosUser.uid, _refreshView);

    configureMessaging(context, widget.archChronosUser, widget.tenant.tenantID, _onChangeRouteTapped, "archChronosHome", null, widget);

    if (widget.redirectToAllConversations == true)
    {
      widget.redirectToAllConversations = false;
      onChangeRouteTapped(messengerContext, "AllConversations", "");
    }

    initNewMessageListener();

  }

  Future initNewMessageListener() async
  {
    CollectionReference messagesRef  = firestoreDB.collection('tenants')
        .document(widget.tenant.tenantID).collection("users").document(widget.archChronosUser.uid)
        .collection("messages");

    Stream<QuerySnapshot> snapshot = messagesRef.snapshots();
    snapshot.listen(showMessageReceivedDialog);
  }

  void showPopupDialog<T>({ BuildContext context, Widget child }) {
    showDialog<T>(
      barrierDismissible: false,
      context: context,
      child: child,
    );
  }

  void showMessageReceivedDialog(QuerySnapshot event) {
    if (event.documentChanges.isNotEmpty)
    {
      // loop through the docs and if there are any unread, display something
      bool unreadMessages = false;
      for(DocumentChange doc in event.documentChanges)
      {
        Message message = initMessageFromMap(doc.document.data);

        if (!message.hasBeenRead)
        {
          unreadMessages = true;
          break;
        }
      }
      if (unreadMessages) {
        _onShowNewMessageDialog(context);
      }
    }
  }

  void _handleMoveBackAWeek()  {
    dateRangeString = setupWeekViewEntity(widget.weekViewEntity, widget.weekViewEntity.date.subtract(new Duration(days: 7)));
    pullWeekViewEntityFromCloud(widget.tenant.tenantID, widget.weekViewEntity, widget.archChronosUser.uid, _refreshView);
  }

  void _handleMoveAheadAWeek()  {
    dateRangeString = setupWeekViewEntity(widget.weekViewEntity, widget.weekViewEntity.date.add(new Duration(days: 7)));
    pullWeekViewEntityFromCloud(widget.tenant.tenantID, widget.weekViewEntity, widget.archChronosUser.uid, _refreshView);
  }

  void _handleWeekDayEntityUpdated()  {
    setState(() {
      pushWeekViewEntityToCloud(widget.tenant.tenantID, widget.weekViewEntity, widget.archChronosUser);
    });
  }

  void _refreshView() {
    setState(() {

    });
  }

  createHomeView () {
    return new WeekView(widget.tenant.tenantID, widget.weekViewEntity, dateRangeString, this._handleMoveBackAWeek, this._handleMoveAheadAWeek, this._handleWeekDayEntityUpdated, widget.archChronosUser, _refreshView);
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance
    // as done by the _incrementCounter method above.
    // The Flutter framework has been optimized to make rerunning
    // build methods fast, so that you can just rebuild anything that
    // needs updating rather than having to individually change
    // instances of widgets.
    return new Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: _archChronosDrawer,
      appBar: new AppBar(
          title: new Text("Arch Chronos"),
          actions: <Widget>[
            new IconButton( // action button
              icon:  new ImageIcon(new AssetImage('assets/icons8-calendar-' + new DateTime.now().day.toString() + '-50.png')),
              onPressed: () {
                dateRangeString = setupWeekViewEntity(widget.weekViewEntity, getCurrentDaySetToMidnightInUTC());
                pullWeekViewEntityFromCloud(widget.tenant.tenantID, widget.weekViewEntity, widget.archChronosUser.uid, _refreshView);
              },
            ),
          ]
      ),
      body: createHomeView(),
    );
  }
}


