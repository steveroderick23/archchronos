// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'common.dart';
import 'package:flutter/material.dart';

enum DialogActions {
  cancel,
  discard,
  disagree,
  agree,
}

class EditUserDialog extends StatefulWidget {
  const EditUserDialog(
      this.loggedInArchChronosUser,
      this.archChronosUser,
      this.onSaveArchchronosUser, {
        Key key,
      })
      : super(key: key);

  final ArchChronosUser loggedInArchChronosUser;
  final ArchChronosUser archChronosUser;
  final SaveArchChronosUserCallback onSaveArchchronosUser;

  @override
  EditUserDialogState createState() => new EditUserDialogState(this.loggedInArchChronosUser, this.archChronosUser, this.onSaveArchchronosUser);
}

class EditUserDialogState extends State<EditUserDialog>
{
  bool _saveNeeded = false;
  String displayName;
  String emailAddress;
  String password;
  bool isAdmin;
  bool isTimeEntryRequired;
  bool isVacationAccumulated;
  String bankedTimeBalance;
  String vacationBalance;
  String vacationRate;
  bool isEnabled ;

  bool isNewUser = false;
  String headerText = "Edit User";
  String messagingToken = "";
  String lastMessage = "";

  EditUserDialogState(this._loggedInArchChronosUser, this._archChronosUser, this._onSaveArchchronosUser);

  ArchChronosUser _loggedInArchChronosUser;
  ArchChronosUser _archChronosUser;
  final SaveArchChronosUserCallback _onSaveArchchronosUser;

  TextEditingController displayNameController;
  TextEditingController emailAddressController;
  TextEditingController passwordController;
  TextEditingController bankedTimeBalanceController;
  TextEditingController vacationBalanceController;
  TextEditingController vacationRateController;

  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  final double colOneWidth = 145.0;
  final double colTwoWidth = 180.0;

  @override
  void initState() {

    super.initState();

    displayName = _archChronosUser.displayName;
    emailAddress =_archChronosUser.emailAddress;
    bankedTimeBalance = _archChronosUser.bankedTimeBalance.toString();
    vacationBalance = _archChronosUser.vacationBalance.toString();
    vacationRate = _archChronosUser.vacationRate.toString();
    isAdmin = _archChronosUser.isAdmin;
    isEnabled = _archChronosUser.isEnabled;
    isTimeEntryRequired = _archChronosUser.isTimeEntryRequired;
    isVacationAccumulated = _archChronosUser.isVacationAccumulated;
    password = _archChronosUser.password;

    displayNameController = new TextEditingController(text: displayName);
    emailAddressController = new TextEditingController(text: emailAddress);
    bankedTimeBalanceController = new TextEditingController(text: bankedTimeBalance);
    vacationBalanceController = new TextEditingController(text: vacationBalance);
    vacationRateController = new TextEditingController(text: vacationRate);
    passwordController = new TextEditingController(text: password);

    if (_archChronosUser.uid == null || _archChronosUser.uid.isEmpty)
    {
      headerText = "New User";
      isNewUser = true;
    }
    else
    {
      headerText = "User Profile";
      isNewUser = false;
    }

    loadLastMessage();
  }

  Future loadLastMessage() async
  {

    SharedPreferences prefs = await SharedPreferences.getInstance();
    lastMessage = prefs.getString("lastMessage");

    setState(() {

    });

  }

  void showPopupDialog<T>({ BuildContext context, Widget child }) {
    showDialog<T>(
      barrierDismissible: false,
      context: context,
      child: child,
    );
  }

  void addClicked() {

  }

  void displayNameTextChanged(String newValue) {
    setState(() {
      _saveNeeded = true;
      displayName = displayNameController.text;
    });
  }

  void emailAddressChanged(String newValue) {
    setState(() {
      _saveNeeded = true;
      emailAddress = emailAddressController.text;
    });
  }

  void passwordChanged(String newValue) {
    setState(() {
      _saveNeeded = true;
      password = passwordController.text;
    });
  }

