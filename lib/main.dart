import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity/connectivity.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';

import 'users.dart';
import 'settings.dart';
import 'archChronosDrawer.dart';
import 'archChronosHome.dart';
import 'common.dart';
import 'reports.dart';
import "allConversations.dart";
import 'dart:io';

enum DialogActions {
  cancel,
  discard,
  disagree,
  agree,
}

final FirebaseAuth fbAuth = FirebaseAuth.instance;
final GoogleSignIn googleSignIn = new GoogleSignIn();
SharedPreferences prefs;

const int AUTHORIZED = 1;
const int UNAUTHORIZED = 2;
const int NOT_SIGNED_IN = 3;
const int INVALID_COMPANY = 4;
const int INVALID_USER = 5;

String tenantCode = "";
String displayName = "";
String emailAddress = "";
String password = "";
String verifyPassword = "";
String loginMessage = "";

TextEditingController tenantCodeController;
TextEditingController displayNameController;
TextEditingController emailController;
TextEditingController passwordController;
TextEditingController verifyPasswordController;
StreamSubscription subscription;

FirebaseUser fbUser;
ArchChronosUser archChronosUser = new ArchChronosUser("");
List<String> routeStack = new List<String>();
Tenant tenant;

ArchChronosDrawer drawer = new ArchChronosDrawer(onlogoutTapped: handleLogout, onChangeRouteTapped: handleShowRoute, onSaveArchchronosUser: saveArchChronosUser, archChronosUser: archChronosUser, companyName: tenantCode,);
Settings settings = new Settings(archChronosDrawer: drawer, onChangeRouteTapped: handleShowRoute);
Users users = new Users(archChronosDrawer: drawer, onChangeRouteTapped: handleShowRoute,  archChronosUser: archChronosUser, onSaveArchchronosUser: saveArchChronosUser);
AllConversations allConversations = new AllConversations(archChronosDrawer: drawer, onChangeRouteTapped: handleShowRoute,  archChronosUser: archChronosUser);
Reports reports = new Reports(archChronosDrawer: drawer, archChronosUser: archChronosUser, onChangeRouteTapped: handleShowRoute, onShowNewMessageDialog: handleShowNewMessageDialog,);
ArchChronosHome timEntry = new ArchChronosHome(archChronosDrawer: drawer,  archChronosUser: archChronosUser, onChangeRouteTapped: handleShowRoute, onShowNewMessageDialog: handleShowNewMessageDialog,);
SignUpOrLoginHome signUpOrLoginHome = new SignUpOrLoginHome();
NoConnectionHome noConnectionHome = new NoConnectionHome();
SignIn signIn = new SignIn();
CreateAccount createAccount = new CreateAccount();

void passwordChanged(String newValue) {
  password = newValue;
}

void verifyPasswordChanged(String newValue) {
  verifyPassword = newValue;
}

void emailAddressChanged(String newValue) {
  emailAddress = newValue;
}

void displayNameChanged(String newValue) {
  displayName = newValue;
}

void tenantCodeChanged(String newValue) {
  tenantCode = newValue;
}

Future saveArchChronosUser(ArchChronosUser updatedArchChronosUser) async
{
  firestoreDB.collection('tenants').document(updatedArchChronosUser.tenantId).collection("users").document(updatedArchChronosUser.uid).setData(updatedArchChronosUser.toJson());
  if (updatedArchChronosUser.uid == archChronosUser.uid) {
    archChronosUser = updatedArchChronosUser;
    timEntry.archChronosUser = updatedArchChronosUser;
    drawer.archChronosUser = updatedArchChronosUser;
    reports.archChronosUser = updatedArchChronosUser;
    users.archChronosUser = updatedArchChronosUser;
    allConversations.archChronosUser = updatedArchChronosUser;
  }
}


Widget splashScreen() {
  return new MaterialApp(
    home:  new Scaffold(
      backgroundColor: Colors.white,
      body: new Container(
        padding: const EdgeInsets.only(
          right: 20.0,
          left: 0.0,
        ),
        child: new Center(
          child: new Text(
            "Loading ...",
            style: new TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20.0,
              color: Colors.black,
            ),
          ),
        ),
      )
    ),
  );
}

Widget loggingInScreen() {
  return new MaterialApp(
    home:  new Scaffold(
      backgroundColor: Colors.black,
      body: new Container(
        padding: const EdgeInsets.only(
          right: 20.0,
          left: 0.0,
        ),
        child: new Center(
          child: new Text(
            'Logging In / Authorizing ...',
            style: new TextStyle(fontSize: 14.0, color: Colors.white),
          ),
        ),
      ),
    ),
  );
}

Widget unauthorized() {
  return new MaterialApp(
    home:  new Scaffold(
      backgroundColor: Colors.black,
      body: new Center(
        child: new Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            new Text(
              'The account selected is not authorized to use this app.',
              style: new TextStyle(fontSize: 14.0, color: Colors.red),
            ),
            new Text("--------"),
            new RaisedButton(
              child: const Text('Retry'),
              onPressed: () async {
                runApp(new ArchChronosLogin());
              },
            ),
          ],
        ),
      )
    ),
  );
}

