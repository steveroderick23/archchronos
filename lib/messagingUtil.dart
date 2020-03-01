import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'common.dart';
import 'reports.dart';
import 'archChronosHome.dart';

final FirebaseMessaging firebaseMessaging = new FirebaseMessaging();

BuildContext messengerContext;
ArchChronosUser localArchChronosUser;
String localTenantID;
BuildContextCallback onChangeRouteTapped;
Reports reportsRef;
String homeTypeRef;
ArchChronosHome archChronosHomeRef;

Widget buildMessengerDialog(BuildContext context) {
  return new AlertDialog(
    content: new Text("Item 23 has been updated"),
    actions: <Widget>[
      new FlatButton(
        child: const Text('CLOSE'),
        onPressed: () {
          Navigator.pop(context, false);
        },
      ),
      new FlatButton(
        child: const Text('SHOW'),
        onPressed: () {
          Navigator.pop(context, true);
        },
      ),
    ],
  );
}

Future onSelectNotification(String payload) async {

  if (payload != null) {
    onChangeRouteTapped(messengerContext, "allConversations", "");
  }

}

void configureMessaging(BuildContext context, ArchChronosUser archChronosUser, String tenantID, BuildContextCallback changeRouteTapped, String homeType, Reports reports, ArchChronosHome archChronosHome)
{
  messengerContext = context;
  localArchChronosUser = archChronosUser;
  localTenantID = tenantID;
  onChangeRouteTapped = changeRouteTapped;
  homeTypeRef = homeType;
  reportsRef = reports;
  archChronosHomeRef = archChronosHome;

  firebaseMessaging.configure(
    onMessage: (Map<String, dynamic> message) {

    },
    onLaunch: (Map<String, dynamic> message) {

      if (homeTypeRef == "reports")
        reportsRef.redirectToAllConversations = true;
      else
        archChronosHomeRef.redirectToAllConversations = true;
    },
    onResume: (Map<String, dynamic> message) {
      onChangeRouteTapped(messengerContext, "allConversations", "");
    },
  );

  firebaseMessaging.requestNotificationPermissions(
      const IosNotificationSettings(sound: true, badge: true, alert: true));

  firebaseMessaging.onIosSettingsRegistered
      .listen((IosNotificationSettings settings) {
    print("Settings registered: $settings");
  });

  firebaseMessaging.getToken().then((String token) {

    if (token != null) {
      if (token != archChronosUser.messagingToken)
      {
        archChronosUser.messagingToken = token;
        firestoreDB.collection('tenants').document(tenantID).collection("users").document(archChronosUser.uid).setData(archChronosUser.toJson(), merge: true);
      }
    }
  });

}

void showMessengerDialog(BuildContext context) {
  showDialog<bool>(
    context: context,
    builder: (_) => buildMessengerDialog(context),
  ).then((bool shouldNavigate) {

  });
}