  void bankedTimeBalanceChanged(String newValue) {
    setState(() {
      _saveNeeded = true;
      bankedTimeBalance = bankedTimeBalanceController.text;
    });
  }
  void vacationBalanceChanged(String newValue) {
    setState(() {
      _saveNeeded = true;
      vacationBalance = vacationBalanceController.text;
    });
  }
  void vacationRateChanged(String newValue) {
    setState(() {
      _saveNeeded = true;
      vacationRate = vacationRateController.text;
    });
  }

  saveClicked() async {

    final ThemeData theme = Theme.of(context);
    String validationMessage = validateUser();
    if (validationMessage != "") {
      final TextStyle dialogTextStyle = theme.textTheme.subhead.copyWith(
        color: theme.textTheme.caption.color);
        showPopupDialog<DialogActions>(
          context: context,
          child: new AlertDialog(
            content: new Text(
                validationMessage,
                style: dialogTextStyle
            ),
            actions: <Widget>[
              new FlatButton(
                  child: const Text('OK'),
                  onPressed: () {
                    Navigator.pop(context, DialogActions.cancel);
                  }
              ),
            ]
          )
      );
      return;
    }

    widget.archChronosUser.emailAddress = emailAddress;
    widget.archChronosUser.password = password;
    widget.archChronosUser.displayName = displayName;
    widget.archChronosUser.isTimeEntryRequired = isTimeEntryRequired;
    widget.archChronosUser.isVacationAccumulated = isVacationAccumulated;
    widget.archChronosUser.isEnabled = isEnabled;
    widget.archChronosUser.isAdmin = isAdmin;
    widget.archChronosUser.bankedTimeBalance = double.parse(bankedTimeBalance);
    widget.archChronosUser.vacationBalance = double.parse(vacationBalance);
    widget.archChronosUser.vacationRate = double.parse(vacationRate);

    if (widget.archChronosUser.uid.isEmpty)
    {
      FirebaseAuth fbAuth = FirebaseAuth.instance;
      FirebaseUser newFBUser;
      try {
        newFBUser = await fbAuth.createUserWithEmailAndPassword(
            email: widget.archChronosUser.emailAddress,
            password: widget.archChronosUser.password);
        if (newFBUser == null) {
          final TextStyle dialogTextStyle = theme.textTheme.subhead.copyWith(
            color: theme.textTheme.caption.color);
            showPopupDialog<DialogActions>(
              context: context,
              child: new AlertDialog(
                content: new Text(
                    "There was an error saving this new user.",
                    style: dialogTextStyle
                ),
                actions: <Widget>[
                  new FlatButton(
                      child: const Text('OK'),
                      onPressed: () {
                        Navigator.pop(context, DialogActions.cancel);
                      }
                  ),
                ]
              )
          );
          return;
        }
        else {
          List<UserInfo> userInfoList = newFBUser.providerData;
          UserInfo ui = userInfoList[1];
          widget.archChronosUser.providerId = ui.providerId;
          widget.archChronosUser.uid = newFBUser.uid;
        }
      }
      catch(exception)
      {
        String message = "There was an error saving this new user.";
        if (exception.toString().indexOf("The email address is already in use by another account.") > -1)
          message = "The email address provided has already been used.";

        final TextStyle dialogTextStyle = theme.textTheme.subhead.copyWith(
          color: theme.textTheme.caption.color);
          showPopupDialog<DialogActions>(
            context: context,
            child: new AlertDialog(
                content: new Text(
                    message,
                    style: dialogTextStyle
                ),
                actions: <Widget>[
                  new FlatButton(
                      child: const Text('OK'),
                      onPressed: () {
                        Navigator.pop(context, DialogActions.cancel);
                      }
                  ),
                ]
            )
        );
        return;
      }
    }

    _onSaveArchchronosUser(widget.archChronosUser);

    Navigator.pop(context);

  }

