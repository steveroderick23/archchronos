import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

typedef void MoveWeekCallback();
typedef void SetupWeekViewCallback(WeekViewEntity weekViewEntity, DateTime date);
typedef void SaveArchChronosUserCallback(ArchChronosUser archChronosUser);
typedef void WeekDayEntityCallback();
typedef void EmptyArgCallback();
typedef void BuildContextCallback(BuildContext context, String routeName, String caller);
typedef void BuildContextAndRouteCallback(BuildContext context, String routeName,);
typedef void SimpleContextCallback(BuildContext context);
typedef void DateCallback(DateTime date);

final firestoreDB = Firestore.instance;

class Tenant  {

  String tenantID;
  String tenantName;
  String tenantCode;
  String contactEmailAddress;
  String contactPhoneNumber;
  bool isEnabled;
  int paydayUtcMillisSinceEpoch;

  Map<String, dynamic> toJson() => {"tenantID":tenantID, "tenantName":tenantName, "tenantCode":tenantCode, "emailAddress":contactEmailAddress, "phoneNumber":contactPhoneNumber, "isEnabled":isEnabled, "paydayUtcMillisSinceEpoch": paydayUtcMillisSinceEpoch};
}

class Notification  {

  String notificationType;
  String message;
  String tokens;
  String sender;
  String senderUID;
  String timestamp;

  Map<String, dynamic> toJson() => {"notificationType":notificationType, "message":message, "tokens":tokens, "senderName":sender, "senderUID":senderUID, "timestamp":timestamp};
}

class Message  {

  String message;
  String sender;
  String senderUID;
  String recipientNames;
  String recipientUIDs;
  String timestamp;
  String direction;
  String conversationWithNames;
  String conversationWithUIDs;
  int utcMillisSinceEpoch;
  bool hasBeenRead;
  String firestoreKey;

  Map<String, dynamic> toJson() => {"message":message,
    "sender":sender,
    "senderUID":senderUID,
    "recipientNames":recipientNames,
    "recipientUIDs":recipientUIDs,
    "timestamp":timestamp,
    "direction":direction,
    "conversationWithNames":conversationWithNames,
    "conversationWithUIDs":conversationWithUIDs,
    "utcMillisSinceEpoch":utcMillisSinceEpoch,
    "hasBeenRead":hasBeenRead,
    "firestoreKey":firestoreKey,};
}

class ArchChronosUser
{
  ArchChronosUser(this.displayName);

  String tenantId;
  String displayName;
  String uid;
  String emailAddress;
  bool isAdmin;
  bool isTimeEntryRequired;
  bool isVacationAccumulated;
  double bankedTimeBalance;
  double vacationBalance;
  double vacationRate;
  bool isEnabled;
  String providerId;
  String password;
  String messagingToken;
  bool paydayNotificationAcknowledged;

  Map<String, dynamic> toJson() => {
    "tenantId":tenantId,
    "displayName":displayName,
    "uid":uid,
    "emailAddress":emailAddress,
    "isAdmin":isAdmin,
    "isTimeEntryRequired":isTimeEntryRequired,
    "isVacationAccumulated":isVacationAccumulated,
    "bankedTimeBalance":bankedTimeBalance,
    "vacationBalance":vacationBalance,
    "vacationRate":vacationRate,
    "isEnabled":isEnabled,
    "providerId":providerId,
    "password":password,
    "messagingToken":messagingToken,
    "paydayNotificationAcknowledged":paydayNotificationAcknowledged,
  };

  bool operator ==(other) {
    return (other is ArchChronosUser && other.uid == uid);
  }
}
class WeekViewEntity {

  WeekViewEntity(this.weekDayEntities);

  final List<WeekDayEntity> weekDayEntities;

  DateTime date;

  Map<String, dynamic> toJson() {
    Map map = new Map();
    for (var weekDayEntity in weekDayEntities)
    {
      map[weekDayEntity.date.toUtc().millisecondsSinceEpoch.toString()] = weekDayEntity.toJson();
    }
    return map;
  }

}

class ReportEntity {

  ReportEntity(this.weekDayEntities, this.userReportLines);

  final List<WeekDayEntity> weekDayEntities;
  final List<UserReportLine> userReportLines;

  DateTime selectedPayday;
  DateTime date;

}

class UserReportLine  {

  UserReportLine(this.user);

  ArchChronosUser user;

  double regularTime = 0.0;
  double overtime = 0.0;
  double statHolidayWorked = 0.0;
  double vacationTime = 0.0;
  double sickTime = 0.0;
  double statHoliday = 0.0;
  double unpaidLeave = 0.0;
  double totalPaid = 0.0;
  double totalUnpaid = 0.0;
  double timeToBank = 0.0;
  double timeFromBank = 0.0;

  bool selected = false;

  WeekViewEntity weekViewEntity;

  bool isExpanded = false;
}

class WeekDayEntity {

  WeekDayEntity(this.date);
  List<TimeEntry> timeEntries = new List<TimeEntry>();
  DateTime date;
  bool selected;

  Map<String, dynamic> toJson() {
    Map map = new Map();
    int i=0;
    for (var timeEntry in timeEntries)
    {
      map["timeEntry" + i.toString()] = timeEntry.toJson();
      i++;
    }
    return map;
  }
}

enum DismissDialogAction {
  cancel,
  discard,
  save,
}

class TimeEntry {

  String timeWorkedOrAway;
  String timeType;
  String startTime;
  String endTime;
  double timeAmount;
  String unpaidBreak;
  String hoursBanked;
  String comments;
  int utcSecsSinceEpoch;

  Map<String, dynamic> toJson() => {"timeWorkedOrAway":timeWorkedOrAway, "timeType":timeType, "startTime":startTime, "endTime":endTime, "timeAmount":timeAmount, "unpaidBreak":unpaidBreak,"hoursBanked":hoursBanked,"comments":comments,"utcSecsSinceEpoch":utcSecsSinceEpoch};
}

