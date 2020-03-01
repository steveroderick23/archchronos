import 'package:flutter/material.dart';
import 'package:collection/collection.dart' show lowerBound;
import 'package:intl/intl.dart';
import 'common.dart';
import 'timeEntryDialog.dart';

enum DialogDemoAction {
  cancel,
  discard,
  disagree,
  agree,
}

class WeekView extends StatefulWidget {

  WeekView(
      this.tenantID,
      this.weekViewEntity,
      this.dateRangeString,
      this.onMoveWeekBack,
      this.onMoveWeekAhead,
      this.onWeekDayEntityUpdated,
      this.user,
      this.onWeekViewEntityUpdated,
      {Key key})
      : super(key: key);

  final String tenantID;
  final WeekViewEntity weekViewEntity;
  final String dateRangeString;
  final MoveWeekCallback onMoveWeekBack;
  final MoveWeekCallback onMoveWeekAhead;
  final WeekDayEntityCallback onWeekDayEntityUpdated;
  final EmptyArgCallback onWeekViewEntityUpdated;
  final ArchChronosUser user;

  @override
  WeekViewContentsState createState() => new WeekViewContentsState(
      weekViewEntity, onMoveWeekBack, onMoveWeekAhead, onWeekDayEntityUpdated);
}

class WeekViewContentsState extends State<WeekView> {
  WeekViewContentsState(
      this._weekViewEntity, this._onMoveWeekBack, this._onMoveWeekAhead, this._onWeekDayEntityUpdated);

