// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'common.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart' show lowerBound;

enum DialogActions {
  cancel,
  discard,
  disagree,
  agree,
}

class TimeEntryDialog extends StatefulWidget {
  const TimeEntryDialog(
      this.weekDayEntity,
      this.onWeekDayEntityUpdated,
      this.archChronosUser, {
        Key key,
      })
      : super(key: key);

  final WeekDayEntity weekDayEntity;
  final WeekDayEntityCallback onWeekDayEntityUpdated;
  final ArchChronosUser archChronosUser;

  @override
  TimeEntryDialogState createState() => new TimeEntryDialogState(this.weekDayEntity, this.onWeekDayEntityUpdated, this.archChronosUser);
}

class TimeEntryDialogState extends State<TimeEntryDialog>
{
  bool _saveNeeded = false;

  TimeEntryDialogState(this._weekDayEntity, this._onWeekDayEntityUpdated, this._archChronosUser);

  final WeekDayEntity _weekDayEntity;
  final WeekDayEntityCallback _onWeekDayEntityUpdated;
  TextEditingController _commentsController;
  ArchChronosUser _archChronosUser;

  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();
  DismissDirection _dismissDirection = DismissDirection.horizontal;

  String workAwayValue = "Time Worked";
  String timeTypeValue = "Regular Time";
  String paidTimeAmountValue = "0 h 0 m";
  String bankedTimeAmountValue = "0 h 0 m";
  String fromBankTimeAmountValue = "0 h 0 m";
  String unpaidBreakValue = "0.0 H";
  String hoursToBank = "0.0 H";
  String fromTime = "8:00 AM";
  String toTime = "5:00 PM";
  String comments = "";

  List<String> bankHourSelections = ["0.0 H"];

  List<String> workSubTypes = [
    'Regular Time',
    'Overtime',
    'Stat Holiday Worked',
  ];

  List<String> hours = [
    '12:00 AM',
    '12:15 AM',
    '12:30 AM',
    '12:45 AM',
    '1:00 AM',
    '1:15 AM',
    '1:30 AM',
    '1:45 AM',
    '2:00 AM',
    '2:15 AM',
    '2:30 AM',
    '2:45 AM',
    '3:00 AM',
    '3:15 AM',
    '3:30 AM',
    '3:45 AM',
    '4:00 AM',
    '4:15 AM',
    '4:30 AM',
    '4:45 AM',
    '5:00 AM',
    '5:15 AM',
    '5:30 AM',
    '5:45 AM',
    '6:00 AM',
    '6:15 AM',
    '6:30 AM',
    '6:45 AM',
    '7:00 AM',
    '7:15 AM',
    '7:30 AM',
    '7:45 AM',
    '8:00 AM',
    '8:15 AM',
    '8:30 AM',
    '8:45 AM',
    '9:00 AM',
    '9:15 AM',
    '9:30 AM',
    '9:45 AM',
    '10:00 AM',
    '10:15 AM',
    '10:30 AM',
    '10:45 AM',
    '11:00 AM',
    '11:15 AM',
    '11:30 AM',
    '11:45 AM',
    '12:00 PM',
    '12:15 PM',
    '12:30 PM',
    '12:45 PM',
    '1:00 PM',
    '1:15 PM',
    '1:30 PM',
    '1:45 PM',
    '2:00 PM',
    '2:15 PM',
    '2:30 PM',
    '2:45 PM',
    '3:00 PM',
    '3:15 PM',
    '3:30 PM',
    '3:45 PM',
    '4:00 PM',
    '4:15 PM',
    '4:30 PM',
    '4:45 PM',
    '5:00 PM',
    '5:15 PM',
    '5:30 PM',
    '5:45 PM',
    '6:00 PM',
    '6:15 PM',
    '6:30 PM',
    '6:45 PM',
    '7:00 PM',
    '7:15 PM',
    '7:30 PM',
    '7:45 PM',
    '8:00 PM',
    '8:15 PM',
    '8:30 PM',
    '8:45 PM',
    '9:00 PM',
    '9:15 PM',
    '9:30 PM',
    '9:45 PM',
    '10:00 PM',
    '10:15 PM',
    '10:30 PM',
    '10:45 PM',
    '11:00 PM',
    '11:15 PM',
    '11:30 PM',
    '11:45 PM',
  ];