bool isDateInTheFuture(DateTime date)
{
  var nowDate = DateTime.parse(new DateFormat("yyyy-MM-dd 00:00:00").format(new DateTime.now().toUtc())).toUtc();
  if (date.isAfter(nowDate))
  {
    if (date.year == nowDate.year && date.month == nowDate.month && date.day == nowDate.day)
      return false;
    else
      return true;
  }

  else
    return false;
}

String formatTimeForLocalTimezone(int datetimeAsLong)
{
  return new DateFormat("yyyy-MM-dd  hh:mm a").format(new DateTime.fromMillisecondsSinceEpoch(datetimeAsLong).subtract(new Duration(hours: 3)).toLocal());
}

void cloneWeekDayEntity(WeekDayEntity source, WeekDayEntity dest)
{
  dest.date = source.date;
  dest.selected = source.selected;
  dest.timeEntries.clear();
  for (var _timeEntry in source.timeEntries)
  {
    TimeEntry timeEntry = new TimeEntry();

    timeEntry.timeType = _timeEntry.timeType;
    timeEntry.startTime = _timeEntry.startTime;
    timeEntry.endTime = _timeEntry.endTime;
    timeEntry.timeAmount = _timeEntry.timeAmount;
    timeEntry.unpaidBreak = _timeEntry.unpaidBreak;
    timeEntry.hoursBanked = _timeEntry.hoursBanked;

    timeEntry.timeWorkedOrAway = _timeEntry.timeWorkedOrAway;
    timeEntry.comments = _timeEntry.comments;
    timeEntry.utcSecsSinceEpoch = _timeEntry.utcSecsSinceEpoch;

    dest.timeEntries.add(timeEntry);
  }
}

void cloneWeekViewEntity(WeekViewEntity source, WeekViewEntity dest)
{
  dest.date = source.date;
  for (var _weekDayEntity in dest.weekDayEntities)
  {
    _weekDayEntity.timeEntries.clear();
    _weekDayEntity.selected = false;

    WeekDayEntity weekDayEntity = findWeekDayEntity(source, _weekDayEntity.date);
    if (weekDayEntity != null)
      cloneWeekDayEntity(weekDayEntity, _weekDayEntity);

  }
}

WeekDayEntity findWeekDayEntity(WeekViewEntity source, DateTime date)
{
  for (var weekDayEntity in source.weekDayEntities)
  {
    if (weekDayEntity.date == date)
      return weekDayEntity;
  }
  return null;
}

String stripUserEmail(String userEmail) {
  return userEmail.replaceAll(".", "").replaceAll("@", "");
}

double calculateTimeAmountFromString(String timeAmountString)
{
  double timeAmount = 0.0;

  double hourAmount = double.parse(timeAmountString.split(" ")[0]);
  double minuteAmount = double.parse(timeAmountString.split(" ")[2]);

  if (minuteAmount == 0)
    timeAmount = hourAmount;
  else if (minuteAmount == 15)
    timeAmount = hourAmount + .25;
  else if (minuteAmount == 30)
    timeAmount = hourAmount + .5;
  else if (minuteAmount == 45)
    timeAmount = hourAmount + .75;

  return timeAmount;
}

double calculateTotalHours(WeekDayEntity weekDayEntity)
{
  double total = 0.0;
  for (var timeEntry in weekDayEntity.timeEntries)
  {
    total = total + timeEntry.timeAmount;
  }

  return total;
}

String calculateHoursWorked(WeekDayEntity weekDayEntity)
{
  double total = 0.0;
  for (var timeEntry in weekDayEntity.timeEntries)
  {
    if (timeEntry.timeWorkedOrAway == "Time Worked")
      total = total + timeEntry.timeAmount;
  }

  return total.toString();
}

String calculateHoursAway(WeekDayEntity weekDayEntity)
{
  double total = 0.0;
  for (var timeEntry in weekDayEntity.timeEntries)
  {
    if (timeEntry.timeWorkedOrAway == "Time Away")
      total = total + timeEntry.timeAmount;
  }

  return total.toString();
}

class DatePicker extends StatelessWidget {
  const DatePicker({
    Key key,
    this.selectedDate,
    this.selectDate,
  }) : super(key: key);

  final DateTime selectedDate;
  final ValueChanged<DateTime> selectDate;

  Future<Null> _selectDate(BuildContext context) async {
    final DateTime picked = await showDatePicker(
        context: context,
        initialDate: selectedDate,
        firstDate: new DateTime(2015, 8).toUtc(),
        lastDate: new DateTime(2101).toUtc()
    );
    if (picked != null && picked != selectedDate)
      selectDate(picked);
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle valueStyle = Theme.of(context).textTheme.title;
    return new Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        new Expanded(
          child: new _InputDropdown(
            valueText: new DateFormat.yMMMd().format(selectedDate),
            valueStyle: valueStyle,
            onPressed: () { _selectDate(context); },
          ),
        ),

      ],
    );
  }
}

class TimePicker extends StatelessWidget {
  const TimePicker({
    Key key,
    this.labelText,
    this.selectedTime,
    this.selectTime
  }) : super(key: key);

  final String labelText;
  final TimeOfDay selectedTime;
  final ValueChanged<TimeOfDay> selectTime;

  Future<Null> _selectTime(BuildContext context) async {
    final TimeOfDay picked = await showTimePicker(
        context: context,
        initialTime: selectedTime,
    );
    if (picked != null && picked != selectedTime)
      selectTime(picked);
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle valueStyle = Theme.of(context).textTheme.title;
    return new Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        new Expanded(
          flex: 3,
          child: new _InputDropdown(
            labelText: labelText,
            valueText: selectedTime.format(context),
            valueStyle: valueStyle,
            onPressed: () { _selectTime(context); },
          ),
        ),
      ],
    );
  }
}

class _InputDropdown extends StatelessWidget {
  const _InputDropdown({
    Key key,
    this.child,
    this.labelText,
    this.valueText,
    this.valueStyle,
    this.onPressed }) : super(key: key);