  WeekViewEntity _weekViewEntity;
  final MoveWeekCallback _onMoveWeekBack;
  final MoveWeekCallback _onMoveWeekAhead;
  final WeekDayEntityCallback _onWeekDayEntityUpdated;

  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  var formatter = new DateFormat('EEE MMM d');

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return new Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.black,
      body: new Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          new Expanded(
            flex: 2,
            child: new Card(
              child: new Center(
                child: new Row (
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    new Container(
                      padding: const EdgeInsets.only(
                        right: 3.0,
                        left: 7.0,
                      ),
                      child: new IconButton(
                        icon: new Icon(Icons.arrow_left, color: Colors.blue, size: 32.0),
                        onPressed: _onMoveWeekBack,
                      ),
                    ),
                    new Expanded(
                      child:
                        new Container(
                          alignment: FractionalOffset.center,
                          child: new DatePicker(
                            selectedDate: widget.weekViewEntity.date,
                            selectDate: (DateTime date) {
                              setState(() {
                                setupWeekViewEntity(widget.weekViewEntity, date);
                                pullWeekViewEntityFromCloud(widget.tenantID, widget.weekViewEntity, widget.user.uid, _onWeekDayEntityUpdated);
                              });
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
                        onPressed: _onMoveWeekAhead,
                      ),
                    ),
                  ]
                ),
              ),
            ),
          ),
          new Expanded(
            flex: 14,
            child: new Card(
              child: new Center(
                child: new ListView(
                  children:
                      buildWeekDayItems(_weekViewEntity.weekDayEntities, context).toList(),
                ),
              ),
            ),
          ),

        ],
      )
    );
  }

  Widget buildTimeEntry(WeekDayEntity weekDayEntity) {

    List<Widget> widgets = new List<Widget>();

    for (TimeEntry timeEntry in weekDayEntity.timeEntries) {
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
      String timeStr = "";
      if (timeEntry.startTime != null)
        timeStr = timeEntry.startTime.toString() + "-" + timeEntry.endTime.toString();

      Column timeEntryCol = new Column(
        children: <Widget>[
          new Text(
            timeStr,
            style: new TextStyle(
              fontSize: 7.0,
            ),
          ),
          icon,
          new Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children:  [
              new Column(
                children: [
                  new Text(
                    timeEntry.timeAmount.toString(),
                    style: new TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 8.0,
                    ),
                  ),
                ]
              ),
              new Container(
                padding: const EdgeInsets.only(
                right: 2.0,
                left: 2.0,
                ),
                child: new Column(
                  children: [
                    new Text(
                      generateTimeTypeAcronym(timeEntry),
                      style: new TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 8.0,
                      ),
                    ),
                  ]
                ),
              ),
              new Container(
                padding: const EdgeInsets.only(
                  right: 2.0,
                  left: 2.0,
                ),
                child: new Column(
                    children: [
                      new Text(
                        generateBankedTimeOutput(timeEntry),
                        style: new TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 8.0,
                        ),
                      ),
                    ]
                ),
              ),
            ]
          )
        ],
      );

      widgets.add(timeEntryCol);

    }

    if (weekDayEntity.timeEntries.length > 0)
    {
      Column timeTotalCol = new Column(
        children: <Widget>[
          new Text(
            " ",
            style: new TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 8.0,
            ),
          ),
          new Icon (Icons.today),
          new Row(
              children:  [
                new Text(
                  calculateTotalHours(weekDayEntity).toString(),
                  style: new TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.0,
                  ),
                ),
              ]
          )
        ],
      );

      widgets.add(timeTotalCol);
    }

    return new Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        new Expanded(
          flex: 15,
          child: new Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: widgets,
          ),
        ),
        buildClearIcon(weekDayEntity.timeEntries, weekDayEntity),
      ]
    );
  }

  String generateTimeTypeAcronym(TimeEntry timeEntry)
  {
    String ttAcronym = "";

    if (timeEntry.timeType == 'Regular Time')
      ttAcronym = "RT";
    else if (timeEntry.timeType == 'Overtime')
      ttAcronym = "OT";
    else if (timeEntry.timeType == 'Stat Holiday Worked')
      ttAcronym = "SHW";
    else if (timeEntry.timeType == 'Vacation')
      ttAcronym = "VT";
    else if (timeEntry.timeType == 'Sick Time')
      ttAcronym = "ST";
    else if (timeEntry.timeType == 'Stat Holiday')
      ttAcronym = "SH";
    else if (timeEntry.timeType == 'Unpaid Leave')
      ttAcronym = "UPL";

    return ttAcronym;
  }

  String generateBankedTimeOutput(TimeEntry timeEntry)
  {
    if (timeEntry.hoursBanked == '0.0 H')
      return "";
    else
      return "BT: " + timeEntry.hoursBanked;
  }

  Widget buildClearIcon(List<TimeEntry> timeEntryList, WeekDayEntity weekDayEntity)  {

    Widget widget;
    if (timeEntryList.length > 0)
    {
      widget = new Expanded(
        flex: 2,
        child: new IconButton(
          icon: new Icon(
            Icons.delete,
            color: Colors.red,
          ),
          onPressed: () {
            weekDayEntity.timeEntries.clear();
            _onWeekDayEntityUpdated();
          },
        ),
      );
    }
    else
    {
      widget = new Text("");
    };
    return widget;
  }

  void showPopupDialog<T>({ BuildContext context, Widget child }) {
    showDialog<T>(
      barrierDismissible: false,
      context: context,
      child: child,
    );
  }
  
  Iterable<Widget> buildWeekDayItems(List<WeekDayEntity> weekDayEntities, BuildContext context) {

    List<ListTile> listTiles = new List<ListTile>();
    for (var weekDayEntity in weekDayEntities) {
      listTiles.add(new ListTile(
        leading: new Text(
          formatter.format(weekDayEntity.date),
          style: new TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 10.0,
            color: Colors.black,
          ),
        ),
        title: buildTimeEntry(weekDayEntity),
        onTap: () {
          _weekViewEntity.date = weekDayEntity.date;
          for (var viewWeekDayEntity in _weekViewEntity.weekDayEntities) {
            if (viewWeekDayEntity.date == weekDayEntity.date)
              viewWeekDayEntity.selected = true;
            else
              viewWeekDayEntity.selected = false;
          }
          if (isDateInTheFuture(weekDayEntity.date))
          {
            final ThemeData theme = Theme.of(context);
            final TextStyle dialogTextStyle = theme.textTheme.subhead.copyWith(color: theme.textTheme.caption.color);
            showPopupDialog<DialogDemoAction>(
                context: context,
                child: new AlertDialog(
                    content: new Text(
                        "Cannot enter time for future dates.",
                        style: dialogTextStyle
                    ),
                    actions: <Widget>[
                      new FlatButton(
                          child: const Text('OK'),
                          onPressed: () { Navigator.pop(context, DialogDemoAction.cancel); }
                      ),
                    ]
                )
            );
            return;
          }
          else
          {
            Navigator.push(context, new MaterialPageRoute<DismissDialogAction>(
              builder: (BuildContext context) => new TimeEntryDialog(weekDayEntity, _onWeekDayEntityUpdated, widget.user),
              fullscreenDialog: true,
            ));
          }

        }
      ));
    }

    return ListTile.divideTiles(tiles: listTiles, color: Colors.black);

  }

  void handleUndo(WeekDayEntity item) {
    final int insertionIndex = lowerBound(_weekViewEntity.weekDayEntities, item);
    setState(() {
      _weekViewEntity.weekDayEntities.insert(insertionIndex, item);
    });
  }
}
