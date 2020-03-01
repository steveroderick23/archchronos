import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'archChronosDrawer.dart';
import 'common.dart';

enum DialogDemoAction {
  cancel,
  discard,
  disagree,
  agree,
}

class Settings extends StatefulWidget {

  static String routeName = "settings";

  Settings({Key key,
    this.archChronosDrawer,
    this.onChangeRouteTapped})
      : super(key: key);

  ArchChronosDrawer archChronosDrawer;
  final BuildContextCallback onChangeRouteTapped;
  bool popupRequired = false;

  @override
  SettingsState createState() => new SettingsState(archChronosDrawer, onChangeRouteTapped);
}

class SettingsState extends State<Settings> {

  SettingsState(this._archChronosDrawer, this._onChangeRouteTapped);

  TextEditingController _reportEmailController;
  ArchChronosDrawer _archChronosDrawer;
  final BuildContextCallback _onChangeRouteTapped;
  String _defaultReportEmailAddress;

  void showPopupDialog<T>({ BuildContext context, Widget child }) {
    showDialog<T>(
      barrierDismissible: false,
      context: context,
      child: child,
    );
  }

  Future reportEmailChanged(String newValue) async {
    _defaultReportEmailAddress = newValue;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('defaultReportEmailAddress', _defaultReportEmailAddress);
  }

  @override
  void initState() {

    super.initState();

    initVars();

  }

  Future initVars() async
  {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String defaultReportEmailAddress = prefs.getString("defaultReportEmailAddress");
    if (defaultReportEmailAddress != null)
      _defaultReportEmailAddress = defaultReportEmailAddress;
    else
      _defaultReportEmailAddress = "";

    _reportEmailController = new TextEditingController(text: _defaultReportEmailAddress);

    if (widget.popupRequired == true)
    {
      showPopupDialog<DialogDemoAction>(
          context: context,
          child: new AlertDialog(
              content: new Text(
                "Please provide the date of one of your paydays. \n\nIt can be any Friday payday in the past or future.",
                textAlign: TextAlign.center,
                style: new TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.0,
                  color: Colors.black,
                ),
              ),
              actions: <Widget>[
                new FlatButton(
                    child: const Text('OK'),
                    onPressed: () {
                      Navigator.pop(context, DialogDemoAction.cancel);
                    }
                ),
              ]
          )
      );
    }

    setState(() {

    });
  }

  bool validateDateSelectedIsAFriday(DateTime date)
  {
    if (date.weekday != 5)
      return false;
    else
      return true;
  }

  Widget buildGotoReportsWidget() {
    if (widget.popupRequired) {
      return new Container(
        padding: const EdgeInsets.all(25.0),
        child: new RaisedButton(
            color: Colors.blue,
            child: new Text(
              'Go To Time Reports',
              style: new TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12.0,
                color: Colors.white,
              ),
            ),
            onPressed: () async {
              _onChangeRouteTapped(context, "reports", "settings");
            }
        ),
      );
    }
    else
      return new Text("");
  }

  Widget build(BuildContext context) {
    return new Scaffold(
      backgroundColor: Colors.white,
      drawer: _archChronosDrawer,
      appBar: new AppBar(
        title: new Text("Settings"),
      ),
      body: new Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          new Expanded(
            child: new Container(
              padding: const EdgeInsets.all(15.0),
              child: new ListView(
                  children: [
                    new Container(
                      padding: const EdgeInsets.only(
                        top: 20.0,
                      ),
                      child: new Text(""),
                    ),
                    new Container(
                      padding: const EdgeInsets.only(
                        top: 10.0,
                      ),
                      child: new Container(
                        child: new Text(
                          "Enter a default email address for reports.",
                          style: new TextStyle(
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ),
                    new Container(
                      child: new TextField(
                        maxLines: 1,
                        onChanged: reportEmailChanged,
                        controller: _reportEmailController,
                        decoration: new InputDecoration(
                          hintText: 'Report Email Address',
                        ),
                      ),
                    ),
                    buildGotoReportsWidget(),
                  ]
              ),
            ),
          ),
        ],
      ),
    );
  }

}