  final String labelText;
  final String valueText;
  final TextStyle valueStyle;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return new InkWell(
      onTap: onPressed,
      borderRadius: null,
      child: new InputDecorator(
        decoration: new InputDecoration(
          labelText: null,
          border: InputBorder.none,
        ),
        baseStyle: valueStyle,
        child: new Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            new Text(valueText, style: valueStyle),
            new Icon(Icons.arrow_drop_down,
                color: Theme.of(context).brightness == Brightness.light ? Colors.grey.shade700 : Colors.white70
            ),
          ],
        ),
      ),
    );
  }
}

String getWeekSpanString(DateTime dateTime)
{
  var formatter = new DateFormat('MMM');
  DateTime startDate = determineStartDateTime(dateTime);
  String dateRangeString = "Week of " + formatter.format(startDate) + " " + startDate.day.toString() + " to " + formatter.format(startDate.add(new Duration(days: 6))) + " " + startDate.add(new Duration(days: 6)).day.toString();

  return dateRangeString;
}

String setupWeekViewEntity (WeekViewEntity weekViewEntity, DateTime date)  {

  String dateRangeString = "";
  weekViewEntity.date = date;

  // based on the date passed, get the week start day of month
  int selectedDayOfMonth = date.day;
  String startMonth = "";
  String endMonth = "";

  dateRangeString = getWeekSpanString(date);

  weekViewEntity.weekDayEntities.clear();

  DateTime startDate = determineStartDateTime(date);

  WeekDayEntity day1 = new WeekDayEntity(startDate);
  if (day1.date.day == date.day)
    day1.selected = true;
  else
    day1.selected = false;

  weekViewEntity.weekDayEntities.add(day1) ;

  WeekDayEntity day2 = new WeekDayEntity(startDate.add(new Duration(days: 1)));
  if (day2.date.day == date.day)
    day2.selected = true;
  else
    day2.selected = false;

  weekViewEntity.weekDayEntities.add(day2) ;

  WeekDayEntity day3 = new WeekDayEntity(startDate.add(new Duration(days: 2)));
  if (day3.date.day == date.day)
    day3.selected = true;
  else
    day3.selected = false;

  weekViewEntity.weekDayEntities.add(day3) ;

  WeekDayEntity day4 = new WeekDayEntity(startDate.add(new Duration(days: 3)));
  if (day4.date.day == date.day)
    day4.selected = true;
  else
    day4.selected = false;

  weekViewEntity.weekDayEntities.add(day4) ;

  WeekDayEntity day5 = new WeekDayEntity(startDate.add(new Duration(days: 4)));
  if (day5.date.day == date.day)
    day5.selected = true;
  else
    day5.selected = false;

  weekViewEntity.weekDayEntities.add(day5) ;

  WeekDayEntity day6 = new WeekDayEntity(startDate.add(new Duration(days: 5)));
  if (day6.date.day == date.day)
    day6.selected = true;
  else
    day6.selected = false;

  weekViewEntity.weekDayEntities.add(day6) ;

  WeekDayEntity day7 = new WeekDayEntity(startDate.add(new Duration(days: 6)));
  if (day7.date.day == date.day)
    day7.selected = true;
  else
    day7.selected = false;

  weekViewEntity.weekDayEntities.add(day7) ;

  return dateRangeString;
}

String determineWeekKey(DateTime date)
{
  DateTime startDateTime = determineStartDateTime(date);
  var formatter = new DateFormat('ddMMMyyyy');
  return formatter.format(startDateTime) + "-" + formatter.format(startDateTime.add(new Duration(days: 7)));
}


DateTime determineStartDateTime(DateTime date)
{
  DateTime startDateTime;
  switch (date.weekday) {
    case DateTime.saturday:
      startDateTime = date;
      break;
    case DateTime.sunday:
      startDateTime = date.subtract(new Duration(days: 1));
      break;
    case DateTime.monday:
      startDateTime = date.subtract(new Duration(days: 2));
      break;
    case DateTime.tuesday:
      startDateTime = date.subtract(new Duration(days: 3));
      break;
    case DateTime.wednesday:
      startDateTime = date.subtract(new Duration(days: 4));
      break;
    case DateTime.thursday:
      startDateTime = date.subtract(new Duration(days: 5));
      break;
    case DateTime.friday:
      startDateTime = date.subtract(new Duration(days: 6));
      break;
  }
  return startDateTime;
}

Future pushWeekViewEntityToCloud(String tenantID, WeekViewEntity weekViewEntity, ArchChronosUser user) async
{
  String userKey = user.uid;

  double bankAdjustment = 0.0;
  double totalVacationTaken = 0.0;

  for (WeekDayEntity weekDayEntity in weekViewEntity.weekDayEntities)
  {
    String dateTimeKey = weekDayEntity.date.toUtc().millisecondsSinceEpoch.toString();

    // query for any existing timeentries for this day and delete them
    CollectionReference timeEntriesRef = firestoreDB.collection("tenants").
    document(tenantID).collection("users").document(user.uid).collection("timeentries");

    QuerySnapshot timeEntrySnapshot = await timeEntriesRef.where("utcSecsSinceEpoch", isEqualTo: int.parse(dateTimeKey)).getDocuments();
    if (timeEntrySnapshot != null)
    {
      for (DocumentSnapshot timeEntryDoc in timeEntrySnapshot.documents)
      {
        bankAdjustment -= double.parse(timeEntryDoc.data["hoursBanked"].split(" ")[0]);
        if (timeEntryDoc.data["timeWorkedOrAway"] == "Time Away")
        {
          if (timeEntryDoc.data["timeType"] == 'Vacation')
          {
            totalVacationTaken -= timeEntryDoc.data["timeAmount"];
          }
          if (timeEntryDoc.data["timeType"] == 'From Bank')
            bankAdjustment += timeEntryDoc.data["timeAmount"];
        }

        timeEntryDoc.reference.delete();
      }

    }

    if (weekDayEntity.timeEntries.isNotEmpty)
    {
      int entryIndex = 0;
      for (TimeEntry timeEntry in weekDayEntity.timeEntries) {

        bankAdjustment += double.parse(timeEntry.hoursBanked.split(" ")[0]);
        if (timeEntry.timeWorkedOrAway == "Time Away")
        {
          if (timeEntry.timeType == 'Vacation')
          {
            totalVacationTaken += timeEntry.timeAmount;
          }
          if (timeEntry.timeType == 'From Bank')
            bankAdjustment -= timeEntry.timeAmount;
        }

        firestoreDB.collection('tenants').document(tenantID).collection("users").document(userKey).collection("timeentries").document(dateTimeKey + "-" + entryIndex.toString()).setData(timeEntry.toJson());
        entryIndex++;
      }
    }
  }

  user.bankedTimeBalance += bankAdjustment;
  user.vacationBalance += totalVacationTaken;

  firestoreDB.collection('tenants').document(tenantID).collection("users").document(userKey).setData(user.toJson(), merge: true);

}

