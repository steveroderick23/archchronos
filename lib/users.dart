import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'archChronosDrawer.dart';
import 'editUserDialog.dart';
import 'common.dart';

class Users extends StatefulWidget {

  static String routeName = "users";

  Users({Key key,
    this.archChronosUser,
    this.archChronosDrawer,
    this.onChangeRouteTapped,
    this.onSaveArchchronosUser,
    this.tenant})
      : super(key: key);

  ArchChronosUser archChronosUser;
  ArchChronosDrawer archChronosDrawer;
  final BuildContextCallback onChangeRouteTapped;
  final SaveArchChronosUserCallback onSaveArchchronosUser;
  Tenant tenant;

  @override
  UsersState createState() => new UsersState(archChronosDrawer, onSaveArchchronosUser);
}

class UsersState extends State<Users> {

  UsersState(this._archChronosDrawer, this._onSaveArchchronosUser);

  ArchChronosDrawer _archChronosDrawer;
  final SaveArchChronosUserCallback _onSaveArchchronosUser;
  Map<String, ArchChronosUser> users = new Map();

  @override
  void initState() {
  }
  
  Widget buildUsersWidget()
  {
    CollectionReference usersRef  = firestoreDB.collection('tenants').document(widget.tenant.tenantID).collection("users");
    Stream<QuerySnapshot> snapshot;

    if (widget.archChronosUser.isAdmin)
      snapshot = usersRef.snapshots();
    else
      snapshot = usersRef.where("uid", isEqualTo: widget.archChronosUser.uid).getDocuments().asStream();

    return new StreamBuilder<QuerySnapshot>(
      stream: snapshot,
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (!snapshot.hasData) return const Text('Loading...');
        return new ListView(
          padding: new EdgeInsets.symmetric(vertical: 4.0),
          children: snapshot.data.documents.map((DocumentSnapshot document) {
            String displayName = document['displayName'];
            if (displayName == null)
              displayName = "N/A";

            ArchChronosUser archChronosUser = initArchChronosUserFromMap("", document.data);

            return new ListTile(
              leading: new ImageIcon(new AssetImage('assets/user.png'),size: 36.0, color: Colors.blueGrey,),
              title: new Text(displayName),
              subtitle: new Text(document['emailAddress']),
              trailing: new IconButton(
                icon: new Icon(
                  Icons.edit,
                  color: Colors.blueGrey,
                ),
                onPressed: () {
                  Navigator.push(context, new MaterialPageRoute<DismissDialogAction>(
                    builder: (BuildContext context) => new EditUserDialog(widget.archChronosUser, archChronosUser, _onSaveArchchronosUser),
                    fullscreenDialog: true,
                  ));
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget build(BuildContext context) {
    return new Scaffold(
      backgroundColor: Colors.white,
      drawer: _archChronosDrawer,
      appBar: new AppBar(
        title: new Text("Users"),
      ),
      body: new Scrollbar(
        child: buildUsersWidget(),
      ),
      floatingActionButton: new FloatingActionButton(
        onPressed: () {
          ArchChronosUser newArchChronosUser = new ArchChronosUser("");
          newArchChronosUser.tenantId = widget.tenant.tenantID;
          newArchChronosUser.providerId = "password";
          newArchChronosUser.bankedTimeBalance = 0.0;
          newArchChronosUser.vacationBalance = 0.0;
          newArchChronosUser.vacationRate = 0.0;
          newArchChronosUser.emailAddress = "";
          newArchChronosUser.displayName = "";
          newArchChronosUser.uid = "";
          newArchChronosUser.isAdmin = false;
          newArchChronosUser.isEnabled = true;
          newArchChronosUser.isVacationAccumulated = true;
          newArchChronosUser.isTimeEntryRequired = true;

          Navigator.push(context, new MaterialPageRoute<DismissDialogAction>(
            builder: (BuildContext context) => new EditUserDialog(widget.archChronosUser, newArchChronosUser, _onSaveArchchronosUser),
            fullscreenDialog: true,
          ));
        },
        tooltip: 'New User',
        child: new Icon(
          Icons.add,
          color: Colors.white,
        ),
      ),
    );
  }

}