  double totalHours = 0.0;

  WeekDayEntity tempWeekDayEntity = new WeekDayEntity(null);

  @override
  void initState() {
    super.initState();
    _commentsController = new TextEditingController(text: comments);
    cloneWeekDayEntity(_weekDayEntity, tempWeekDayEntity);
    updateTimeEntrySummaryTotals();
  }

  void updateTimeEntrySummaryTotals(){

      double unpaidBreak = double.parse(unpaidBreakValue.substring(0,unpaidBreakValue.indexOf(" ")));

      int unpaidBreakHourAmount = unpaidBreak.toInt();
      int unpaidBreakMinuteAmount = 0;

      double remainder = unpaidBreak - unpaidBreak.floor();

      if (remainder == 0.0)
        unpaidBreakMinuteAmount = 0;
      else if (remainder == 0.25)
        unpaidBreakMinuteAmount = 15;
      else if (remainder == 0.5)
        unpaidBreakMinuteAmount = 30;
      else if (remainder == 0.75)
        unpaidBreakMinuteAmount = 45;

      int hourDiff = calculateHourDiff(toTime,fromTime);
      int minuteDiff = calculateMinuteDiff(toTime,fromTime);

      if (minuteDiff < 0) {
        hourDiff--;
        minuteDiff = 60 + minuteDiff;
      }

      hourDiff = hourDiff - unpaidBreakHourAmount;
      minuteDiff = minuteDiff - unpaidBreakMinuteAmount;

      if (minuteDiff < 0) {
        hourDiff--;
        minuteDiff = 60 + minuteDiff;
      }

      int bankDropdownHoursDiff = hourDiff;
      int bankDropdownMinuteDiff = minuteDiff;

      double bankAmount = 0.0;
      int bankHourAmount = 0;
      int bankMinuteAmount = 0;

      bankAmount = double.parse(hoursToBank.substring(0, hoursToBank.indexOf(" ")));

      bankHourAmount = bankAmount.toInt();
      bankMinuteAmount = 0;

      double bankRemainder = bankAmount - bankAmount.floor();

      if (bankRemainder == 0.0)
        bankMinuteAmount = 0;
      else if (bankRemainder == 0.25)
        bankMinuteAmount = 15;
      else if (bankRemainder == 0.5)
        bankMinuteAmount = 30;
      else if (bankRemainder == 0.75)
        bankMinuteAmount = 45;

      hourDiff = hourDiff - bankHourAmount;
      minuteDiff = minuteDiff - bankMinuteAmount;

      if (workAwayValue == "Time Away" && timeTypeValue == "Unpaid Time Off")
      {
        hourDiff = 0;
        minuteDiff = 0;
      }

      if (minuteDiff < 0) {
        hourDiff--;
        minuteDiff = 60 + minuteDiff;
      }

      paidTimeAmountValue = hourDiff.toString() + " h " + minuteDiff.toString() + " m";
      bankedTimeAmountValue = bankHourAmount.toString() + " h " + bankMinuteAmount.toString() + " m";

      if (workAwayValue == "Time Away" && timeTypeValue == "From Bank")
      {
        fromBankTimeAmountValue = paidTimeAmountValue;
      }
      else
        fromBankTimeAmountValue = "0 h 0 m";

      // based on the number of hours entered, populate the bank time hours dropdown
      bankHourSelections.clear();
      for (int i=0; i<bankDropdownHoursDiff;i++)
      {
        bankHourSelections.add(i.toString() + "." + "0 H");
        bankHourSelections.add(i.toString() + "." + "25 H");
        bankHourSelections.add(i.toString() + "." + "5 H");
        bankHourSelections.add(i.toString() + "." + "75 H");
      }
      bankHourSelections.add(bankDropdownHoursDiff.toString() + "." + "0 H");
      if (bankDropdownMinuteDiff == 45)
      {
        bankHourSelections.add(bankDropdownHoursDiff.toString() + "." + "25 H");
        bankHourSelections.add(bankDropdownHoursDiff.toString() + "." + "5 H");
        bankHourSelections.add(bankDropdownHoursDiff.toString() + "." + "75 H");
      }
      else if (bankDropdownMinuteDiff == 30)
      {
        bankHourSelections.add(bankDropdownHoursDiff.toString() + "." + "25 H");
        bankHourSelections.add(bankDropdownHoursDiff.toString() + "." + "5 H");
      }
      else if (bankDropdownMinuteDiff == 15)
      {
        bankHourSelections.add(bankDropdownHoursDiff.toString() + "." + "25 H");
      }
  }