Future pullWeekViewEntityFromCloud(String tenantID, WeekViewEntity weekViewEntity, String uid, EmptyArgCallback onWeekViewEntityLoaded) async
{
  int startDateEpoch = determineStartDateEpoch(weekViewEntity.date, "Week", null);
  int endDateEpoch = weekViewEntity.date.add(new Duration(days: 7)).millisecondsSinceEpoch;

  CollectionReference timeEntriesRef = firestoreDB.collection("tenants").
                      document(tenantID).collection("users").document(uid).collection("timeentries");

  QuerySnapshot snapshot = await timeEntriesRef.where("utcSecsSinceEpoch", isGreaterThanOrEqualTo: startDateEpoch, isLessThanOrEqualTo: endDateEpoch).getDocuments();
  if (snapshot != null) {

    WeekViewEntity cloudWeekView = new WeekViewEntity(new List<WeekDayEntity>());
    cloudWeekView.date = weekViewEntity.date;

    for (DocumentSnapshot timeEntryDoc in snapshot.documents)
    {
      DateTime date = new DateTime.fromMillisecondsSinceEpoch(timeEntryDoc.data["utcSecsSinceEpoch"], isUtc: true);
      WeekDayEntity cloudWeekDayEntity = findWeekDayEntityInList(cloudWeekView.weekDayEntities, date);
      if (cloudWeekDayEntity != null)
        cloudWeekDayEntity = cloudWeekView.weekDayEntities.elementAt(cloudWeekView.weekDayEntities.indexOf(cloudWeekDayEntity));
      else
      {
        cloudWeekDayEntity = new WeekDayEntity(date);
        cloudWeekView.weekDayEntities.add(cloudWeekDayEntity);
      }

      TimeEntry timeEntry = new TimeEntry();
      timeEntry.timeWorkedOrAway = timeEntryDoc.data["timeWorkedOrAway"];
      timeEntry.startTime = timeEntryDoc.data["startTime"];
      timeEntry.endTime = timeEntryDoc.data["endTime"];
      timeEntry.timeAmount = timeEntryDoc.data["timeAmount"].toDouble();
      timeEntry.unpaidBreak = timeEntryDoc.data["unpaidBreak"];
      if (timeEntryDoc.data["hoursBanked"] != null)
        timeEntry.hoursBanked = timeEntryDoc.data["hoursBanked"];
      else
        timeEntry.hoursBanked = "0.0 H";
      timeEntry.timeType = timeEntryDoc.data["timeType"];
      timeEntry.comments = timeEntryDoc.data["comments"];
      timeEntry.utcSecsSinceEpoch = timeEntryDoc.data["utcSecsSinceEpoch"];

      cloudWeekDayEntity.timeEntries.add(timeEntry);

    }

    cloneWeekViewEntity(cloudWeekView, weekViewEntity);
  }
  onWeekViewEntityLoaded();
}

WeekDayEntity findWeekDayEntityInList(List<WeekDayEntity> weekDayEntities, DateTime date) {
  for (WeekDayEntity weekDayEntity in weekDayEntities) {
    if (weekDayEntity.date == date)
      return weekDayEntity;
  }
  return null;
}

Future queryForEmployeeTime(Tenant tenant, ReportEntity reportEntity, String timeSpan, EmptyArgCallback onReportDataLoaded, ArchChronosUser user, String selectedEmployee, List<ArchChronosUser> archChronosUsers) async
{

  reportEntity.selectedPayday = new DateTime.fromMillisecondsSinceEpoch(tenant.paydayUtcMillisSinceEpoch, isUtc: true);

  // determine the data to grab based on the time span
  int startDateEpoch = determineStartDateEpoch(reportEntity.date, timeSpan, reportEntity.selectedPayday);

  reportEntity.userReportLines.clear();

  if (user.isAdmin)
  {
    // refresh users
    await loadArchChronosUsers(tenant, archChronosUsers);

    for (ArchChronosUser archChronosUser in archChronosUsers)
    {
      if (selectedEmployee == "All" && archChronosUser.isTimeEntryRequired == true ||
          (archChronosUser.displayName == selectedEmployee  && archChronosUser.isTimeEntryRequired == true))
      {
        UserReportLine url = await processMapEntry(tenant, archChronosUser, startDateEpoch, timeSpan, reportEntity.date, reportEntity.weekDayEntities);
        if (!userReportLineExists(reportEntity.userReportLines, url))
          reportEntity.userReportLines.add(url);
      }
    }
  }
  else {
    if (user.isTimeEntryRequired == true)
    {
      String displayName = user.displayName;
      if (displayName == null)
        displayName = user.emailAddress;
      UserReportLine url = await processMapEntry(tenant, user, startDateEpoch, timeSpan, reportEntity.date, reportEntity.weekDayEntities);
      if (!userReportLineExists(reportEntity.userReportLines, url))
        reportEntity.userReportLines.add(url);

    }
  }

  reportEntity.userReportLines.sort((a, b) => a.user.displayName.compareTo(b.user.displayName));

  onReportDataLoaded();
}