Future<Tenant> queryForTenant(String tenantCode) async
{
  Tenant assignedTenant;

  CollectionReference tenantRef = firestoreDB.collection("tenants");
  QuerySnapshot snapshot;
  snapshot = await tenantRef.where("tenantCode", isEqualTo: tenantCode).getDocuments();
  if (snapshot != null && snapshot.documents.length > 0) {

    assignedTenant = initTenantFromMap(snapshot.documents[0].data);
    assignedTenant.tenantID = snapshot.documents[0].documentID;

    if (assignedTenant.paydayUtcMillisSinceEpoch == null)
    {
      loginMessage = "A system error occurred. The Company payday date has not been assigned.";
      return null;
    }

    reports.selectedPayday = new DateTime.fromMillisecondsSinceEpoch(assignedTenant.paydayUtcMillisSinceEpoch, isUtc: true);

  }

  return assignedTenant;
}

void assignTenant(tenant)
{
  reports.tenant = tenant;
  timEntry.tenant = tenant;
  users.tenant = tenant;
  allConversations.tenant = tenant;
}

Future<int> loginEmailAndPassword() async
{
  try {
    fbUser = await fbAuth.signInWithEmailAndPassword(
        email: emailAddress,
        password: password);
  }
  catch (exception)
  {
    loginMessage = "User not found in the selected company or credentials invalid. If you are a new user, return to the main screen and click 'Create Account'";
    fbAuth.signOut();
    googleSignIn.signOut();
    return UNAUTHORIZED;
  }
  try
  {
    // store the user token in local storage
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("loggedInEmailAddress", emailAddress);
    prefs.setString("loggedInPassword", password);
    prefs.setString("tenantCode", tenant.tenantCode);
  }
  catch (exception)
  {
    loginMessage = "An unexpected exception occurred";
    fbAuth.signOut();
    googleSignIn.signOut();
    return UNAUTHORIZED;
  }

  return AUTHORIZED;
}

Future<int> createAccountEmailAndPassword() async
{
  String errorMessage = "";
  bool tenantExists = false;

  if (tenantCode == null || tenantCode.isEmpty)
  {
    if (errorMessage.isEmpty)
      errorMessage = "Company ID can't be empty";
    else
      errorMessage = errorMessage + ", Company ID can't be empty";
  }
  if (emailAddress == null || emailAddress.isEmpty)
  {
    if (errorMessage.isEmpty)
      errorMessage = "Email Address can't be empty";
    else
      errorMessage = errorMessage + ", Email Address can't be empty";
  }
  if (password == null || password.isEmpty)
  {
    if (errorMessage.isEmpty)
      errorMessage = "Password can't be empty";
    else
      errorMessage = errorMessage + ", Password can't be empty";
  }
  if (password != verifyPassword)
  {
    if (errorMessage.isEmpty)
      errorMessage = "Passwords don't match";
    else
      errorMessage = errorMessage + ", Passwords don't match";
  }
  if (displayName == null || displayName.isEmpty)
  {
    if (errorMessage.isEmpty)
      errorMessage = "Display Name can't be empty";
    else
      errorMessage = errorMessage + ", Display Name can't be empty";
  }

  if (errorMessage.isNotEmpty)
  {
    loginMessage = errorMessage;
    return UNAUTHORIZED;
  }

  try {

    // check that email and password  - if it already exists, just use that user
    try{
      fbUser = await fbAuth.signInWithEmailAndPassword(email: emailAddress, password: password);
    }
    catch(exception)
    {
      fbUser = await fbAuth.createUserWithEmailAndPassword(email: emailAddress, password: password);
    }

    if (fbUser ==null)
      fbUser = await fbAuth.createUserWithEmailAndPassword(email: emailAddress, password: password);

    if (fbUser == null) {
      loginMessage = "Error occurred creating user account.";
      return UNAUTHORIZED;
    }

  }
  catch (exception)
  {
    loginMessage = "Error occurred creating user account: " + exception.toString();
    return UNAUTHORIZED;
  }

  return AUTHORIZED;
}

Future<int> loginGoogle() async {

  FirebaseUser user;
  try
  {
    final GoogleSignInAccount googleUser = await googleSignIn.signIn();
    if (googleUser == null)
    {
      return UNAUTHORIZED;
    }

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.getCredential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    fbUser = await fbAuth.signInWithCredential(credential);

    assert(await fbUser.getIdToken() != null);

  }
  catch (exception)
  {
    loginMessage = "Error occurred logging in. Sorry...";
    fbAuth.signOut();
    googleSignIn.signOut();
    return UNAUTHORIZED;
  }

  return AUTHORIZED;

}

Future<int> createAccountGoogle() async {

  String errorMessage = "";

  try
  {
    if (tenantCode == null || tenantCode.isEmpty)
    {
      if (errorMessage.isEmpty)
        errorMessage = "Company ID can't be empty";
      else
        errorMessage = errorMessage + ", Company ID can't be empty";
    }

    if (errorMessage.length > 0)
    {
        loginMessage = errorMessage;
        fbAuth.signOut();
        googleSignIn.signOut();
        return UNAUTHORIZED;
    }

    final GoogleSignInAccount googleUser = await googleSignIn.signIn();
    if (googleUser == null)
    {
      loginMessage = "Google authorization failed.";
      fbAuth.signOut();
      googleSignIn.signOut();
      return UNAUTHORIZED;
    }

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.getCredential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    fbUser = await fbAuth.signInWithCredential(credential);
  }
  catch (exception)
  {
    loginMessage = "Google authorization failed: " + exception.toString();
    fbAuth.signOut();
    googleSignIn.signOut();
    return UNAUTHORIZED;
  }

  return AUTHORIZED;

}