  Future deleteUser() async
  {
    CollectionReference usersRef = firestoreDB.collection("tenants").
      document(_archChronosUser.tenantId).collection("users");

    QuerySnapshot userSnapshot = await usersRef.where("uid", isEqualTo: _archChronosUser.uid).getDocuments();

    if (userSnapshot != null)
    {
      for (DocumentSnapshot userDoc in userSnapshot.documents) {

        userDoc.reference.delete();

      }
    }
  }

  String validateUser() {

    String errorMessage = "";

    if (displayName.isEmpty)
    {
      errorMessage = "Display Name required.";
    }

    if (emailAddress.isEmpty)
    {
      errorMessage = "Email address required.";
    }

    if (_archChronosUser.providerId.indexOf("google") == -1 && (password.isEmpty || password.length < 6))
    {
      errorMessage = "Password is required and must be at least 6 characters.";
    }

    try{
      double.parse(bankedTimeBalance);
    }
    catch(exception){
      errorMessage = "Invalid Banked Time Balance.";
    }

    try{
      double.parse(vacationBalance);
    }
    catch(exception){
      errorMessage = "Invalid Vacation Balance.";
    }

    if (widget.loggedInArchChronosUser.uid == _archChronosUser.uid && isEnabled == false)
    {
      errorMessage = "Cannot disable current user.";
    }

    return errorMessage;
  }