Future loadArchChronosUsers(Tenant tenant, List<ArchChronosUser> archChronosUsers) async
{
  archChronosUsers.clear();

  CollectionReference usersRef = firestoreDB.collection("tenants").
  document(tenant.tenantID).collection("users");

  QuerySnapshot usersSnapshot = await usersRef.where("isEnabled", isEqualTo: true).getDocuments();
  if (usersSnapshot != null) {
    for (DocumentSnapshot userDoc in usersSnapshot.documents) {
      // add all users to the global user list
      ArchChronosUser archChronosUser = generateArchChronosUserFromDocumentSnapshot(userDoc);
      if (archChronosUser.isTimeEntryRequired == true)
        archChronosUsers.add(archChronosUser);
    }
  }
}

Future loadAllArchChronosUsers(String tenantID, List<ArchChronosUser> archChronosUsers) async
{
  archChronosUsers.clear();

  CollectionReference usersRef = firestoreDB.collection("tenants").
  document(tenantID).collection("users");

  QuerySnapshot usersSnapshot = await usersRef.getDocuments();
  if (usersSnapshot != null) {
    for (DocumentSnapshot userDoc in usersSnapshot.documents) {
      // add all users to the global user list
      ArchChronosUser archChronosUser = generateArchChronosUserFromDocumentSnapshot(userDoc);
      archChronosUsers.add(archChronosUser);
    }
  }
}

ArchChronosUser generateArchChronosUserFromDocumentSnapshot(DocumentSnapshot userDoc)
{
  String displayName = userDoc.data["displayName"];
  if (displayName == null)
    displayName = userDoc["emailAddress"];

  ArchChronosUser archChronosUser = new ArchChronosUser(displayName);

  archChronosUser.uid = userDoc.data["uid"];
  archChronosUser.isTimeEntryRequired = userDoc.data["isTimeEntryRequired"];
  archChronosUser.isVacationAccumulated = userDoc.data["isVacationAccumulated"];
  archChronosUser.isAdmin = userDoc.data["isAdmin"];
  archChronosUser.emailAddress = userDoc.data["emailAddress"];
  archChronosUser.messagingToken = userDoc.data["messagingToken"];

  if (userDoc.data["bankedTimeBalance"] != null)
    archChronosUser.bankedTimeBalance = double.parse(userDoc.data["bankedTimeBalance"].toString());
  else
    archChronosUser.bankedTimeBalance = 0.0;

  if (userDoc.data["vacationBalance"] != null)
    archChronosUser.vacationBalance = double.parse(userDoc.data["vacationBalance"].toString());
  else
    archChronosUser.vacationBalance = 0.0;

  if (userDoc.data["vacationRate"] != null)
    archChronosUser.vacationRate = double.parse(userDoc.data["vacationRate"].toString());
  else
    archChronosUser.vacationRate = 0.0;

  return archChronosUser;
}

bool userReportLineExists(List<UserReportLine> reportEntityLines, UserReportLine url)
{
  for (UserReportLine userReportLine in reportEntityLines)
  {
    if (userReportLine.user.uid == url.user.uid)
    {
      return true;
    }
  }
  return false;
}

Future<UserReportLine> processMapEntry(Tenant tenant, ArchChronosUser user, int startDateEpoch, String timeSpan, DateTime date, List<WeekDayEntity> weekDayEntities) async {

  if (user.displayName == null || user.displayName == "")
  {
    user.displayName = user.emailAddress;
  }

  UserReportLine userReportLine = new UserReportLine(user);

  int endDateEpoch = determineEndDateEpoch(date, startDateEpoch, timeSpan);

  CollectionReference timeEntriesRef = firestoreDB.collection("tenants").
  document(tenant.tenantID).collection("users").document(user.uid).collection("timeentries");

  QuerySnapshot snapshot;
  if (timeSpan == "Day")
    snapshot = await timeEntriesRef.where("utcSecsSinceEpoch", isEqualTo: startDateEpoch).getDocuments();
  else
    snapshot = await timeEntriesRef.where("utcSecsSinceEpoch", isGreaterThanOrEqualTo: startDateEpoch, isLessThanOrEqualTo: endDateEpoch).getDocuments();

  if (snapshot != null) {

    WeekViewEntity cloudWeekView = new WeekViewEntity(new List<WeekDayEntity>());
    for (DocumentSnapshot timeEntryDoc in snapshot.documents)
    {
      DateTime wdemDate = new DateTime.fromMillisecondsSinceEpoch(timeEntryDoc.data["utcSecsSinceEpoch"], isUtc: true);
      WeekDayEntity cloudWeekDayEntity = findWeekDayEntityInList(cloudWeekView.weekDayEntities, wdemDate);
      if (cloudWeekDayEntity != null)
        cloudWeekDayEntity = cloudWeekView.weekDayEntities.elementAt(cloudWeekView.weekDayEntities.indexOf(cloudWeekDayEntity));
      else
      {
        cloudWeekDayEntity = new WeekDayEntity(wdemDate);
        cloudWeekView.weekDayEntities.add(cloudWeekDayEntity);
      }

      if ((timeSpan == "Day" && wdemDate == date) || timeSpan != "Day") {

        TimeEntry timeEntry = new TimeEntry();
        timeEntry.timeWorkedOrAway = timeEntryDoc.data["timeWorkedOrAway"];
        timeEntry.startTime = timeEntryDoc.data["startTime"];
        timeEntry.endTime = timeEntryDoc.data["endTime"];
        timeEntry.timeAmount = timeEntryDoc.data["timeAmount"].toDouble();
        timeEntry.unpaidBreak = timeEntryDoc.data["unpaidBreak"];
        timeEntry.timeType = timeEntryDoc.data["timeType"];
        timeEntry.comments = timeEntryDoc.data["comments"];
        timeEntry.hoursBanked = timeEntryDoc.data["hoursBanked"];
        timeEntry.utcSecsSinceEpoch = timeEntryDoc.data["utcSecsSinceEpoch"];

        cloudWeekDayEntity.timeEntries.add(timeEntry);
      }
    }
    setUserReportLineValues(cloudWeekView, userReportLine);
  }

  return userReportLine;
}