  void commentsTextChanged(String newValue) {
    setState(() {
      _saveNeeded = true;
      comments = _commentsController.text;
    });
  }

  void workTypeChanged(String newValue) {
    setState(() {
      _saveNeeded = true;
      workAwayValue = newValue;
      if (workAwayValue == "Time Worked")
      {
        timeTypeValue = "Regular Time";
        workSubTypes = [
          'Regular Time',
          'Overtime',
          'Stat Holiday'
        ];
      }
      else
      {
        timeTypeValue = "Vacation";
        workSubTypes = [
          'Vacation',
          'Sick Time',
          'Stat Holiday',
          'Unpaid Time Off',
          'From Bank',
          'Time Off In Lieu',
        ];
      }
      hoursToBank = "0.0 H";
      updateTimeEntrySummaryTotals();
    });
  }

  void workSubTypeChanged(String newValue) {
    setState(() {
      _saveNeeded = true;
      timeTypeValue = newValue;
      hoursToBank = "0.0 H";
      updateTimeEntrySummaryTotals();
    });
  }

  void fromTimeChanged(String newValue) {
    setState(() {
      fromTime = newValue;
      hoursToBank = "0.0 H";
      updateTimeEntrySummaryTotals();
    });
  }

  void toTimeChanged(String newValue) {
    setState(() {
      toTime = newValue;
      hoursToBank = "0.0 H";
      updateTimeEntrySummaryTotals();
    });
  }

  void unpaidBreakValueChanged(String newValue) {
    setState(() {
      _saveNeeded = true;
      unpaidBreakValue = newValue;
      hoursToBank = "0.0 H";
      updateTimeEntrySummaryTotals();
    });
  }

