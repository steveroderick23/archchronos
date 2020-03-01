import 'common.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'editUserDialog.dart';

class LinkTextSpan extends TextSpan {
  LinkTextSpan({TextStyle style, String url, String text})
      : super(
            style: style,
            text: text ?? url,
            recognizer: new TapGestureRecognizer()..onTap = () {});
}

class ArchChronosDrawer extends StatelessWidget {
  ArchChronosDrawer({ Key key,
        this.onlogoutTapped,
        this.onChangeRouteTapped,
        this.onSaveArchchronosUser,
        this.archChronosUser,
        this.companyName}) : super(key: key);

  final EmptyArgCallback onlogoutTapped;
  final BuildContextCallback onChangeRouteTapped;
  final SaveArchChronosUserCallback onSaveArchchronosUser;
  ArchChronosUser archChronosUser;
  String companyName;

  @override
  Widget build(BuildContext context) {

    final List<Widget> allDrawerItems = buildWidgetList(context);

    return new Drawer(child: new ListView(primary: false, children: allDrawerItems));
  }

//    launchWebView() {
//
//    String pdf = "http://kamsrv.poleymountain.com/kbs/site/printReceipt?d=oL8u1QzyTWxjQLhMDJVeptrnc7xB3B%2FSem9gBSgb6uxVUyMA9gBngpJak5d0ZaKoCAfrn4fE8EuNl1dm93J4faSrt6yTgSESw0QbSBT2m8lFNSK4Yo6FFREWVG%2FgDT99&v=dqYPL5H2oMO6KqfRp6bmcQ%3D%3D";
//    String url = 'http://drive.google.com/viewerng/viewer?embedded=true&url=' + pdf;
//    //flutterWebviewPlugin.launch(url);
//  }
//
//  _launchURL() async {
//    const url = 'http://kamsrv.poleymountain.com/kbs/site/printReceipt?d=oL8u1QzyTWxjQLhMDJVeptrnc7xB3B%2FSem9gBSgb6uxVUyMA9gBngpJak5d0ZaKoCAfrn4fE8EuNl1dm93J4faSrt6yTgSESw0QbSBT2m8lFNSK4Yo6FFREWVG%2FgDT99&v=dqYPL5H2oMO6KqfRp6bmcQ%3D%3D';
//    if (await canLaunch(url)) {
//      await launch(url);
//    } else {
//      throw 'Could not launch $url';
//    }
//  }

  List<Widget> buildWidgetList(BuildContext context)
  {
    List<Widget> widgetList = new List<Widget>();

    widgetList.add(
      new Container(
        padding: const EdgeInsets.only(
          right: 10.0,
          left: 10.0,
          top: 10.0,
          bottom: 0.0,
        ),
        child: new Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            new Image(
                image: new AssetImage(
                    'assets/arch_a.png'
                ),
                width: 64.0,
                height: 64.0,
                fit: BoxFit.scaleDown,
                alignment: FractionalOffset.center
            ),
            new Text(
              "Arch Chronos",
              style: new TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
                fontFamily: "Kalam",
                fontSize: 18.0,
              ),
            ),
          ],
        ),
      ),
    );

    widgetList.add(const Divider());

    widgetList.add(
      new Container(
        padding: const EdgeInsets.only(left: 10.0,),
        child: new Text(
          "Company: " + companyName,
          style: new TextStyle(
            fontSize: 12.0,
            fontWeight: FontWeight.normal,
          ),
        )
      )
    );

    String user = archChronosUser.displayName;
    if (user == null || user.isEmpty)
      user = archChronosUser.emailAddress;

    widgetList.add(
      new Container(
        padding: const EdgeInsets.only(left: 10.0,),
        child: new Row(
          children: [
            new Container(
              padding: const EdgeInsets.only(right: 10.0,),
              child: new Text
                (
                "User: " + user,
                style: new TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ]
        ),
      )
    );

    widgetList.add(const Divider());

    if (archChronosUser.isTimeEntryRequired == true) {
      widgetList.add(new ListTile(
        leading: new Icon(
          Icons.timer,
          color: Colors.black,
        ),
        title: new Text('Time Entry'),
        onTap: () {
          onChangeRouteTapped(context, "timeEntry", "drawer");
        },
      ));
    }

    widgetList.add(new ListTile(
      leading: new Icon(
        Icons.receipt,
        color: Colors.green,
      ),
      title: new Text('Time Reports'),
      onTap: () { onChangeRouteTapped(context, "reports", "drawer"); },
    ));

    String userMenuText = "Users";
    if (!archChronosUser.isAdmin)
    {
      userMenuText = "My Profile";
      widgetList.add(new ListTile(
        leading: new Icon(
          Icons.supervised_user_circle,
          color: Colors.black,
        ),
        title: new Text("My Profile"),
        onTap: () {
          Navigator.pop(context);
          Navigator.push(context, new MaterialPageRoute<DismissDialogAction>(
            builder: (BuildContext context) => new EditUserDialog(archChronosUser, archChronosUser, onSaveArchchronosUser),
            fullscreenDialog: true,
          ));
        },
      ));
    }
    else
    {
      widgetList.add(new ListTile(
        leading: new Icon(
          Icons.supervised_user_circle,
          color: Colors.black,
        ),
        title: new Text("Users"),
        onTap: () { onChangeRouteTapped(context, "users", "drawer"); },
      ));

    }

    widgetList.add(new ListTile(
      leading: new Icon(
        Icons.message,
        color: Colors.black,
      ),
      title: new Text("Arch Chronos Messenger"),
      onTap: () { onChangeRouteTapped(context, "allConversations", "drawer"); },
    ));

    widgetList.add(new ListTile(
      leading: new Icon(
        Icons.settings,
        color: Colors.black,
      ),
      title: new Text('Settings'),
      onTap: () { onChangeRouteTapped(context, "settings", "drawer"); },
    ));

    final ThemeData themeData = Theme.of(context);
    final TextStyle aboutTextStyle = themeData.textTheme.body2;

    widgetList.add(
      new AboutListTile(
        icon: new Image(
            image: new AssetImage(
                'assets/arch_a.png'
            ),
            width: 24.0,
            height: 24.0,
            fit: BoxFit.scaleDown,
            alignment: FractionalOffset.center
        ),
        applicationVersion: '1.1.29',
        applicationIcon: new Image(
            image: new AssetImage(
                'assets/arch_a.png'
            ),
            width: 48.0,
            height: 48.0,
            fit: BoxFit.scaleDown,
            alignment: FractionalOffset.center
        ),
        applicationLegalese: '© 2018 Spring Breeze Solutions',
        aboutBoxChildren: <Widget> [
          new Padding(
            padding: const EdgeInsets.only(top: 24.0),
            child: new RichText(
              text: new TextSpan(
                children: <TextSpan>[
                  new TextSpan(
                    style: aboutTextStyle,
                    text: "Arch Chronus - Keeping Your Business On Time .."
                  ),
                  new TextSpan(style: aboutTextStyle, text: ".")
                ]
              )
            )
          )
        ]
      ),
    );

    widgetList.add(new ListTile(
      leading: new Icon(
        Icons.person,
        color: Colors.blue,
      ),
      title: new Text('Logout'),
      onTap: onlogoutTapped,
    ));

    return widgetList;

  }
}