void setUserReportLineValues(WeekViewEntity weekViewEntity, UserReportLine userReportLine)
{
  double totalRegularTime = 0.0;
  double totalOvertime = 0.0;
  double totalStatHolidayWorked = 0.0;
  double totalVacationTime = 0.0;
  double totalSickTime = 0.0;
  double totalStatHoliday = 0.0;
  double totalUnpaidLeave = 0.0;
  double totalTimeToBank = 0.0;
  double totalTimeFromBank = 0.0;
  double totalPaid = 0.0;
  double totalUnpaid = 0.0;

  for(WeekDayEntity weekDayEntity in  weekViewEntity.weekDayEntities) {
    for (TimeEntry timeEntry in weekDayEntity.timeEntries) {
      if (timeEntry.timeType == 'Regular Time')
        totalRegularTime += timeEntry.timeAmount;
      else if (timeEntry.timeType == 'Overtime')
        totalOvertime += timeEntry.timeAmount;
      else if (timeEntry.timeType == 'Stat Holiday Worked')
        totalStatHolidayWorked += timeEntry.timeAmount;
      else if (timeEntry.timeType == 'Vacation')
        totalVacationTime += timeEntry.timeAmount;
      else if (timeEntry.timeType == 'Sick Time')
        totalSickTime += timeEntry.timeAmount;
      else if (timeEntry.timeType == 'Stat Holiday')
        totalStatHoliday += timeEntry.timeAmount;
      else if (timeEntry.timeType == 'Unpaid Leave')
        totalUnpaidLeave += timeEntry.timeAmount;
      else if (timeEntry.timeType == 'From Bank')
        totalTimeFromBank += timeEntry.timeAmount;

      double toBank = 0.0;
      if (timeEntry.hoursBanked != null)
        toBank = double.parse(timeEntry.hoursBanked.split(" ")[0]);
      if (toBank > 0)
      {
        totalUnpaid += toBank;
      }
      else
      {
        if (timeEntry.timeType == "Unpaid Leave")
          totalUnpaid += timeEntry.timeAmount;
        else
          totalPaid += timeEntry.timeAmount;
      }

      totalTimeToBank += toBank;
    }
  }

  userReportLine.regularTime = totalRegularTime;
  userReportLine.overtime = totalOvertime;
  userReportLine.statHolidayWorked = totalStatHolidayWorked;
  userReportLine.vacationTime = totalVacationTime;
  userReportLine.sickTime = totalSickTime;
  userReportLine.statHoliday = totalStatHoliday;
  userReportLine.unpaidLeave = totalUnpaidLeave;
  userReportLine.timeFromBank = totalTimeFromBank;
  userReportLine.timeToBank = totalTimeToBank;
  userReportLine.totalPaid = totalPaid;
  userReportLine.totalUnpaid = totalUnpaid;
  userReportLine.weekViewEntity = weekViewEntity;
}

int determineStartDateEpoch(DateTime date, String timeSpan, DateTime selectedPayday)
{
  int startDateEpoch = 0;
  if (timeSpan == "Day")
  {
    startDateEpoch = date.millisecondsSinceEpoch;
  }
  else if (timeSpan == "Week")
  {
    startDateEpoch = determineStartDateTime(date).millisecondsSinceEpoch;
  }
  else if (timeSpan == "Pay Period")
  {
    // from the date passed, determine the pay period start
    startDateEpoch = calculatePayPeriodStart(date, selectedPayday).millisecondsSinceEpoch;
  }
  else
  {
    startDateEpoch = DateTime
          .parse(new DateFormat("yyyy-01-01 00:00:00").format(new DateTime(date.year, 1, 1, 0, 0, 0).toUtc()))
          .toUtc().millisecondsSinceEpoch;
  }

  return startDateEpoch;
}

int determineEndDateEpoch(DateTime date, int startDateEpoch, String timeSpan)
{
  int endDateEpoch = 0;

  if (timeSpan == "Day")
    endDateEpoch = startDateEpoch;
  else if (timeSpan == "Week")
    endDateEpoch = new DateTime.fromMillisecondsSinceEpoch(startDateEpoch, isUtc: true).add(new Duration(days: 6)).millisecondsSinceEpoch;
  else if (timeSpan == "Pay Period")
    endDateEpoch = new DateTime.fromMillisecondsSinceEpoch(startDateEpoch, isUtc: true).add(new Duration(days: 13)).millisecondsSinceEpoch;
  else if (timeSpan == "YTD") {
    endDateEpoch = DateTime
          .parse(new DateFormat("yyyy-12-31 00:00:00").format(new DateTime(date.year, 1, 1, 1, 0, 0).toUtc()))
          .toUtc().millisecondsSinceEpoch;
  }

  return endDateEpoch;
}

DateTime calculatePayPeriodStart(DateTime date, DateTime selectedPayday)
{
  DateTime ppStartDate;
  Duration dateDiff = selectedPayday.difference(date);
  int diffDays = dateDiff.inDays;
  int remainderDays = diffDays.remainder(14);
  if (remainderDays > 0)
  {
    ppStartDate = date.add(new Duration(days: remainderDays)).subtract(new Duration(days: 20,));
  }
  else
  {
    if (remainderDays > -8)
      ppStartDate = date.add(new Duration(days: remainderDays)).subtract(new Duration(days: 6,));
    else
      ppStartDate = date.add(new Duration(days: remainderDays)).add(new Duration(days: 8,));
  }

  return ppStartDate;
}

