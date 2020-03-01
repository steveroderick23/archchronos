import 'dart:async';
import 'dart:core';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:email_validator/email_validator.dart';
import 'archChronosDrawer.dart';
import 'common.dart';
import 'messagingUtil.dart';

enum DialogActions {
  cancel,
  discard,
  disagree,
  agree,
}

class Reports extends StatefulWidget {

  static String routeName = "reports";

  Reports({Key key,
    this.tenant,
    this.archChronosDrawer,
    this.archChronosUser,
    this.onChangeRouteTapped,
    this.onShowNewMessageDialog,
    this.passedDate,})
      : super(key: key);

  ArchChronosDrawer archChronosDrawer;
  final ReportEntity reportEntity = new ReportEntity(new List<WeekDayEntity>(), new List<UserReportLine>());
  ArchChronosUser archChronosUser;
  final BuildContextCallback onChangeRouteTapped;
  final SimpleContextCallback onShowNewMessageDialog;
  final DateTime passedDate;
  Tenant tenant;
  DateTime selectedPayday;
  bool redirectToAllConversations = false;

  @override
  ReportsState createState() => new ReportsState(archChronosDrawer, reportEntity, passedDate, archChronosUser, onChangeRouteTapped, onShowNewMessageDialog);
}

class ReportsState extends State<Reports> {

  ReportsState(this._archChronosDrawer, this._reportEntity, this._passedDate, this._archChronosUser, this._onChangeRouteTapped, this._onShowNewMessageDialog);

  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  TextEditingController emailAddressController;

  String dateRangeString = "";
  String radioValue = "";
  String selectedEmployee = "";
  String emailAddress = "";
  String prefsEmailAddress = "";

  final ReportEntity _reportEntity;
  final BuildContextCallback _onChangeRouteTapped;
  final SimpleContextCallback _onShowNewMessageDialog;
  ArchChronosDrawer _archChronosDrawer;
  ArchChronosUser _archChronosUser;
  DateTime _passedDate;
  double delta = 0.0;
  int _rowsPerPage = PaginatedDataTable.defaultRowsPerPage;

  Widget loadingIndicator = new Container();
  bool _load = false;

  var formatter = new DateFormat('EEE MMM dd');

  List<WeekDayEntity> wdeList = new List<WeekDayEntity>();
  List<ArchChronosUser> archChronosUsers = new List<ArchChronosUser>();

  @override
  void dispose() {
    super.dispose();

    _reportEntity.userReportLines.clear();

  }

  @override
  initState() {
    super.initState();

    if (_archChronosUser.isTimeEntryRequired == false) {

      configureMessaging(
          context,
          _archChronosUser,
          widget.tenant.tenantCode,
          _onChangeRouteTapped,
          "reports",
          widget,
          null);

      initNewMessageListener();
    }

    radioValue = "Pay Period";
    if (_passedDate != null)
      _reportEntity.date = _passedDate;
    else
      _reportEntity.date = getCurrentDaySetToMidnightInUTC();

    wdeList.add(new WeekDayEntity(new DateTime.now()));

    selectedEmployee = "All";
    emailAddressController = new TextEditingController(text: emailAddress);

    if (widget.selectedPayday == null)
    {
      _onChangeRouteTapped(context, "settings", "reports");
      return;
    }

    if (_reportEntity.date != null) {

      Future.delayed(Duration.zero,() =>queryEmployeeTime(widget.tenant.tenantCode, _reportEntity, radioValue, handleReportDataLoaded, _archChronosUser, selectedEmployee, archChronosUsers));

    }

  }

  Future initNewMessageListener() async
  {
    CollectionReference messagesRef  = firestoreDB.collection('tenants')
        .document(widget.tenant.tenantCode).collection("users").document(widget.archChronosUser.uid)
        .collection("messages");

    Stream<QuerySnapshot> snapshot = messagesRef.snapshots();
    snapshot.listen(showMessageReceivedDialog);
  }