void showPopupDialog<T>({ BuildContext context, Widget child }) {
  showDialog<T>(
    barrierDismissible: false,
    context: context,
    child: child,
  );
}

main() async {

  prefs = await SharedPreferences.getInstance();

  tenantCodeController = new TextEditingController(text: tenantCode);
  displayNameController = new TextEditingController(text: displayName);
  emailController = new TextEditingController(text: emailAddress);
  passwordController = new TextEditingController(text: password);
  verifyPasswordController = new TextEditingController(text: verifyPassword);

  subscription = new Connectivity().onConnectivityChanged.listen((ConnectivityResult result) async {
    if (result == ConnectivityResult.none) {
      routeStack.clear();
      runApp(new NoConnection());
    }
    else
    {
      if (await isInternetReachable())
        doLoginWork();
      else
      {
        routeStack.clear();
        runApp(new NoConnection());
      }
    }
  });

  var connectivityResult = await (new Connectivity().checkConnectivity());
  if (connectivityResult == ConnectivityResult.none) {
    routeStack.clear();
    runApp(new NoConnection());
  }
  else if (await isInternetReachable())
    doLoginWork();
  else
    runApp(new NoConnection());


}

void dispose() {
  // Always remember to cancel your subscriptions when you're done.
  subscription.cancel();
}

Future<bool> isInternetReachable() async
{
  try {
    final result = await InternetAddress.lookup('google.com');
    if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
      return true;
    }
    else
      return false;
  } on SocketException catch (_) {
    return false;
  }
}

Future doLoginWork() async
{
  runApp(splashScreen());

  int cachedAuthStatus = await handleCachedAuthorization();

  if (cachedAuthStatus  == UNAUTHORIZED) {
    loginMessage = "";
    prefs.remove("loggedInEmailAddress");
    prefs.remove("loggedInPassword");
    prefs.remove("tenantCode");
    runApp(new ArchChronosLogin());
    return;
  }

  // is valid tenant?
  tenant = await queryForTenant(prefs.getString("tenantCode"));
  if (tenant == null)
  {
    if (loginMessage.indexOf("Company payday") == -1) {
      loginMessage = "Error occured retrieving company. Please contact a system administrator.";
      fbAuth.signOut();
      googleSignIn.signOut();
    }
    runApp(new SignIn());
    return;
  }
  else
    assignTenant(tenant);

  // is user in tenant?

  // get the uid from the Firebase user
  String userKey = fbUser.uid;

  DocumentReference tenantUserRef = firestoreDB.collection("tenants").document(tenant.tenantID).collection("users").document(userKey);
  await tenantUserRef.get().then((DocumentSnapshot snapshot) {
    var tenantUser = snapshot.data;
    if (tenantUser != null)
    {
      archChronosUser = initArchChronosUserFromMap("", tenantUser);
    }
    else // if the user is not found, return
        {
      loginMessage = "We have encountered an error with the previously logged in user. Sign In again or, if you are a new user, click 'Create Account'";
      fbAuth.signOut();
      googleSignIn.signOut();
      runApp(new ArchChronosLogin());
      return;
    }

    timEntry.archChronosUser = archChronosUser;
    drawer.archChronosUser = archChronosUser;
    drawer.companyName = tenant.tenantName;
    reports.archChronosUser = archChronosUser;
    users.archChronosUser = archChronosUser;
    allConversations.archChronosUser = archChronosUser;

    runApp(new ArchChronos());

  });
}

Future<int> handleCachedAuthorization() async  {

  int authStatus = UNAUTHORIZED;

  fbUser = await fbAuth.currentUser();
  if (fbUser != null) {
    return AUTHORIZED;
  }

  final GoogleSignInAccount googleUser = await googleSignIn.signInSilently();
  if (googleUser == null)
  {
    String loggedInEmailAddress = prefs.getString("loggedInEmailAddress");
    String loggedInPassword = prefs.getString("loggedInPassword");
    if (loggedInEmailAddress != null && loggedInPassword != null) {
      try {
        fbUser = await fbAuth.signInWithEmailAndPassword(
            email: loggedInEmailAddress,
            password: loggedInPassword);
        authStatus = AUTHORIZED;
      }
      catch (exception)
      {
        authStatus = UNAUTHORIZED;
      }
    }
  }
  else {
    try {
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.getCredential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      fbUser = await fbAuth.signInWithCredential(credential);

      authStatus = AUTHORIZED;
    }
    catch(exception)
    {
      authStatus = UNAUTHORIZED;
    }
  }

  return authStatus;

}