DateTime getCurrentDaySetToMidnightInUTC()
{
  DateTime now = new DateTime.now().toUtc();
  String nowString = new DateFormat("yyyy-MM-dd 00:00:00+00:00").format(now);

  return DateTime.parse(nowString);
}

DateTime convertDateTimeToUTC(DateTime value)
{
  String nowString = new DateFormat("yyyy-MM-dd 00:00:00+00:00").format(new DateTime.utc(value.year, value.month, value.day));

  return DateTime.parse(nowString);
}

int calculateHourDiff(String toTime, String fromTime)
{
  int toTmHour = int.parse(toTime.split(" ")[0].split(":")[0]);
  if (toTmHour == 12)
    toTmHour = 0;
  String toAmPm = toTime.split(" ")[1];

  int fromTmHour = int.parse(fromTime.split(" ")[0].split(":")[0]);
  if (fromTmHour == 12)
    fromTmHour = 0;
  String fromAmPm = fromTime.split(" ")[1];

  int hourDiff = 0;
  if (toAmPm == "PM")
    toTmHour = toTmHour + 12;
  if (fromAmPm == "PM")
    fromTmHour = fromTmHour + 12;

  hourDiff = toTmHour - fromTmHour;

  return hourDiff;
}

int calculateMinuteDiff(String toTime, String fromTime)
{
  String toTm = toTime.split(" ")[0];
  String fromTm = fromTime.split(" ")[0];

  int minuteDiff = int.parse(toTm.split(":")[1]) - int.parse(fromTm.split(":")[1]);

  return minuteDiff;
}

String generateTimeTypeAcronym(TimeEntry timeEntry) {
  String ttAcronym = "";

  if (timeEntry.timeWorkedOrAway == "Time Worked") {
    if (timeEntry.timeType == 'Regular Time')
      ttAcronym = "RT";
    else if (timeEntry.timeType == 'Overtime')
      ttAcronym = "OT";
    else if (timeEntry.timeType == 'Stat Holiday')
      ttAcronym = "SHW";
  }
  else
  {
    if (timeEntry.timeType == 'Vacation')
      ttAcronym = "VT";
    else if (timeEntry.timeType == 'Sick Time')
      ttAcronym = "ST";
    else if (timeEntry.timeType == 'Stat Holiday')
      ttAcronym = "SH";
    else if (timeEntry.timeType == 'From Bank')
      ttAcronym = "FB";
  }

  return ttAcronym;
}

formatTimeFromDoubleToString(double timeAmount)
{
    String timeAmountString = timeAmount.toInt().toString() + "h ";

    double remainder = timeAmount - timeAmount.floor();
    if (remainder == 0.00)
      timeAmountString = timeAmountString + " 0m";
    if (remainder == 0.25)
      timeAmountString = timeAmountString + " 15m";
    else if (remainder == 0.5)
      timeAmountString = timeAmountString + " 30m";
    else if (remainder == 0.75)
      timeAmountString = timeAmountString + " 45m";

    return timeAmountString;
}

ArchChronosUser initArchChronosUserFromMap(String displayName, Map archChronosUserMap)
{

  ArchChronosUser archChronosUser = new ArchChronosUser(displayName);

  archChronosUser.tenantId = archChronosUserMap["tenantId"];
  archChronosUser.isAdmin = archChronosUserMap["isAdmin"];
  archChronosUser.isTimeEntryRequired = archChronosUserMap["isTimeEntryRequired"];
  archChronosUser.isVacationAccumulated = archChronosUserMap["isVacationAccumulated"];
  archChronosUser.isEnabled = archChronosUserMap["isEnabled"];
  archChronosUser.displayName = archChronosUserMap["displayName"];
  archChronosUser.uid = archChronosUserMap["uid"];
  archChronosUser.emailAddress = archChronosUserMap["emailAddress"];
  archChronosUser.providerId = archChronosUserMap["providerId"];
  archChronosUser.password = archChronosUserMap["password"];
  archChronosUser.messagingToken = archChronosUserMap["messagingToken"];

  if (archChronosUserMap["bankedTimeBalance"] != null)
    archChronosUser.bankedTimeBalance = double.parse(archChronosUserMap["bankedTimeBalance"].toString());
  else
    archChronosUser.bankedTimeBalance = 0.0;

  if (archChronosUserMap["vacationBalance"] != null)
    archChronosUser.vacationBalance = double.parse(archChronosUserMap["vacationBalance"].toString());
  else
    archChronosUser.vacationBalance = 0.0;

  if (archChronosUserMap["vacationRate"] != null)
    archChronosUser.vacationRate = double.parse(archChronosUserMap["vacationRate"].toString());
  else
    archChronosUser.vacationRate = 0.0;

  return archChronosUser;
}

Message initMessageFromMap(Map archChronosMessageMap)
{
  Message message = new Message();

  message.message = archChronosMessageMap["message"];
  message.sender = archChronosMessageMap["sender"];
  message.senderUID = archChronosMessageMap["senderUID"];
  message.recipientNames = archChronosMessageMap["recipientNames"];
  message.recipientUIDs = archChronosMessageMap["recipientUIDs"];
  message.direction = archChronosMessageMap["direction"];
  message.timestamp = archChronosMessageMap["timestamp"];
  message.conversationWithNames = archChronosMessageMap["conversationWithNames"];
  message.conversationWithUIDs = archChronosMessageMap["conversationWithUIDs"];
  message.utcMillisSinceEpoch = archChronosMessageMap["utcMillisSinceEpoch"];
  message.hasBeenRead = archChronosMessageMap["hasBeenRead"];

  return message;
}

Tenant initTenantFromMap(Map tenantMap)
{
  Tenant tenant = new Tenant();

  tenant.tenantCode = tenantMap["tenantCode"];
  tenant.contactEmailAddress = tenantMap["contactEmailAddress"];
  tenant.contactPhoneNumber = tenantMap["contactPhoneNumber"];
  tenant.isEnabled = tenantMap["isEnabled"];
  tenant.paydayUtcMillisSinceEpoch = tenantMap["paydayUtcMillisSinceEpoch"];
  tenant.tenantName = tenantMap["tenantName"];

  return tenant;
}