  void hoursToBankValueChanged(String newValue) {
    setState(() {
      _saveNeeded = true;
      hoursToBank = newValue;
      bankedTimeAmountValue = hoursToBank.toString();
      updateTimeEntrySummaryTotals();
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

    updateTimeEntrySummaryTotals();

    if (tempWeekDayEntity.timeEntries.length == 4)
    {
      final ThemeData theme = Theme.of(context);
      final TextStyle dialogTextStyle = theme.textTheme.subhead.copyWith(color: theme.textTheme.caption.color);
      showPopupDialog<DialogActions>(
          context: context,
          child: new AlertDialog(
              content: new Text(
                  "A maximum of 4 time entries can be added.",
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

    if (this.workAwayValue == "Time Away" && ((this.timeTypeValue == "Time Off In Lieu" || this.timeTypeValue == "From Bank") && this.comments == ""))
    {
      final ThemeData theme = Theme.of(context);
      final TextStyle dialogTextStyle = theme.textTheme.subhead.copyWith(color: theme.textTheme.caption.color);
      showPopupDialog<DialogActions>(
          context: context,
          child: new AlertDialog(
              content: new Text(
                  "You must provide a comment explaining Time Off In Lieu or Time From Bank.",
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

    double fromBankAmount = calculateTimeAmountFromString(this.fromBankTimeAmountValue);
    if (fromBankAmount > 0 && fromBankAmount > _archChronosUser.bankedTimeBalance)
    {
      final ThemeData theme = Theme.of(context);
      final TextStyle dialogTextStyle = theme.textTheme.subhead.copyWith(color: theme.textTheme.caption.color);
      showPopupDialog<DialogActions>(
          context: context,
          child: new AlertDialog(
              content: new Text(
                  "You do not have enough time in your Banked Time Balance.",
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

    if (calculateTimeAmountFromString(this.paidTimeAmountValue) < 0)
    {
      final ThemeData theme = Theme.of(context);
      final TextStyle dialogTextStyle = theme.textTheme.subhead.copyWith(color: theme.textTheme.caption.color);
      showPopupDialog<DialogActions>(
          context: context,
          child: new AlertDialog(
              content: new Text(
                  "Time worked can't be zero or negative.",
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

    if (calculateTotalHours(tempWeekDayEntity) + calculateTimeAmountFromString(this.paidTimeAmountValue) > 12)
    {
      final ThemeData theme = Theme.of(context);
      final TextStyle dialogTextStyle = theme.textTheme.subhead.copyWith(color: theme.textTheme.caption.color);
      showPopupDialog<DialogActions>(
          context: context,
          child: new AlertDialog(
              content: new Text(
                  "The total of hours worked can not be greater than 12.",
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

    setState(() {

      TimeEntry timeEntry = new TimeEntry();
      timeEntry.comments = this.comments;
      timeEntry.timeAmount = calculateTimeAmountFromString(paidTimeAmountValue);
      timeEntry.timeType = this.timeTypeValue;
      timeEntry.timeWorkedOrAway = this.workAwayValue;
      timeEntry.startTime = this.fromTime.toString();
      timeEntry.endTime = this.toTime.toString();
      timeEntry.unpaidBreak = this.unpaidBreakValue;
      timeEntry.hoursBanked = this.hoursToBank;
      timeEntry.utcSecsSinceEpoch = tempWeekDayEntity.date.toUtc().millisecondsSinceEpoch;

      tempWeekDayEntity.timeEntries.add(timeEntry);

      workSubTypes = [
        'Regular Time',
        'Overtime',
        'Stat Holiday Worked'
      ];

      // reset all fields
      this.comments = "";
      this._commentsController.text = "";
      this.paidTimeAmountValue = "8 h 0 m";
      this.workAwayValue = "Time Worked";
      this.timeTypeValue = "Regular Time";
      this.fromTime = "8:00 AM";
      this.toTime = "5:00 PM";
      this.unpaidBreakValue = "0.0 H";
      this.hoursToBank = "0.0 H";

      _saveNeeded = true;

    });

    cloneWeekDayEntity(tempWeekDayEntity, _weekDayEntity);
    _onWeekDayEntityUpdated();
    _saveNeeded = false;

  }

  Widget buildTimeEntry(TimeEntry timeEntry) {

    Icon icon;
    if (timeEntry.timeWorkedOrAway == "Time Worked") {
      icon = new Icon(
        Icons.timer,
        color: Colors.green,
      );
    }
    else {
      icon = new Icon(
        Icons.call_missed,
        color: Colors.red,
      );
    }

    final ThemeData theme = Theme.of(context);

    return new Dismissible(
        key: new ObjectKey(timeEntry),
        direction: _dismissDirection,
        onDismissed: (DismissDirection direction) {
          setState(() {
            this.tempWeekDayEntity.timeEntries.remove(timeEntry);
            cloneWeekDayEntity(tempWeekDayEntity, _weekDayEntity);
            _onWeekDayEntityUpdated();
            _saveNeeded = false;
          });
          final String action = (direction == DismissDirection.endToStart) ? 'archived' : 'deleted';
          _scaffoldKey.currentState.showSnackBar(new SnackBar(
              content: new Text('You $action item ${timeEntry.timeType}'),
              action: new SnackBarAction(
                  label: 'UNDO',
                  onPressed: () { handleUndo(timeEntry); }
              )
          ));
        },
        background: new Container(
            color: Colors.red,
            child: const ListTile(
                leading: const Icon(Icons.delete, color: Colors.white, size: 36.0)
            )
        ),
        secondaryBackground: new Container(
            color: Colors.red,
            child: const ListTile(
                trailing: const Icon(Icons.delete, color: Colors.white, size: 36.0)
            )
        ),
        child: new Container(
            decoration: new BoxDecoration(
                color: theme.canvasColor,
                border: new Border(bottom: new BorderSide(color: theme.dividerColor))
            ),
            child: new ListTile(
              leading: icon,
              title: new Text(
                timeEntry.timeAmount.toString() + " Hours - " +
                timeEntry.timeType
              ),
              isThreeLine: true,
              subtitle: new Text('Comments: ' + timeEntry.comments),
              trailing: new Container(
                child: new Column (
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    new Text(
                        timeEntry.startTime + " - " + timeEntry.endTime,
                        style: new TextStyle(fontSize: 8.0,),
                    ),
                    new Text(
                      "UB " + timeEntry.unpaidBreak,
                      style: new TextStyle(fontSize: 8.0,),
                    ),
                    new Text(
                      "Banked " + timeEntry.hoursBanked,
                      style: new TextStyle(fontSize: 8.0,),
                    ),
                  ],
                ),
              ),
            )
        )
    );
  }

  void handleUndo(TimeEntry item) {
    final int insertionIndex = lowerBound(this.tempWeekDayEntity.timeEntries, item);
    setState(() {
      this.tempWeekDayEntity.timeEntries.insert(insertionIndex, item);
    });
  }

  Widget buildBankHoursColumn(ThemeData theme)
  {
    if (workAwayValue == "Time Worked" || (workAwayValue == "Time Away" && timeTypeValue == "Stat Holiday")) {
      return new Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            new Text('Bank (Bal: ' + formatTimeFromDoubleToString(_archChronosUser.bankedTimeBalance) + ')', style: theme.textTheme.caption),
            new DropdownButton<String>(
                value: hoursToBank,
                onChanged: hoursToBankValueChanged,
                items: bankHourSelections.map((String value) {
                  return new DropdownMenuItem<String>(
                      value: value, child: new Text(value));
                }).toList()
            ),
          ]
      );
    }
    else if (workAwayValue == "Time Away" && timeTypeValue == "From Bank")
    {
      return new Text(
        'Bank Balance: ' + formatTimeFromDoubleToString(_archChronosUser.bankedTimeBalance),
        style: new TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: Colors.blue),
      );
    }
    else
    {
      return new Text("");
    }
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

    final ThemeData theme = Theme.of(context);
    var formatter = new DateFormat('EEE MMM d');

    final Widget actions = new ButtonTheme.bar(
      child: new ButtonBar(
        children: <Widget>[
          new FlatButton(
            child: const Text('ADD Time Entry'),
            onPressed: () {this.addClicked();},
          ),
        ],
      ),
    );

    return new Scaffold(
      key: _scaffoldKey,
      appBar: new AppBar(
        title: new Text('Time for ' + formatter.format(tempWeekDayEntity.date)),
      ),
      body: new Form(
        onWillPop: _onWillPop,
        child: new ListView(
          padding: const EdgeInsets.all(16.0),
          children: <Widget> [
            new Container(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              height: 70.0,
              child: new Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  new Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      new Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          new Text('Worked / Away', style: theme.textTheme.caption),
                          new DropdownButton<String>(
                            value: workAwayValue,
                            onChanged: workTypeChanged,
                            items: <String>[
                              'Time Worked',
                              'Time Away'
                            ].map((String value) {
                              return new DropdownMenuItem<String>(
                                  value: value, child: new Text(value));
                            }).toList()
                          ),
                        ]
                      ),
                      new Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          new Text('Time Type', style: theme.textTheme.caption),
                          new DropdownButton<String>(
                            value: timeTypeValue,
                            onChanged: workSubTypeChanged,
                            items: workSubTypes.map((String value) {
                              return new DropdownMenuItem<String>(
                                  value: value, child: new Text(value));
                            }).toList()
                          ),
                        ]
                      ),
                    ]
                  ),
                ]
              ),
            ),
            new Container(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              height: 80.0,
              child: new Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    new Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          new Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                new Text('From', style: theme.textTheme.caption),
                                new DropdownButton<String>(
                                    value: fromTime,
                                    onChanged: fromTimeChanged,
                                    items: hours.map((String value) {
                                      return new DropdownMenuItem<String>(
                                          value: value, child: new Text(value));
                                    }).toList()
                                ),
                              ]
                          ),
                          new Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                new Text('To', style: theme.textTheme.caption),
                                new DropdownButton<String>(
                                    value: toTime,
                                    onChanged: toTimeChanged,
                                    items: hours.map((String value) {
                                      return new DropdownMenuItem<String>(
                                          value: value, child: new Text(value));
                                    }).toList()
                                ),
                              ]
                          ),
                        ]
                    ),
                  ]
              ),
            ),
            new Container(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: new Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  new Row (
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      new Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            new Text('Unpaid Break', style: theme.textTheme.caption),
                            new DropdownButton<String>(
                                value: unpaidBreakValue,
                                onChanged: unpaidBreakValueChanged,
                                items: <String>[
                                  '0.0 H',
                                  '0.25 H',
                                  '0.5 H',
                                  '0.75 H',
                                  '1.0 H',
                                  '1.25 H',
                                  '1.5 H',
                                  '1.75 H',
                                  '2.0 H',
                                ].map((String value) {
                                  return new DropdownMenuItem<String>(
                                      value: value, child: new Text(value));
                                }).toList()
                            ),
                          ]
                      ),
                      buildBankHoursColumn(theme),
                    ],
                  ),
                ]
              ),
            ),
            new Container(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: new Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  new Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      new Text(
                        'Total Paid Hours: ' + paidTimeAmountValue,
                        style: new TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                      new Text(
                        'Total Banked Hours: ' + bankedTimeAmountValue,
                        style: new TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            new Container(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              height: 80.0,
              child: new Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  new TextField(
                    maxLines: 2,
                    onChanged: commentsTextChanged,
                    controller: _commentsController,
                    decoration: new InputDecoration(
                      hintText: 'Enter A Comment',
                    ),
                  ),
                ]
              ),
            ),
            new Container(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              height: 50.0,
              child: actions,
            ),
            new Container(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                height: 20.0,
                child: new Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      new Text("Worked: " + calculateHoursWorked(this.tempWeekDayEntity), style: new TextStyle(fontWeight: FontWeight.bold, color: Colors.green),),
                      new Text("Away: " + calculateHoursAway(this.tempWeekDayEntity), style: new TextStyle(fontWeight: FontWeight.bold, color: Colors.red),),
                      new Text("Total: " + calculateTotalHours(this.tempWeekDayEntity).toString(), style: new TextStyle(fontWeight: FontWeight.bold),),
                    ]
                )
            ),
            new Container(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              height: 10.0,
              child: new Divider(color: Colors.white, height: 15.0,),
            ),
            new Container(
              height: 160.0,
              child: new ListView(
                children:
                this.tempWeekDayEntity.timeEntries.map(buildTimeEntry).toList(),
              ),
            ),
          ]
        )
      ),
    );
  }
}