Future handleLogout() async {

  fbAuth.signOut();
  googleSignIn.signOut();

  SharedPreferences prefs = await SharedPreferences.getInstance();
  prefs.remove("loggedInEmailAddress");
  prefs.remove("loggedInPassword");
  prefs.remove("tenantCode");

  emailAddress = "";
  password = "";
  verifyPassword = "";
  loginMessage = "";

  tenantCodeController.text = "";
  displayNameController.text = "";
  emailController.text = "";
  passwordController.text = "";
  verifyPasswordController.text = "";

  timEntry.weekViewEntity = new WeekViewEntity(new List<WeekDayEntity>());

  runApp(new ArchChronosLogin());
}

Future handleShowNewMessageDialog(BuildContext context) async {

  if (routeStack.length == 0 || (routeStack.length > 0 && routeStack.last != "allConversations")) {

    showPopupDialog<DialogActions>(
        context: context,
        child: new AlertDialog(
            title: new Text(
              "You have new unread messages.",
              style: new TextStyle(
                  fontSize: 14.0, color: Colors.black),
            ),
            actions: <Widget>[
              new FlatButton(
                  child: const Text('View'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    handleShowRoute(context, "allConversations", "");
                  }
              ),
              new FlatButton(
                  child: const Text('Close'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  }
              ),
            ]
        )
    );
  }
}

Future handleShowRoute(BuildContext context, String routeName, String caller) async {

  settings.popupRequired = false;

  reports.selectedPayday =new DateTime.fromMillisecondsSinceEpoch(tenant.paydayUtcMillisSinceEpoch, isUtc: true);

  // pop menu
  if (caller == "drawer")
    Navigator.pop(context);

  // don't re-show the route if the requested route is the same as the current route
  if (routeStack.length > 0 && routeStack.last == routeName)
    return;

  // pop everything on the routeStack
  for (var i = 0; i < routeStack.length; i++)
  {
    Navigator.pop(context);
  }
  routeStack.clear();

  if (routeName == "settings" && (tenant.paydayUtcMillisSinceEpoch == null || tenant.paydayUtcMillisSinceEpoch == 0)) {
    settings.popupRequired = true;
  }

  if (routeName == "reports") {
    if (tenant.paydayUtcMillisSinceEpoch == null || tenant.paydayUtcMillisSinceEpoch == 0) {
      settings.popupRequired = true;
      routeName = "settings";
    }
    else
    {
        if (archChronosUser.isTimeEntryRequired == false)
        {
          Navigator.pushReplacementNamed(context, routeName);
          return;
        }
    }
  }

  // push new Route - await and pop self on finish
  if ((archChronosUser.isTimeEntryRequired == true && routeName != "timeEntry") || (archChronosUser.isTimeEntryRequired == false && routeName != "reports")) {
    routeStack.add(routeName);
    await Navigator.pushNamed(context, routeName);
    if (routeStack.length > 0 && routeStack.last == routeName)
      routeStack.removeLast();
  }

}

Future handleShowLoginRoute(BuildContext context, String routeName,) async {
  await Navigator.pushNamed(context, routeName);
}

class ArchChronos extends StatefulWidget {
  ArchChronosState createState() => new ArchChronosState();
}

class ArchChronosState extends State<ArchChronos> {

  final String _title = "Arch Chronos";
  final WeekViewEntity _weekViewEntity = new WeekViewEntity(new List<WeekDayEntity>());

  @override
  void initState() {

    super.initState();

  }

  Widget build(BuildContext context) {

    var routes = <String, WidgetBuilder>  {

      Reports.routeName : (BuildContext context) => reports,

      Users.routeName : (BuildContext context) => users,

      AllConversations.routeName : (BuildContext context) => allConversations,

      Settings.routeName : (BuildContext context) => settings,

      ArchChronosHome.routeName : (BuildContext context) => timEntry,

    };

    timEntry.title = _title;
    timEntry.weekViewEntity = _weekViewEntity;

    Widget home;
    if (archChronosUser.isTimeEntryRequired == true)
      home = timEntry;
    else
      home = reports;

    return new MaterialApp(
      title: _title,
      home: home,
      routes: routes,
    );
  }

}

class ArchChronosLogin extends StatefulWidget
{
  ArchChronosLoginState createState() => new ArchChronosLoginState();
}

class ArchChronosLoginState extends State<ArchChronosLogin> {

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var routes = <String, WidgetBuilder>{

      SignUpOrLoginHome.routeName: (BuildContext context) => signUpOrLoginHome,

      SignIn.routeName: (BuildContext context) => signIn,

      CreateAccount.routeName: (BuildContext context) => createAccount,

    };

    Widget home = signUpOrLoginHome;

    return new MaterialApp(
      routes: routes,
      home: home,
    );
  }
}

class NoConnection extends StatefulWidget
{
  NoConnectionState createState() => new NoConnectionState();
}

class NoConnectionState extends State<NoConnection> {

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var routes = <String, WidgetBuilder>{

      NoConnectionHome.routeName: (BuildContext context) => noConnectionHome,

    };

    Widget home = noConnectionHome;

    return new MaterialApp(
      routes: routes,
      home: home,
    );
  }
}


class SignUpOrLoginHome extends StatefulWidget
{
  static String routeName = "signUpOrLoginHome";
  SignUpOrLoginHomeState createState() => new SignUpOrLoginHomeState();
}