  Future<bool> _onWillPop() async {
    if (!_saveNeeded)
      return true;

    final ThemeData theme = Theme.of(context);
    final TextStyle dialogTextStyle = theme.textTheme.subhead.copyWith(color: theme.textTheme.caption.color);

    return await showDialog<bool>(
      context: context,
      child: new AlertDialog(
        content: new Text(
          'Discard new event?',
          style: dialogTextStyle
        ),
        actions: <Widget>[
          new FlatButton(
            child: const Text('CANCEL'),
            onPressed: () {
              Navigator.of(context).pop(DialogActions.cancel); // Pops the confirmation dialog but not the page.
            }
          ),
          new FlatButton(
            child: const Text('DISCARD'),
            onPressed: () {
              Navigator.of(context).pop(DialogActions.agree); // Returning true to _onWillPop will pop again.
            }
          )
        ]
      )
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {

    List<Widget> actions = new List<Widget>();

    if (_loggedInArchChronosUser.isAdmin ) {

      if (!isNewUser) {
        actions.add(new IconButton( // action button
          icon: new Icon(
            Icons.delete,
            color: Colors.white,
          ),
          onPressed: () {

            final ThemeData theme = Theme.of(context);
            final TextStyle dialogTextStyle = theme.textTheme.subhead.copyWith(color: theme.textTheme.caption.color);

            showPopupDialog<DialogActions>(
                context: context,
                child: new AlertDialog(
                    content: new Text(
                      "Are you Sure? All time entry data will be deleted.",
                      style: new TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    actions: <Widget>[
                      new FlatButton(
                          child: const Text('Cancel'),
                          onPressed: () {
                            Navigator.of(context).pop(DialogActions.cancel); // Pops the confirmation dialog but not the page.
                          }
                      ),
                      new FlatButton(
                          child: const Text('Yes - Delete'),
                          onPressed: () {
                            Navigator.of(context).pop(DialogActions.agree);

                            deleteUser();

                            Navigator.pop(context);
                          }
                      )
                    ]
                )
            );
            return;

          },
        ));
      }
    }

    return new Scaffold(
      key: _scaffoldKey,
      appBar: new AppBar(
        title: new Text(headerText),
        actions: actions,
      ),
      body: new Form(
        onWillPop: _onWillPop,
        child: new ListView(
          padding: const EdgeInsets.all(16.0),
          children: <Widget> [
            new Container(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: new Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: buildEditUserRows().toList(),
              ),
            ),
          ]
        )
      ),
      floatingActionButton: new FloatingActionButton(

        onPressed: () {
          this.saveClicked();
        },
        tooltip: 'Save User',
        child: new Icon(
          Icons.save,
        ),
      ),

    );
  }

  Iterable<Row> buildEditUserRows()
  {
    final ThemeData theme = Theme.of(context);
    List<Row> editUserRows = new List<Row>();

    bool isGoogle = false;
    if (_archChronosUser.providerId.contains("google.com"))
      isGoogle = true;

    if (!isGoogle) {

      editUserRows.add(

        new Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            new Container(
              child: new Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    new Text('Display Name', style: theme.textTheme.caption),
                  ]
              ),
              width: colOneWidth,
            ),
            new Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  new Container(
                    child: new Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          new Container(
                            padding: const EdgeInsets.only(
                              left: 10.0,
                            ),
                            width: colTwoWidth,
                            child: new TextField(
                              maxLines: 1,
                              onChanged: displayNameTextChanged,
                              controller: displayNameController,
                              decoration: new InputDecoration(
                                hintText: 'Enter A Display Name',
                              ),
                            ),
                          ),
                        ]
                    ),
                  ),
                ]
            ),
          ],
        ),
      );
    }
    else {

      editUserRows.add(

        new Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            new Container(
              padding: const EdgeInsets.only(
                top: 10.0,
                bottom: 10.0,
              ),
              child: new Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    new Text('Display Name', style: theme.textTheme.caption),
                  ]
              ),
              width: colOneWidth,
            ),
            new Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  new Container(
                    padding: const EdgeInsets.only(
                      top: 10.0,
                      bottom: 10.0,
                    ),
                    child: new Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          new Container(
                            padding: const EdgeInsets.only(
                              left:10.0,
                            ),
                            width: colTwoWidth,
                            child: new Text(
                              _archChronosUser.displayName,
                              style: theme.textTheme.caption,
                            ),
                          ),
                        ]
                    ),
                  ),
                ]
            ),
          ],
        ),

      );
    }

    if (_archChronosUser.uid.isEmpty)
    {
      editUserRows.add(

        new Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            new Container(
              padding: const EdgeInsets.only(
                top: 10.0,
                bottom: 10.0,
              ),
              child: new Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    new Text('Email Address', style: theme.textTheme.caption),
                  ]
              ),
              width: colOneWidth,
            ),
            new Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  new Container(
                    padding: const EdgeInsets.only(
                      top: 10.0,
                      bottom: 10.0,
                    ),
                    child: new Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          new Container(
                            padding: const EdgeInsets.only(
                              left: 10.0,
                            ),
                            width: colTwoWidth,
                            child: new TextField(
                              maxLines: 1,
                              onChanged: emailAddressChanged,
                              controller: emailAddressController,
                              decoration: new InputDecoration(
                                hintText: 'Enter Email Address',
                              ),
                            ),
                          ),
                        ]
                    ),
                  ),
                ]
            ),
          ],
        ),
      );

      editUserRows.add(

        new Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            new Container(
              padding: const EdgeInsets.only(
                bottom: 10.0,
              ),
              child: new Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    new Text('Password', style: theme.textTheme.caption),
                  ]
              ),
              width: colOneWidth,
            ),
            new Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  new Container(
                    padding: const EdgeInsets.only(
                      bottom: 10.0,
                    ),
                    child: new Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          new Container(
                            padding: const EdgeInsets.only(
                              left:10.0,
                            ),
                            width: colTwoWidth,
                            child: new TextField(
                              maxLines: 1,
                              onChanged: passwordChanged,
                              controller: passwordController,
                              decoration: new InputDecoration(
                                hintText: 'Enter Password',
                              ),
                            ),
                          ),
                        ]
                    ),
                  ),
                ]
            ),
          ],
        ),

      );
    }
    else {
      editUserRows.add(

        new Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            new Container(
              child: new Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    new Text('Email Address', style: theme.textTheme.caption),
                  ]
              ),
              width: colOneWidth,
            ),
            new Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  new Container(
                    padding: const EdgeInsets.only(
                      top: 10.0,
                      bottom: 10.0,
                    ),
                    child: new Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          new Container(
                            padding: const EdgeInsets.only(
                              left: 10.0,
                            ),
                            width: colTwoWidth,
                            child: new Text(
                              _archChronosUser.emailAddress,
                              style: theme.textTheme.caption,
                            ),
                          ),
                        ]
                    ),
                  ),
                ]
            ),
          ],
        ),
      );
    }

    if (_loggedInArchChronosUser.isAdmin && !isGoogle) {
      editUserRows.add(

        new Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            new Container(
              padding: const EdgeInsets.only(
                bottom: 10.0,
              ),
              child: new Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    new Text('Password', style: theme.textTheme.caption),
                  ]
              ),
              width: colOneWidth,
            ),
            new Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  new Container(
                    padding: const EdgeInsets.only(
                      bottom: 10.0,
                    ),
                    child: new Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          new Container(
                            padding: const EdgeInsets.only(
                              left: 10.0,
                            ),
                            width: colTwoWidth,
                            child: new TextField(
                              maxLines: 1,
                              onChanged: passwordChanged,
                              controller: passwordController,
                              decoration: new InputDecoration(
                                hintText: 'Enter Password',
                              ),
                            ),
                          ),
                        ]
                    ),
                  ),
                ]
            ),
          ],
        ),

      );

    }

    editUserRows.add(

      new Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          new Container(
            child: new Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  new Text(
                      'Banked Time Balance', style: theme.textTheme.caption),
                ]
            ),
            width: colOneWidth,
          ),
          new Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                new Container(
                  child: new Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        new Container(
                          padding: const EdgeInsets.only(
                            left: 10.0,
                          ),
                          width: colTwoWidth,
                          child: new TextField(
                            maxLines: 1,
                            onChanged: bankedTimeBalanceChanged,
                            controller: bankedTimeBalanceController,
                            decoration: new InputDecoration(
                              hintText: 'Enter A Balance',
                            ),
                          ),
                        ),
                      ]
                  ),
                ),
              ]
          ),
        ],
      ),

    );

    editUserRows.add(

      new Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          new Container(
            child: new Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  new Text(
                      'Vacation Balance', style: theme.textTheme.caption),
                ]
            ),
            width: colOneWidth,
          ),
          new Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                new Container(
                  child: new Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        new Container(
                          padding: const EdgeInsets.only(
                            left: 10.0,
                          ),
                          width: colTwoWidth,
                          child: new TextField(
                            maxLines: 1,
                            onChanged: vacationBalanceChanged,
                            controller: vacationBalanceController,
                            decoration: new InputDecoration(
                              hintText: 'Enter A Balance',
                            ),
                          ),
                        ),
                      ]
                  ),
                ),
              ]
          ),
        ],
      ),

    );

    editUserRows.add(

      new Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          new Container(
            child: new Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  new Text('Is Admin', style: theme.textTheme.caption),
                ]
            ),
            width: colOneWidth,
          ),
          new Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                new Container(
                  child: new Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        new Container(
                          child: new Checkbox(
                              value: isAdmin, onChanged: (bool value) {
                            setState(() {
                              _saveNeeded = true;
                              isAdmin = value;
                            });
                          }),
                        ),
                      ]
                  ),
                ),
              ]
          ),
        ],
      ),

    );

    editUserRows.add(

      new Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          new Container(
            child: new Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  new Text(
                      'Time Entry Req', style: theme.textTheme.caption),
                ]
            ),
            width: colOneWidth,
          ),
          new Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                new Container(
                  child: new Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        new Container(
                          child: new Checkbox(value: isTimeEntryRequired,
                              onChanged: (bool value) {
                                setState(() {
                                  _saveNeeded = true;
                                  isTimeEntryRequired = value;
                                });
                              }),
                        ),
                      ]
                  ),
                ),
              ]
          ),
        ],
      ),

    );

    editUserRows.add(

      new Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          new Container(
            child: new Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  new Text('Enabled', style: theme.textTheme.caption),
                ]
            ),
            width: colOneWidth,
          ),
          new Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                new Container(
                  child: new Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        new Container(
                          child: new Checkbox(
                              value: isEnabled, onChanged: (bool value) {
                            setState(() {
                              _saveNeeded = true;
                              isEnabled = value;
                            });
                          }),
                        ),
                      ]
                  ),
                ),
              ]
          ),
        ],
      ),
    );

    return editUserRows;

  }
}