  void showMessageReceivedDialog(QuerySnapshot event) {

    // don't do anything if the user is on any of the messenger screens

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

  queryEmployeeTime(String tenantCode, ReportEntity reportEntity, String timeSpan, EmptyArgCallback onReportDataLoaded, ArchChronosUser user, String selectedEmployee, List<ArchChronosUser> archChronosUsers) async
  {
    showGeneratingReportsDialog();

    await queryForEmployeeTime(widget.tenant, _reportEntity, radioValue, handleReportDataLoaded, _archChronosUser, selectedEmployee, archChronosUsers);

    Navigator.of(context).pop();

    if (widget.redirectToAllConversations == true)
    {
      widget.redirectToAllConversations = false;
      onChangeRouteTapped(messengerContext, "allConversations", "");
    }
  }

  setDateRangeString()
  {
    if (radioValue == "Day")
      dateRangeString = "Time For " + new DateFormat('EEE MMM d').format(_reportEntity.date);
    else if (radioValue == "Week")
      dateRangeString = "Time For " + getWeekSpanString(_reportEntity.date);
    else if (radioValue == "Pay Period") {
      DateTime payPeriodstart = calculatePayPeriodStart(_reportEntity.date, _reportEntity.selectedPayday);
      dateRangeString = "Time For Pay Period Of " + new DateFormat('MMM d').format(payPeriodstart) +
          " - " + new DateFormat('MMM d').format(payPeriodstart.add(new Duration(days: 13)));
    }
    else
    {
      dateRangeString = "Time For " + new DateFormat('yyyy').format(_reportEntity.date);
    }
  }

  void handleReportDataLoaded() {
    setState(() {
      setDateRangeString();
    });
  }

  void showGeneratingReportsDialog()
  {
    showPopupDialog<DialogActions>(
      context: context,
      child: new AlertDialog(
        title: new Container(
          child: new Center(
            child: new Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                new Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    new Text(
                      "Regenerating Reports ...",
                      style: new TextStyle(fontSize: 14.0),
                    ),
                  ],
                ),
                new Row(
                  children: <Widget>[
                    new Text(
                      " ",
                    ),
                  ],
                ),
                new Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    new CircularProgressIndicator(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future handleEmployeeChanged(String newValue) async {
    selectedEmployee = newValue;

    showGeneratingReportsDialog();

    await queryForEmployeeTime(widget.tenant, _reportEntity, radioValue, handleReportDataLoaded, _archChronosUser, selectedEmployee, archChronosUsers);

    Navigator.of(context).pop();
  }

  Future handleReportDateChanged(DateTime date) async {
    _reportEntity.date = date;

    showGeneratingReportsDialog();

    await queryForEmployeeTime(widget.tenant, _reportEntity, radioValue, handleReportDataLoaded, _archChronosUser, selectedEmployee, archChronosUsers);

    Navigator.of(context).pop();
  }

  Future handleRadioValueChanged(String newValue) async {
    radioValue = newValue;

    showGeneratingReportsDialog();

    await queryForEmployeeTime(widget.tenant, _reportEntity, radioValue, handleReportDataLoaded, _archChronosUser, selectedEmployee, archChronosUsers);

    Navigator.of(context).pop();
  }

  Future handleMoveBackAWeek() async {

    if (radioValue == "Day")
      _reportEntity.date = _reportEntity.date.subtract(new Duration(days: 1));
    else if (radioValue == "Week")
      _reportEntity.date = _reportEntity.date.subtract(new Duration(days: 7));
    else if (radioValue == "Pay Period")
      _reportEntity.date = _reportEntity.date.subtract(new Duration(days: 14));
    else if (radioValue == "YTD")
      _reportEntity.date = new DateTime.utc(_reportEntity.date.year - 1, _reportEntity.date.month, _reportEntity.date.day, _reportEntity.date.hour, _reportEntity.date.minute, _reportEntity.date.second);

    showGeneratingReportsDialog();

    await queryForEmployeeTime(widget.tenant, _reportEntity, radioValue, handleReportDataLoaded, _archChronosUser, selectedEmployee, archChronosUsers);

    Navigator.of(context).pop();
  }

  Future handleMoveAheadAWeek() async {

    if (radioValue == "Day")
      _reportEntity.date = _reportEntity.date.add(new Duration(days: 1));
    else if (radioValue == "Week")
      _reportEntity.date = _reportEntity.date.add(new Duration(days: 7));
    else if (radioValue == "Pay Period")
      _reportEntity.date = _reportEntity.date.add(new Duration(days: 14));
    else if (radioValue == "YTD")
      _reportEntity.date = new DateTime.utc(_reportEntity.date.year + 1, _reportEntity.date.month, _reportEntity.date.day, _reportEntity.date.hour, _reportEntity.date.minute, _reportEntity.date.second);

    showGeneratingReportsDialog();

    await queryForEmployeeTime(widget.tenant, _reportEntity, radioValue, handleReportDataLoaded, _archChronosUser, selectedEmployee, archChronosUsers);

    Navigator.of(context).pop();
  }

  Future handleTodayClicked() async {
    _reportEntity.date = getCurrentDaySetToMidnightInUTC();

    showGeneratingReportsDialog();

    await queryForEmployeeTime(widget.tenant, _reportEntity, radioValue, handleReportDataLoaded, _archChronosUser, selectedEmployee, archChronosUsers);

    Navigator.of(context).pop();
  }


  void showPopupDialog<T>({ BuildContext context, Widget child }) {
    showDialog<T>(
      barrierDismissible: false,
      context: context,
      child: child,
    );
  }

  Future handleEmailPdfClicked() async{

    // send the request
    int startDateEpoch = determineStartDateEpoch(_reportEntity.date, radioValue, _reportEntity.selectedPayday);
    int endDateEpoch = determineEndDateEpoch(_reportEntity.date, startDateEpoch, radioValue);
    String uids = selectedEmployee;
    if (uids != "All") {
      for (ArchChronosUser archChronosUser in archChronosUsers)
      {
        if (archChronosUser.displayName == selectedEmployee)
        {
          uids = archChronosUser.uid;
          break;
        }
      }
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefsEmailAddress = prefs.getString('defaultReportEmailAddress');
    if (prefsEmailAddress == null)
      prefsEmailAddress = "";

    String reportType = radioValue;
    emailAddressController.text = prefsEmailAddress;
    emailAddress = prefsEmailAddress;

    // alert the user the request has been sent
    showPopupDialog<DialogActions>(
      context: context,
      child: new AlertDialog(
        title: new Text(
          "Confirm or change the email address you would like the report sent to:",
          style: new TextStyle(fontSize: 14.0, color: Colors.black),
        ),
        content: new Row(
          children: [
            new Container(
              padding: const EdgeInsets.only(
                left: 12.0,
              ),
              width: 250.0,
              child: new TextField(
                controller: emailAddressController,
                decoration: new InputDecoration(
                  hintText: 'Enter Email',
                ),
                style: new TextStyle(fontSize: 10.0, color: Colors.black),
              ),
            ),
          ],

        ),
        actions: <Widget>[
          new FlatButton(
              child: const Text('OK'),
              onPressed: () async {

                if (emailAddressController.text == null || emailAddressController.text.isEmpty || !EmailValidator.validate(emailAddressController.text))
                {
                  showPopupDialog<DialogActions>(
                      context: context,
                      child: new AlertDialog(
                          title: new Text(
                            "Please provide a valid email address.",
                            style: new TextStyle(
                                fontSize: 14.0, color: Colors.red),
                          ),
                          actions: <Widget>[
                            new FlatButton(
                                child: const Text('OK'),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                }
                            ),
                          ]
                      )
                  );
                }
                else {

                  Navigator.of(context).pop();

                  showPopupDialog<DialogActions>(
                    context: context,
                    child: new AlertDialog(
                      title: new Container(
                        child: new Center(
                          child: new Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              new Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  new Text(
                                    "Sending Report ...",
                                    style: new TextStyle(fontSize: 14.0),
                                  ),
                                ],
                              ),
                              new Row(
                                children: <Widget>[
                                  new Text(
                                    " ",
                                  ),
                                ],
                              ),
                              new Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  new CircularProgressIndicator(),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );

                  var httpClient = new HttpClient();
                  var uri = new Uri(scheme: "http",
                      host: "springbreezesolutions.org",
                      path: "sbsservices/emailReportPdf",
                      port: 80,
                      queryParameters:
                      {
                        'startDate': startDateEpoch.toString(),
                        'endDate': endDateEpoch.toString(),
                        'tenantCode': widget.tenant.tenantCode,
                        'uids': uids,
                        'reportType': reportType,
                        'emailAddress': emailAddressController.text,
                        'timeSpanString': dateRangeString
                      });

                  try {
                    var request = await httpClient.getUrl(uri);
                    await request.close();

                    Navigator.of(context).pop();
                  }
                  catch (exception) {
                    Navigator.of(context).pop();

                    print(exception);
                    emailAddressController.text = "";
                    showPopupDialog<DialogActions>(
                        context: context,
                        child: new AlertDialog(
                            title: new Text(
                              "There was an error emailing your report. Please try again.",
                              style: new TextStyle(
                                  fontSize: 14.0, color: Colors.red),
                            ),
                            actions: <Widget>[
                              new FlatButton(
                                  child: const Text('OK'),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  }
                              ),
                            ]
                        )
                    );

                    return;
                  }

                  emailAddressController.text = "";
                  showPopupDialog<DialogActions>(
                      context: context,
                      child: new AlertDialog(
                          title: new Text(
                            "Your report request has been sent. You should receive an email containing a PDF of the requested report shortly.",
                            style: new TextStyle(
                                fontSize: 14.0, color: Colors.black),
                          ),
                          actions: <Widget>[
                            new FlatButton(
                                child: const Text('OK'),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                }
                            ),
                          ]
                      )
                  );
                }
                return;
              }
          ),
          new FlatButton(
              child: const Text('Cancel'),
              onPressed: () {
                emailAddressController.text = "";
                Navigator.of(context).pop(); // Pops the confirmation dialog but not the page.
              }
          ),
        ]
        ),

    );
    return;
  }

  Widget build(BuildContext context) {

    List<Widget> actions = new List<Widget>();
    actions.add(new IconButton(
        icon:  new ImageIcon(new AssetImage('assets/icons8-calendar-' + new DateTime.now().day.toString() + '-50.png')),
        onPressed: handleTodayClicked));

    if (radioValue != "Day") {
      actions.add(new IconButton(
          icon: new ImageIcon(new AssetImage('assets/emailPDF.png')),
          onPressed: handleEmailPdfClicked));
    }

    return new Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: _archChronosDrawer,
      appBar: new AppBar(
        title: new Text("Time Reports"),
        actions: actions,
      ),
      body: buildReports()
    );
  }

  Widget buildIndividualEmployeeReportBlock(UserReportLine userReportLine)
  {

    List<Row> listRows = new List<Row>();

    Row spacerRow = new Row(

      children: <Widget>[
        new Text(
          " ",
        ),
      ],
    );

    Row bankedTimeBalanceHeaderRow = new Row(

      children: <Widget>[
        new Container(
          padding: const EdgeInsets.only(
            left: 15.0,
            top: 2.0,
            bottom: 2.0,
          ),
          child: new Text(
            "Banked Time Balance: " + userReportLine.user.bankedTimeBalance.toStringAsFixed(2) + " hrs",
          ),
        ),
      ],
    );

    Row vacationBalanceHeaderRow = new Row(

      children: <Widget>[
        new Container(
          padding: const EdgeInsets.only(
            left: 15.0,
            top: 2.0,
            bottom: 2.0,
          ),
          child: new Text(
            "Vacation Balance: " + userReportLine.user.vacationBalance.toStringAsFixed(2) + " hrs",
          ),
        ),
      ],
    );

    listRows.add(bankedTimeBalanceHeaderRow);

    if (userReportLine.user.isVacationAccumulated)
      listRows.add(vacationBalanceHeaderRow);

    return new Column(

      children: listRows,

    );

  }

  Widget buildGridView(UserReportLine userReportLine)
  {

    return new GridView.count(
      // Create a grid with 2 columns. If you change the scrollDirection to
      // horizontal, this would produce 2 rows.
        crossAxisCount: 9,
        childAspectRatio: 3.0,
        shrinkWrap: true,
        // Generate 18 Widgets that display their index in the List
        children: [

          Center(
            child: Text(
              'RT',
              style: new TextStyle(
                fontSize: 10.0,
              ),
            ),
          ),
          Center(
            child: Text(
              'OT',
              style: new TextStyle(
                fontSize: 10.0,
              ),
            ),
          ),
          Center(
            child: Text(
              'SHW',
              style: new TextStyle(
                fontSize: 10.0,
              ),
            ),
          ),
          Center(
            child: Text(
              'TB',
              style: new TextStyle(
                fontSize: 10.0,
              ),
            ),
          ),
          Center(
            child: Text(
              'VT',
              style: new TextStyle(
                fontSize: 10.0,
              ),
            ),
          ),
          Center(
            child: Text(
              'ST',
              style: new TextStyle(
                fontSize: 10.0,
              ),
            ),
          ),
          Center(
            child: Text(
              'SH',
              style: new TextStyle(
                fontSize: 10.0,
              ),
            ),
          ),
          Center(
            child: Text(
              'TFB',
              style: new TextStyle(
                fontSize: 10.0,
              ),
            ),
          ),
          Center(
            child: Text(
              'UTO',
              style: new TextStyle(
                fontSize: 10.0,
              ),
            ),
          ),
          Center(
            child: Text(
              '0.0',
              style: new TextStyle(
                fontSize: 10.0,
              ),
            ),
          ),
          Center(
            child: Text(
              '0.0',
              style: new TextStyle(
                fontSize: 10.0,
              ),
            ),
          ),
          Center(
            child: Text(
              '0.0',
              style: new TextStyle(
                fontSize: 10.0,
              ),
            ),
          ),
          Center(
            child: Text(
              '0.0',
              style: new TextStyle(
                fontSize: 10.0,
              ),
            ),
          ),
          Center(
            child: Text(
              '0.0',
              style: new TextStyle(
                fontSize: 10.0,
              ),
            ),
          ),
          Center(
            child: Text(
              '0.0',
              style: new TextStyle(
                fontSize: 10.0,
              ),
            ),
          ),
          Center(
            child: Text(
              '0.0',
              style: new TextStyle(
                fontSize: 10.0,
              ),
            ),
          ),
          Center(
            child: Text(
              '0.0',
              style: new TextStyle(
                fontSize: 10.0,
              ),
            ),
          ),
          Center(
            child: Text(
              '0.0',
              style: new TextStyle(
                fontSize: 10.0,
              ),
            ),
          ),
        ]
    );
  }

  Widget buildReports()
  {
    ListView reportsView = new ListView(
        children: [
          new Row (
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                new Container(
                  padding: const EdgeInsets.only(
                    right: 3.0,
                    left: 7.0,
                  ),
                  child: new IconButton(
                    icon: new Icon(Icons.arrow_left, color: Colors.blue, size: 32.0),
                    onPressed: handleMoveBackAWeek,
                  ),
                ),
                new Expanded(
                  child: new Container(
                    alignment: FractionalOffset.center,
                    child: new DatePicker(
                      selectedDate: _reportEntity.date,
                      selectDate: (DateTime date) {
                        handleReportDateChanged(date);
                      },
                    ),
                  ),
                ),
                new Container(
                  padding: const EdgeInsets.only(
                    right: 3.0,
                    left: 7.0,
                  ),
                  child: new IconButton(
                    icon: new Icon(Icons.arrow_right, color: Colors.blue, size: 32.0),
                    onPressed: handleMoveAheadAWeek,
                  ),
                ),
              ]
          ),
          buildUserSelectionWidget(_archChronosUser),
          new Row(
            children: [
              new Container(
                child: new Icon(
                  Icons.date_range,
                  color: Colors.black,
                ),
                padding: EdgeInsets.only(left: 15.0, top: 0.0, bottom: 0.0),
              ),
              new Container(
                child: new Container(
                  child: new Row(
                      children: [
                        new Radio<String>(
                          value: "Day",
                          groupValue: radioValue,
                          onChanged: handleRadioValueChanged,
                        ),
                        new Text("Day",
                          style: new TextStyle(
                            fontSize: 10.0,
                          ),
                        ),
                        new Radio<String>(
                          value: "Week",
                          groupValue: radioValue,
                          onChanged: handleRadioValueChanged,
                        ),
                        new Text("Week",
                          style: new TextStyle(
                            fontSize: 10.0,
                          ),
                        ),
                        new Radio<String>(
                          value: "Pay Period",
                          groupValue: radioValue,
                          onChanged: handleRadioValueChanged,
                        ),
                        new Text("Pay Period",
                          style: new TextStyle(
                            fontSize: 10.0,
                          ),
                        ),
                        new Radio<String>(
                          value: "YTD",
                          groupValue: radioValue,
                          onChanged: handleRadioValueChanged,
                        ),
                        new Text("YTD",
                          style: new TextStyle(
                            fontSize: 10.0,
                          ),
                        ),
                      ]
                  ),
                ),
                padding: EdgeInsets.only(left: 15.0, top: 10.0, bottom: 10.0),
              ),
            ],

          ),

          buildDateRangeRow(),
          new Padding(
            padding: new EdgeInsets.all(10.0),
            child: new ExpansionPanelList(
              expansionCallback: (int index, bool isExpanded) {
                setState(() {
                  _reportEntity.userReportLines[index].isExpanded = !isExpanded;
                });
              },
              children: _reportEntity.userReportLines.map((UserReportLine item) {
                ReportLineDataSource _reportLineDataSource = new ReportLineDataSource(new List.from([item]));
                return new ExpansionPanel(
                    isExpanded: item.isExpanded,
                    headerBuilder: buildHeader(item),
                    body: new Column(
                        children: [
                          buildIndividualEmployeeReportBlock(item),
                          buildTimeEntries(item),
                        ]
                    ),
                );
              }).toList()
            ),
          ),

        ]
      );

    return reportsView;
  }

  Widget buildTimeEntries(UserReportLine userReportLine)
  {
    List<Row> listRows = new List<Row>();

    Row spacerRow = new Row(

      children: <Widget>[
        new Text(
          " ",
        ),
      ],
    );

    if (userReportLine.weekViewEntity.weekDayEntities.length > 0) {

      Row timeEntryHeaderRow = new Row(

        children: <Widget>[
          new Container(
            padding: const EdgeInsets.only(
              left: 15.0,
              top: 2.0,
              bottom: 2.0,
            ),
            child: new Text(
              "Time Entries ",
              style: new TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      );

      listRows.add(spacerRow);

      listRows.add(timeEntryHeaderRow);

      listRows.add(spacerRow);

      for (var weekDayEntity in userReportLine.weekViewEntity.weekDayEntities) {
        Row row = new Row(

          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            new Container(
              padding: const EdgeInsets.only(
                left: 20.0,
                top: 2.0,
                bottom: 2.0,
              ),
              child: buildTimeEntry(weekDayEntity),
            ),
          ],
        );
        listRows.add(row);
      }

      listRows.add(spacerRow);

      Row timeTotalsHeaderRow = new Row(

        children: <Widget>[
          new Container(
            padding: const EdgeInsets.only(
              left: 15.0,
              top: 2.0,
              bottom: 2.0,
            ),
            child: new Text(
              "Totals",
              style: new TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      );

      listRows.add(timeTotalsHeaderRow);

      listRows.add(spacerRow);
      listRows.add(buildReporLineContent(userReportLine));
      listRows.add(spacerRow);
      listRows.add(buildReporLineTotals(userReportLine));
      listRows.add(spacerRow);
    }
    else
    {
      Row timeEntryHeaderRow = new Row(

        children: <Widget>[
          new Container(
            padding: const EdgeInsets.only(
              left: 15.0,
              top: 2.0,
              bottom: 2.0,
            ),
            child: new Text(
              "No Time Entries For Selected Time Period... ",
              style: new TextStyle(
                fontWeight: FontWeight.normal,
                color: Colors.black,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      );

      listRows.add(spacerRow);

      listRows.add(timeEntryHeaderRow);

      listRows.add(spacerRow);
    }

    return new Column(

      children: listRows,

    );
  }

  Widget buildUserSelectionWidget(ArchChronosUser user)
  {
    Widget userSelectionWidget;
    if (user.isAdmin) {
      userSelectionWidget = new Row(
        children: [
         new Container(
           child: new Icon(
             Icons.person,
             color: Colors.black,
           ),
           padding: EdgeInsets.only(left: 15.0, top: 10.0, bottom: 0.0),
         ),
         new Container(
           child: buildUserDropdown(),
           padding: EdgeInsets.only(left: 25.0, top: 10.0, bottom: 0.0),
         ),
        ],

      );

    }
    else
    {
      userSelectionWidget = new Row (
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            new Text(""),
          ]
      );
    }

    return userSelectionWidget;
  }

  Widget buildUserDropdown() {

    CollectionReference usersRef = firestoreDB.collection("tenants").
      document(widget.tenant.tenantCode).collection("users");

    Stream<QuerySnapshot> usersSnapshot = usersRef.where("isTimeEntryRequired", isEqualTo: true).snapshots();
    return new StreamBuilder<QuerySnapshot>(
      stream: usersSnapshot,
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (!snapshot.hasData) return const Text('Loading...');
        return new DropdownButton<String>(
            value: selectedEmployee,
            onChanged: handleEmployeeChanged,
            items: buildMenuItems(snapshot),
        );
      },
    );
  }

  List<DropdownMenuItem<String>> buildMenuItems(AsyncSnapshot<QuerySnapshot> snapshot) {

    List<DropdownMenuItem<String>> menuItems = new List<DropdownMenuItem<String>>();

    menuItems.add(new DropdownMenuItem<String>( value: "All", child: new Text("All"),));

    menuItems.addAll(snapshot.data.documents.map((DocumentSnapshot document) {
        String displayName = document.data["displayName"];
        if (displayName == null)
          displayName = document.data["emailAddress"];
        return new DropdownMenuItem<String>( value: displayName, child: new Text(displayName), );
      }).toList()
    );

    return menuItems;
  }

  Iterable<Row> buildUserReportPage(UserReportLine userReportLine) {

    List<Row> listRows = new List<Row>();

    Row headerRow = new Row(
        children: <Widget>[
          new Text(
            userReportLine.user.displayName,
            style: new TextStyle(
              fontWeight: FontWeight.normal,
              fontSize: 14.0,
              color: Colors.blue,
            ),
          ),
        ]
    );

    Row spacerRow = new Row(

      children: <Widget>[
        new Text(
          " ",
        ),
      ],
    );

    Row bankedTimeBalanceHeaderRow = new Row(

      children: <Widget>[
        new Container(
          padding: const EdgeInsets.only(
            left: 15.0,
            top: 2.0,
            bottom: 2.0,
          ),
          child: new Text(
            "Banked Time Balance: " + userReportLine.user.bankedTimeBalance.toStringAsFixed(2) + " hrs",
          ),
        ),
      ],
    );

    Row vacationBalanceHeaderRow = new Row(

      children: <Widget>[
        new Container(
          padding: const EdgeInsets.only(
            left: 15.0,
            top: 2.0,
            bottom: 2.0,
          ),
          child: new Text(
            "Vacation Balance: " + userReportLine.user.vacationBalance.toStringAsFixed(2) + " hrs",
          ),
        ),
      ],
    );

    listRows.add(spacerRow);
    listRows.add(headerRow);
    listRows.add(spacerRow);
    listRows.add(bankedTimeBalanceHeaderRow);

    if (userReportLine.user.isVacationAccumulated)
      listRows.add(vacationBalanceHeaderRow);

    if (userReportLine.weekViewEntity.weekDayEntities.length > 0) {

      Row timeEntryHeaderRow = new Row(

        children: <Widget>[
          new Container(
            padding: const EdgeInsets.only(
              left: 15.0,
              top: 2.0,
              bottom: 2.0,
            ),
            child: new Text(
              "Time Entries ",
              style: new TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      );

      listRows.add(spacerRow);

      listRows.add(timeEntryHeaderRow);

      listRows.add(spacerRow);

      for (var weekDayEntity in userReportLine.weekViewEntity.weekDayEntities) {
        Row row = new Row(

          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            new Container(
              padding: const EdgeInsets.only(
                left: 20.0,
                top: 2.0,
                bottom: 2.0,
              ),
              child: buildTimeEntry(weekDayEntity),
            ),
          ],
        );
        listRows.add(row);
      }

      listRows.add(spacerRow);

      Row timeTotalsHeaderRow = new Row(

        children: <Widget>[
          new Container(
            padding: const EdgeInsets.only(
              left: 15.0,
              top: 2.0,
              bottom: 2.0,
            ),
            child: new Text(
              "Totals",
              style: new TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      );

      listRows.add(timeTotalsHeaderRow);

      listRows.add(spacerRow);
      listRows.add(buildReporLineContent(userReportLine));
      listRows.add(spacerRow);
      listRows.add(buildReporLineTotals(userReportLine));
      listRows.add(spacerRow);
    }
    else
    {
      Row timeEntryHeaderRow = new Row(

        children: <Widget>[
          new Container(
            padding: const EdgeInsets.only(
              left: 15.0,
              top: 2.0,
              bottom: 2.0,
            ),
            child: new Text(
              "No Time Entries For Selected Time Period... ",
              style: new TextStyle(
                fontWeight: FontWeight.normal,
                color: Colors.black,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      );

      listRows.add(spacerRow);

      listRows.add(timeEntryHeaderRow);

      listRows.add(spacerRow);
    }

    return listRows;

  }

  Widget buildReporLineContent(UserReportLine userReportLine) {

    return new Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        new Column (
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            new Text(
              "RT",
              style: new TextStyle(
                fontSize: 10.0,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
            ),
            new Text(
              userReportLine.regularTime.toString(),
              style: new TextStyle(
                fontSize: 10.0,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
            ),
          ],
        ),
        new Column (
          children: [
            new Text(
              "OT",
              style: new TextStyle(
                fontSize: 10.0,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
            ),
            new Text(
              userReportLine.overtime.toString(),
              style: new TextStyle(
                fontSize: 10.0,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
            ),
          ],
        ),
        new Column (
          children: [
            new Text(
              "SHW",
              style: new TextStyle(
                fontSize: 10.0,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
            ),
            new Text(
              userReportLine.statHolidayWorked.toString(),
              style: new TextStyle(
                fontSize: 10.0,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
            ),
          ],
        ),
        new Column (
          children: [
            new Text(
              "TB",
              style: new TextStyle(
                fontSize: 10.0,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
            ),
            new Text(
              userReportLine.timeToBank.toString(),
              style: new TextStyle(
                fontSize: 10.0,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
            ),
          ],
        ),
        new Column (
          children: [
            new Text(
              "   ",
              style: new TextStyle(
                fontSize: 10.0,
                fontWeight: FontWeight.normal,
              ),
            ),
            new Text(
              "   ",
              style: new TextStyle(
                fontSize: 10.0,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
            ),
          ],
        ),
        new Column (
          children: [
            new Text(
              "VT",
              style: new TextStyle(
                fontSize: 10.0,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
            ),
            new Text(
              userReportLine.vacationTime.toString(),
              style: new TextStyle(
                fontSize: 10.0,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
            ),
          ],
        ),
        new Column (
          children: [
            new Text(
              "ST",
              style: new TextStyle(
                fontSize: 10.0,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
            ),
            new Text(
              userReportLine.sickTime.toString(),
              style: new TextStyle(
                fontSize: 10.0,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
            ),
          ],
        ),
        new Column (
          children: [
            new Text(
              "SH",
              style: new TextStyle(
                fontSize: 10.0,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
            ),
            new Text(
              userReportLine.statHoliday.toString(),
              style: new TextStyle(
                fontSize: 10.0,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
            ),
          ],
        ),
        new Column (
          children: [
            new Text(
              "TFB",
              style: new TextStyle(
                fontSize: 10.0,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
            ),
            new Text(
              userReportLine.timeFromBank.toString(),
              style: new TextStyle(
                fontSize: 10.0,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
            ),
          ],
        ),
        new Column (
          children: [
            new Text(
              "UTO",
              style: new TextStyle(
                fontSize: 10.0,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
            ),
            new Text(
              userReportLine.unpaidLeave.toString(),
              style: new TextStyle(
                fontSize: 10.0,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ],
    );

  }

  Widget buildReporLineTotals(UserReportLine userReportLine) {

    return new Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        new Text(
          "Totals: ",
          style: new TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        new Text(
          "Paid: " + userReportLine.totalPaid.toString(),
          style: new TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        new Text(
          "Unpaid: " + userReportLine.totalUnpaid.toString(),
          style: new TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
      ],
    );

  }

  ExpansionPanelHeaderBuilder  buildHeader(UserReportLine userReportLine)
  {
    return (BuildContext context, bool isExpanded) {
      String displayName = userReportLine.user.displayName;

      if (displayName == null || displayName.isEmpty)
        displayName = userReportLine.user.emailAddress;

      return new DualHeaderWithHint(
        name: displayName,
      );
    };
  }

  Widget buildDateRangeRow()
  {
    if (_reportEntity.userReportLines.isEmpty)
    {
      return new Row (
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            new Container(
              padding: const EdgeInsets.only(
                top: 5.0,
                bottom: 10.0,
              ),
              child: new Text(""),
            ),
          ]
      );
    }
    else
    {
      return new Row (
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            new Container(
              padding: const EdgeInsets.only(
                top: 5.0,
                bottom: 10.0,
              ),
              child: new Text(
                dateRangeString,
                style: new TextStyle(
                  fontSize: 10.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
          ]
      );
    }

  }
  Widget buildExpandedHoursPanel(List<UserReportLine> userReportLines) {

    if (_reportEntity.userReportLines.isEmpty)
    {
      return new Column(

          children: [
            new Text(
              "--- Selected User(s) Do Not Report Time ---",
              style: new TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],

      );
    }
    else
    {
      return new Column(

          children: userReportLines.map( (UserReportLine userReportLine) {
            if (selectedEmployee == "All" ||
                userReportLine.user.displayName == selectedEmployee) {
              return new Column(
                children:
                buildUserReportPage(userReportLine).toList(),
              );
            }}).toList()

      );
    }
  }

}

class DualHeaderWithHint extends StatelessWidget {
  const DualHeaderWithHint({
    this.name,
  });

  final String name;

  @override
  Widget build(BuildContext context) {

    return new Row(
        children: <Widget>[
          new Container(
            margin: const EdgeInsets.only(left: 24.0),
            child: new Text(
                name,
                style: new TextStyle(
                  fontWeight: FontWeight.normal,
                  fontSize: 14.0,
                  color: Colors.blue,
                ),
              ),
            ),
        ],
    );
  }
}

Widget buildTimeEntry(WeekDayEntity weekDayEntity) {

  String timeStr = "";
  var formatter = new DateFormat('EEE MMM d');

  timeStr = formatter.format(weekDayEntity.date) + ":    ";
  for (TimeEntry timeEntry in weekDayEntity.timeEntries) {
    if (timeStr == formatter.format(weekDayEntity.date) + ":    ")
      timeStr = timeStr + timeEntry.timeAmount.toString() + " " + generateTimeTypeAcronym(timeEntry);
    else
      timeStr = timeStr + ", " + timeEntry.timeAmount.toString() + " " + generateTimeTypeAcronym(timeEntry);


    if (timeEntry.hoursBanked != null)
    {
      double toBank = 0.0;
      toBank = double.parse(timeEntry.hoursBanked.split(" ")[0]);
      if (toBank > 0)
        timeStr = timeStr + " (BT: " + timeEntry.hoursBanked + ")";
    }
  }

  Text timeEntryText = new Text(
    timeStr,
    style: new TextStyle(
      fontWeight: FontWeight.normal,
      fontSize: 12.0,
    ),
    textAlign: TextAlign.left,
  );

  return timeEntryText;
}

class ReportLineDataSource extends DataTableSource {

  ReportLineDataSource(List<UserReportLine> this._reportLinesEntries);

  final List<UserReportLine> _reportLinesEntries;

  int _selectedCount = 0;

  @override
  DataRow getRow(int index) {
    assert(index >= 0);
    if (index >= _reportLinesEntries.length)
      return null;
    final UserReportLine userReportLine = _reportLinesEntries[index];
    return new DataRow.byIndex(
        index: index,
        selected: userReportLine.selected,
        onSelectChanged: (bool value) {
          if (userReportLine.selected != value) {
            _selectedCount += value ? 1 : -1;
            assert(_selectedCount >= 0);
            userReportLine.selected = value;
            notifyListeners();
          }
        },
        cells: <DataCell>[
          new DataCell(new Text('${userReportLine.regularTime}')),
          new DataCell(new Text('${userReportLine.overtime}')),
          new DataCell(new Text('${userReportLine.statHolidayWorked}')),
          new DataCell(new Text('${userReportLine.timeToBank}')),
          new DataCell(new Text('${userReportLine.vacationTime}')),
          new DataCell(new Text('${userReportLine.sickTime}')),
          new DataCell(new Text('${userReportLine.statHoliday}%')),
          new DataCell(new Text('${userReportLine.timeFromBank}%')),
          new DataCell(new Text('${userReportLine.unpaidLeave}%')),
        ]
    );
  }

  @override
  int get rowCount => _reportLinesEntries.length;

  @override
  bool get isRowCountApproximate => false;

  @override
  int get selectedRowCount => _selectedCount;

  void _selectAll(bool checked) {
    for (UserReportLine userReportLine in _reportLinesEntries)
      userReportLine.selected = checked;
    _selectedCount = checked ? _reportLinesEntries.length : 0;
    notifyListeners();
  }
}