class SignUpOrLoginHomeState extends State<SignUpOrLoginHome> {

  @override
  void initState() {

    super.initState();

  }

  @override
  Widget build(BuildContext context) {

    return new MaterialApp(
      home: new Scaffold(
        backgroundColor: Colors.white,
        body: new Center(
          child: new Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              new Expanded(
                child: new Container(
                  padding: const EdgeInsets.only(
                    top: 75.0,
                  ),
                  child: new ListView(
                    children: [
                      new Container(
                        child: new Text(
                          "Arch Chronos",
                          style: new TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20.0,
                            color: Colors.black,
                          ),
                        ),
                        alignment: Alignment.center,
                      ),
                      new Container(
                        child: new Text(
                          "Your corporate time keeping app.",
                          style: new TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16.0,
                            color: Colors.black,
                          ),
                        ),
                        alignment: Alignment.center,
                      ),
                      new Container(
                        padding: const EdgeInsets.only(
                          right: 20.0,
                          left: 20.0,
                          top: 10.0,
                        ),
                        child: new Center(

                          child: new Text(
                            loginMessage,
                            style: new TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.0,
                              color: Colors.red,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      new Container(
                        padding: const EdgeInsets.only(
                          right: 30.0,
                          left: 30.0,
                          top: 30.0,
                        ),
                        child: new RaisedButton(
                          child: new Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              new Text(
                                'Create Account',
                                style: new TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.0,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          color: Colors.blue,
                          onPressed: () async {

                            tenantCodeController.text = "";
                            displayNameController.text = "";
                            emailController.text = "";
                            passwordController.text = "";
                            verifyPasswordController.text = "";

                            loginMessage = "";

                            await Navigator.pushNamed(context, "createAccount");
                          },
                        ),
                      ),
                      new Container(
                        padding: const EdgeInsets.only(
                          right: 30.0,
                          left: 30.0,
                          top: 20.0,
                        ),
                        child: new RaisedButton(
                          child: new Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              new Text(
                                'Sign In',
                                style: new TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.0,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          color: Colors.blueGrey,
                          onPressed: () async {
                            loginMessage = "";
                            await Navigator.pushNamed(context, "signIn");
                          },
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
    );
  }
}

class NoConnectionHome extends StatefulWidget
{
  static String routeName = "noConnectionHome";
  NoConnectionHomeState createState() => new NoConnectionHomeState();
}

class NoConnectionHomeState extends State<NoConnectionHome> {

  @override
  void initState() {

    super.initState();

  }

  @override
  Widget build(BuildContext context) {

    return new MaterialApp(
      home: new Scaffold(
        backgroundColor: Colors.white,
        body: new Center(
          child: new Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              new Expanded(
                child: new Container(
                  padding: const EdgeInsets.only(
                    top: 150.0,
                  ),
                  child: new ListView(
                    children: [
                      new Container(
                        child: new Text(
                          "No Internet Connection ...",
                          style: new TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20.0,
                            color: Colors.black,
                          ),
                        ),
                        alignment: Alignment.center,
                      ),
                      new Container(
                        padding: const EdgeInsets.only(
                          top: 20.0,
                        ),
                        child: new Text(
                          "Archchronos will be disabled until a connection is detected.",
                          style: new TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.0,
                            color: Colors.black,
                          ),
                        ),
                        alignment: Alignment.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SignIn extends StatefulWidget
{
  static String routeName = "signIn";

  SignInState createState() => new SignInState();
}

class SignInState extends State<SignIn>
{

  @override
  void initState() {

    super.initState();

  }

  Future<int> processUsernamePasswordLogin() async
  {
    bool tenantExists = false;

    // basic field validation
    if (tenantCode == null || tenantCode.isEmpty)
    {
      loginMessage = "Invalid Or Missing Company Code";
      tenantCodeController.text = tenantCode;
      setState(() {

      });
      return UNAUTHORIZED;
    }

    if (emailAddress == null || emailAddress.isEmpty || password == null || password.isEmpty)
    {
      fbAuth.signOut();
      googleSignIn.signOut();
      loginMessage = "User not found in the selected company or credentials invalid. If you are a new user, return to the main screen and click 'Create Account'";
      setState(() {

      });
      return UNAUTHORIZED;
    }

    tenantCode = tenantCode.toLowerCase();

    // now check if the authenticated user is a valid user for the given tenantCode
    CollectionReference tenantRef = firestoreDB.collection("tenants");
    QuerySnapshot snapshot;
    snapshot = await tenantRef.where("tenantCode", isEqualTo: tenantCode).getDocuments();
    if (snapshot != null) {
      if (snapshot.documents.length > 0) {
        tenant = initTenantFromMap(snapshot.documents[0].data);
        tenant.tenantID = snapshot.documents[0].documentID;
        assignTenant(tenant);
        tenantExists = true;
      }
      else
        tenantExists = false;
    }

    if (!tenantExists)
    {
      loginMessage = "Invalid Or Missing Company Code [" + tenantCode + "]";
      tenantCodeController.text = tenantCode;
      setState(() {

      });
      return UNAUTHORIZED;
    }

    return await loginEmailAndPassword();
  }

  Future<int> processGoogleLogin() async
  {
    bool tenantExists = false;

    // basic field validation
    if (tenantCode == null || tenantCode.isEmpty)
    {
      loginMessage = "Invalid Or Missing Company Code [" + tenantCode + "]";
      tenantCodeController.text = tenantCode;
      setState(() {

      });
      return UNAUTHORIZED;
    }

    tenantCode = tenantCode.toLowerCase();

    // now check if the authenticated user is a valid user for the given tenantCode
    CollectionReference tenantRef = firestoreDB.collection("tenants");
    QuerySnapshot snapshot;
    snapshot = await tenantRef.where("tenantCode", isEqualTo: tenantCode).getDocuments();
    if (snapshot != null) {
      if (snapshot.documents.length > 0) {
        tenant = initTenantFromMap(snapshot.documents[0].data);
        assignTenant(tenant);
        tenantExists = true;
      }
      else
        tenantExists = false;
    }

    if (!tenantExists)
    {
      loginMessage = "Invalid Or Missing Company Code [" + tenantCode + "]";
      tenantCodeController.text = tenantCode;
      setState(() {

      });
      return UNAUTHORIZED;
    }

    return await loginGoogle();
  }

  Future handleAuthStatus(int authStatus) async
  {
    if (authStatus == UNAUTHORIZED)
    {
      fbAuth.signOut();
      googleSignIn.signOut();
      setState(() {
        if (loginMessage.isEmpty)
          loginMessage = "User unauthorized...";
      });
      return;
    }

    // is valid tenant?
    tenant = await queryForTenant(tenant.tenantCode);
    if (tenant == null)
    {
      if (loginMessage.indexOf("Company payday") == -1)
        loginMessage = "Error occured retrieving company. Please contact a system administrator.";
      setState(() {

      });
      return;
    }
    else
      assignTenant(tenant);

    // is user in tenant?

    // get the uid from the Firebase user
    String userKey = fbUser.uid;

    DocumentReference tenantUserRef = firestoreDB.collection("tenants").document(tenant.tenantID).collection("users").document(userKey);
    await tenantUserRef.get().then((DocumentSnapshot snapshot) {
      var tenantUser = snapshot.data;
      if (tenantUser != null)
      {
        archChronosUser = initArchChronosUserFromMap("", tenantUser);
      }
      else // if the user is not found, return
      {
        loginMessage = "User not found in the selected company or credentials invalid. If you are a new user, return to the main screen and click 'Create Account'";
        fbAuth.signOut();
        googleSignIn.signOut();
        setState(() {

        });
        return;
      }

      timEntry.archChronosUser = archChronosUser;
      drawer.archChronosUser = archChronosUser;
      drawer.companyName = tenant.tenantName;
      reports.archChronosUser = archChronosUser;
      users.archChronosUser = archChronosUser;
      allConversations.archChronosUser = archChronosUser;

      runApp(new ArchChronos());

    });
  }

  @override
  Widget build(BuildContext context) {

    return new MaterialApp(
      home:  new Scaffold(
          backgroundColor: Colors.white,
          body: new Center(
            child: new Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                new Expanded(
                    child: new Container(
                      padding: const EdgeInsets.only(
                        top: 75.0,
                      ),
                      child: new ListView(
                        children: [
                          new Container(
                            child: new Text(
                              "Arch Chronos",
                              style: new TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20.0,
                                color: Colors.black,
                              ),
                            ),
                            alignment: Alignment.center,
                          ),
                          new Container(
                            child: new Text(
                              "Login",
                              style: new TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16.0,
                                color: Colors.black,
                              ),
                            ),
                            alignment: Alignment.center,
                          ),
                          new Container(
                            padding: const EdgeInsets.only(
                              right: 20.0,
                              left: 20.0,
                              top: 10.0,
                            ),
                            child: new Center(

                              child: new Text(
                                loginMessage,
                                style: new TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.0,
                                  color: Colors.red,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          new Container(
                            padding: const EdgeInsets.only(
                              right: 30.0,
                              left: 30.0,
                              top: 5.0,
                              bottom: 30.0,
                            ),
                            child: new TextField(
                              maxLines: 1,
                              autocorrect: false,
                              onChanged: tenantCodeChanged,
                              controller: tenantCodeController,
                              decoration: new InputDecoration(
                                hintText: 'Enter Your Company ID',
                              ),
                            ),
                          ),
                          new Container(
                            padding: const EdgeInsets.only(
                              top: 0.0,
                            ),
                            child: new Text(
                              "----- Then -----",
                              style: new TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.0,
                                color: Colors.blue,
                              ),
                            ),
                            alignment: Alignment.center,
                          ),
                          new Container(
                            padding: const EdgeInsets.only(
                              right: 30.0,
                              left: 30.0,
                              top: 10.0,
                            ),
                            child: new TextField(
                              autocorrect: false,
                              maxLines: 1,
                              onChanged: emailAddressChanged,
                              controller: emailController,
                              decoration: new InputDecoration(
                                hintText: 'Enter Your Email Address',
                              ),
                            ),
                          ),
                          new Container(
                            padding: const EdgeInsets.only(
                              right: 30.0,
                              left: 30.0,
                            ),
                            child: new TextField(
                              maxLines: 1,
                              obscureText: true,
                              onChanged: passwordChanged,
                              controller: passwordController,
                              decoration: new InputDecoration(
                                hintText: 'Enter Your Password',
                              ),
                            ),
                          ),
                          new Container(
                            padding: const EdgeInsets.only(
                              right: 30.0,
                              left: 30.0,
                              top: 10.0,
                            ),
                            child: new RaisedButton(
                              child: new Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  new Text(
                                    'Sign In',
                                    style: new TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.0,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              color: Colors.blueGrey,
                              onPressed: () async {

                                routeStack.clear();
                                loginMessage = "";
                                int authStatus = await processUsernamePasswordLogin();
                                await handleAuthStatus(authStatus);

                              },
                            ),
                          ),
                          new Container(
                            padding: const EdgeInsets.only(
                              top: 20.0,
                              bottom: 20.0,
                            ),
                            child: new Text(
                              "--------------- Or ---------------",
                              style: new TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16.0,
                                color: Colors.blue,
                              ),
                            ),
                            alignment: Alignment.center,
                          ),
                          new Container(
                            padding: const EdgeInsets.only(
                              right: 30.0,
                              left: 30.0,
                              top: 0.0,
                            ),
                            child: new RaisedButton(
                              child: new Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  new Image(
                                      image: new AssetImage(
                                          'assets/google.jpg'
                                      ),
                                      height: 24.0,
                                      fit: BoxFit.scaleDown,
                                      alignment: FractionalOffset.center
                                  ),
                                  new Container(
                                    padding: const EdgeInsets.only(
                                      right: 10.0,
                                      left: 10.0,
                                    ),
                                    child:
                                    new Text("   ",),
                                  ),
                                  new Text(
                                    'Google Sign In',
                                    style: new TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.0,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              color: Colors.blue ,
                              onPressed: () async {

                                routeStack.clear();
                                loginMessage = "";
                                int authStatus = await processGoogleLogin();
                                await handleAuthStatus(authStatus);

                              },
                            ),
                          ),
                        ],
                      ),
                    )
                ),
              ],
            ),
          )
      ),
    );
  }
}

class CreateAccount extends StatefulWidget
{
  static String routeName = "createAccount";

  CreateAccountState createState() => new CreateAccountState();
}

class CreateAccountState extends State<CreateAccount> {

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      home: new Scaffold(
          backgroundColor: Colors.white,
          body: new Center(
            child: new Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                new Expanded(
                    child: new Container(
                      padding: const EdgeInsets.only(
                        top: 75.0,
                      ),
                      child: new ListView(
                        children: [
                          new Container(
                            child: new Text(
                              "Arch Chronos",
                              style: new TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20.0,
                                color: Colors.black,
                              ),
                            ),
                            alignment: Alignment.center,
                          ),
                          new Container(
                            child: new Text(
                              "Create An Account",
                              style: new TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16.0,
                                color: Colors.black,
                              ),
                            ),
                            alignment: Alignment.center,
                          ),
                          new Container(
                            padding: const EdgeInsets.only(
                              right: 10.0,
                              left: 10.0,
                              top: 10.0,
                            ),
                            child: new Center(

                              child: new Text(
                                loginMessage,
                                style: new TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.0,
                                  color: Colors.red,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          new Container(
                            padding: const EdgeInsets.only(
                              right: 30.0,
                              left: 30.0,
                              top: 5.0,
                              bottom: 30.0,
                            ),
                            child: new TextField(
                              maxLines: 1,
                              autocorrect: false,
                              onChanged: tenantCodeChanged,
                              controller: tenantCodeController,
                              decoration: new InputDecoration(
                                hintText: 'Enter Your Company ID',
                              ),
                            ),
                          ),
                          new Container(
                            padding: const EdgeInsets.only(
                              top: 0.0,
                            ),
                            child: new Text(
                              "----- Then Enter An Email And Password -----",
                              style: new TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.0,
                                color: Colors.blue,
                              ),
                            ),
                            alignment: Alignment.center,
                          ),
                          new Container(
                            padding: const EdgeInsets.only(
                              right: 30.0,
                              left: 30.0,
                              top: 10.0,
                            ),
                            child: new TextField(
                              autocorrect: false,
                              maxLines: 1,
                              onChanged: displayNameChanged,
                              controller: displayNameController,
                              decoration: new InputDecoration(
                                hintText: 'Enter Your Display Name',
                              ),
                            ),
                          ),
                          new Container(
                            padding: const EdgeInsets.only(
                              right: 30.0,
                              left: 30.0,
                              top: 10.0,
                            ),
                            child: new TextField(
                              autocorrect: false,
                              maxLines: 1,
                              onChanged: emailAddressChanged,
                              controller: emailController,
                              decoration: new InputDecoration(
                                hintText: 'Enter Your Email Address',
                              ),
                            ),
                          ),
                          new Container(
                            padding: const EdgeInsets.only(
                              right: 30.0,
                              left: 30.0,
                            ),
                            child: new TextField(
                              maxLines: 1,
                              obscureText: true,
                              onChanged: passwordChanged,
                              controller: passwordController,
                              decoration: new InputDecoration(
                                hintText: 'Enter Your Password',
                              ),
                            ),
                          ),
                          new Container(
                            padding: const EdgeInsets.only(
                              right: 30.0,
                              left: 30.0,
                            ),
                            child: new TextField(
                              maxLines: 1,
                              obscureText: true,
                              onChanged: verifyPasswordChanged,
                              controller: verifyPasswordController,
                              decoration: new InputDecoration(
                                hintText: 'Verify Your Password',
                              ),
                            ),
                          ),
                          new Container(
                            padding: const EdgeInsets.only(
                              right: 30.0,
                              left: 30.0,
                              top: 10.0,
                            ),
                            child: new RaisedButton(
                              child: new Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  new Text(
                                    'Create Account',
                                    style: new TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.0,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              color: Colors.blueGrey,
                              onPressed: () async {

                                routeStack.clear();
                                loginMessage = "";
                                int authStatus = await createAccountEmailAndPassword();
                                await handleAuthStatus(authStatus);

                              },
                            ),
                          ),
                          new Container(
                            padding: const EdgeInsets.only(
                              top: 20.0,
                              bottom: 20.0,
                            ),
                            child: new Text(
                              "--------------- Or ---------------",
                              style: new TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16.0,
                                color: Colors.blue,
                              ),
                            ),
                            alignment: Alignment.center,
                          ),
                          new Container(
                            padding: const EdgeInsets.only(
                              right: 30.0,
                              left: 30.0,
                              top: 0.0,
                            ),
                            child: new RaisedButton(
                              child: new Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  new Image(
                                      image: new AssetImage(
                                          'assets/google.jpg'
                                      ),
                                      height: 24.0,
                                      fit: BoxFit.scaleDown,
                                      alignment: FractionalOffset.center
                                  ),
                                  new Container(
                                    padding: const EdgeInsets.only(
                                      right: 10.0,
                                      left: 10.0,
                                    ),
                                    child:
                                    new Text("   ",),
                                  ),
                                  new Text(
                                    'Use Google',
                                    style: new TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.0,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              color: Colors.blue,
                              onPressed: () async {

                                routeStack.clear();
                                loginMessage = "";
                                int authStatus = await createAccountGoogle();
                                await handleAuthStatus(authStatus);

                              },
                            ),
                          ),
                        ],
                      ),
                    )
                ),
              ],
            ),
          )
      ),
    );
  }

  Future handleAuthStatus(int authStatus) async
  {
    if (authStatus == UNAUTHORIZED)
    {
      fbAuth.signOut();
      googleSignIn.signOut();
      loginMessage = "User is not authorized. Perhaps you need to create an account?";
      setState(() {

      });
      return;
    }

    // is valid tenant?
    tenant = await queryForTenant(tenantCode);
    if (tenant == null)
    {
      if (loginMessage.indexOf("Company payday") == -1)
        loginMessage = "Error occured retrieving company. Please contact a system administrator.";
      setState(() {

      });
      return;
    }
    else
      assignTenant(tenant);

    // check to see if there is already a user in the tenant with associated with the google user. If so, skip user creation
    DocumentReference userRef = firestoreDB.collection("tenants").document(tenant.tenantID).collection("users").document(fbUser.uid);
    await userRef.get().then((DocumentSnapshot snapshot) {
      var tenantUser = snapshot.data;
      if (tenantUser == null)
      {
        List<UserInfo> userInfoList = fbUser.providerData;
        UserInfo ui = userInfoList[1];

        if (ui.providerId.indexOf("google") > -1) {
          archChronosUser = new ArchChronosUser(ui.displayName);
          archChronosUser.emailAddress = ui.email;
        }
        else {
          archChronosUser = new ArchChronosUser(displayName);
          archChronosUser.emailAddress = emailAddress;
          archChronosUser.password = password;
        }

        archChronosUser.tenantId = tenant.tenantID;
        archChronosUser.isTimeEntryRequired = true;
        archChronosUser.isVacationAccumulated = true;
        archChronosUser.isEnabled = true;
        archChronosUser.isAdmin = false;
        archChronosUser.bankedTimeBalance = 0.0;
        archChronosUser.vacationBalance = 0.0;
        archChronosUser.vacationRate = 0.0;
        archChronosUser.messagingToken = "";

        archChronosUser.providerId = ui.providerId;
        archChronosUser.uid = fbUser.uid;

        firestoreDB.collection('tenants').document(archChronosUser.tenantId).collection("users").document(archChronosUser.uid).setData(archChronosUser.toJson());
      }
      else
        archChronosUser = initArchChronosUserFromMap("", tenantUser);

    });

    // store the user token in local storage
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("loggedInEmailAddress", emailAddress);
    prefs.setString("loggedInPassword", password);
    prefs.setString("tenantCode", tenant.tenantCode);

    timEntry.archChronosUser = archChronosUser;
    drawer.archChronosUser = archChronosUser;
    drawer.companyName = tenant.tenantName;
    reports.archChronosUser = archChronosUser;
    users.archChronosUser = archChronosUser;
    allConversations.archChronosUser = archChronosUser;

    runApp(new ArchChronos());

  }
}