bool sendMessage(String tenantID,
    Set<ArchChronosUser> selectedRecipients,
    String notificationType,
    String message,
    ArchChronosUser senderArchChronosUser,
    String conversationWithNames,
    String conversationWithUIDs)
{
  try {

    String tokens = "";
    String recipientNames = "";
    String recipientUIDs = "";

    for (ArchChronosUser archChronosUser in selectedRecipients) {
      if (tokens.length == 0) {
        tokens = archChronosUser.messagingToken;
        recipientNames = archChronosUser.displayName;
        recipientUIDs = archChronosUser.uid;
      }
      else {
        tokens = tokens + "|" + archChronosUser.messagingToken;
        recipientNames = recipientNames + "," + archChronosUser.displayName;
        recipientUIDs = recipientUIDs + "," + archChronosUser.uid;
      }
    }

    DateTime nowDT =new DateTime.now().toUtc();
    String timestamp = (new DateFormat("yyyy-MM-dd hh:mm:ss").format(nowDT));
    int millisecondsSinceEpoch = nowDT.millisecondsSinceEpoch;

    Notification notification = new Notification();

    notification.notificationType = notificationType;
    notification.message = message;
    notification.tokens = tokens;
    notification.sender = senderArchChronosUser.displayName;
    notification.senderUID = senderArchChronosUser.uid;
    notification.timestamp = timestamp;

    firestoreDB.collection('tenants').document(tenantID).collection("notifications").add(notification.toJson());

    Message msgFromSender = new Message();
    msgFromSender.message = message;
    msgFromSender.sender = senderArchChronosUser.displayName;
    msgFromSender.senderUID = senderArchChronosUser.uid;
    msgFromSender.recipientNames = recipientNames;
    msgFromSender.recipientUIDs = recipientUIDs;
    msgFromSender.direction = "outgoing";
    msgFromSender.timestamp = timestamp;
    msgFromSender.conversationWithNames = conversationWithNames;
    msgFromSender.conversationWithUIDs = conversationWithUIDs;
    msgFromSender.utcMillisSinceEpoch = millisecondsSinceEpoch;
    msgFromSender.hasBeenRead = true;

    firestoreDB.collection('tenants').document(tenantID).collection("users").document(senderArchChronosUser.uid).collection("messages").add(msgFromSender.toJson());

    for (ArchChronosUser archChronosUser in selectedRecipients) {

      Message msgToRecipient = new Message();
      msgToRecipient.message = message;
      msgToRecipient.sender = senderArchChronosUser.displayName;
      msgToRecipient.senderUID = senderArchChronosUser.uid;
      msgToRecipient.recipientNames = recipientNames;
      msgToRecipient.recipientUIDs = recipientUIDs;
      msgToRecipient.direction = "incoming";
      msgToRecipient.timestamp = timestamp;
      msgToRecipient.conversationWithNames = conversationWithNames;
      msgToRecipient.conversationWithUIDs = conversationWithUIDs;
      msgToRecipient.utcMillisSinceEpoch = millisecondsSinceEpoch;
      msgToRecipient.hasBeenRead = false;

      firestoreDB.collection('tenants').document(tenantID).collection(
          "users").document(archChronosUser.uid)
          .collection("messages")
          .add(msgToRecipient.toJson());
    }

    return true;
  }
  catch(exception)
  {
    print(exception.toString());
    return false;
  }
}

Future saveMessage(ArchChronosUser archChronosUser, Message message) async
{
  firestoreDB.collection('tenants').document(archChronosUser.tenantId).collection("users").document(archChronosUser.uid).collection("messages").document(message.firestoreKey).setData(message.toJson(), merge: true);
}

String removeSelfFromNames(String names, String uids, ArchChronosUser archChronosUser) {

  String recipientNamesWithSelfRemoved = "";

  List<String> uidList = uids.split(",");
  if (uidList.length == 1)
    return names;

  List<String> nameList = names.split(",");
  if (nameList.length != uidList.length)
    return "";

  int index = 0;
  for(String uid in uidList)
  {
    if (uid != archChronosUser.uid)
    {
      if (recipientNamesWithSelfRemoved.length == 0)
        recipientNamesWithSelfRemoved = nameList.elementAt(index);
      else
        recipientNamesWithSelfRemoved = recipientNamesWithSelfRemoved + "," + nameList.elementAt(index);
    }
    index++;
  }

  return recipientNamesWithSelfRemoved;
}

String removeSelfFromUIDs(String uids, ArchChronosUser archChronosUser) {

  String recipientUIDsWithSelfRemoved = "";

  List<String> uidList = uids.split(",");
  if (uidList.length == 1)
    return uids;

  for(String uid in uidList)
  {
    if (uid != archChronosUser.uid)
    {
      if (recipientUIDsWithSelfRemoved.length == 0)
        recipientUIDsWithSelfRemoved = uid;
      else
        recipientUIDsWithSelfRemoved = recipientUIDsWithSelfRemoved + "," + uid;
    }
  }

  return recipientUIDsWithSelfRemoved;
}

String formatNamesForDisplay(String names) {

  String formattedNames = "";

  List<String> namesList = names.split(",");
  if (namesList.length == 1)
    return names;

  for(String name in namesList)
  {

    if (formattedNames.length == 0)
      formattedNames = name;
    else
      formattedNames = formattedNames + ", " + name;

  }

  return formattedNames;
}

String pullFirstLetterFromNames(String names) {

  String nameFirstLetters = "";

  List<String> namesList = names.split(",");
  if (namesList.length == 1)
    return names.substring(0,1);

  for(String name in namesList)
  {

    if (nameFirstLetters.length == 0)
      nameFirstLetters = name.substring(0,1);
    else
      nameFirstLetters = nameFirstLetters + ", " + name.substring(0,1);

  }

  return nameFirstLetters;
}