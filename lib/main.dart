import 'package:flutter/material.dart';
import 'package:flutter_first/test/gui/model/item.dart';
import 'package:flutter_first/test/gui/page/babloz_test_page.dart';
import 'package:flutter_first/test/gui/page/raw_test_page.dart';
import 'package:flutter_first/test/gui/widget/main_item_widget.dart';

import 'main.reflectable.dart';

void main() {
  initializeReflectable(); //flutter packages pub run build_runner build

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  // This widget is the root of your application.

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  var routes = <String, WidgetBuilder>{
    '/test': (BuildContext context) => MyHomePage(),
    testRawRoute: (BuildContext context) => RawTestPage(),
    testRawBabloz: (BuildContext context) => BablozTestPage(),
  };
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Sqflite Demo',
        theme: ThemeData(
          // This is the theme of your application.
          //
          // Try running your application with "flutter run". You'll see
          // the application has a blue toolbar. Then, without quitting
          // the app, try changing the primarySwatch below to Colors.green
          // and then invoke "hot reload" (press "r" in the console where
          // you ran "flutter run", or press Run > Hot Reload App in IntelliJ).
          // Notice that the counter didn't reset back to zero -- the application
          // is not restarted.
          primarySwatch: Colors.blue,
        ),
        home: MyHomePage(title: 'Sqflite Demo Home Page'),
        routes: routes);
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key) {
    final List<MainItem> it = [
      MainItem("Raw tests", "Raw SQLite operations", route: testRawRoute),
      MainItem("Babloz tests", "Babloz SQLite operations", route: testRawBabloz)
    ];

    items.addAll(it);

    // Uncomment to view all logs
    //Sqflite.devSetDebugModeOn(true);
  }

  final List<MainItem> items = [];
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

const String testRawRoute = "/test/simple";
const String testRawBabloz = "/test/babloz";

class _MyHomePageState extends State<MyHomePage> {
  int get _itemCount => widget.items.length;

  @override
  void initState() {
    super.initState();
    //initPlatformState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Center(child: Text('Sqflite demo', textAlign: TextAlign.center)),
        ),
        body: ListView.builder(itemBuilder: _itemBuilder, itemCount: _itemCount));
  }

  //new Center(child: new Text('Running on: $_platformVersion\n')),

  Widget _itemBuilder(BuildContext context, int index) {
    return MainItemWidget(widget.items[index], (MainItem item) {
      Navigator.of(context).pushNamed(item.route);
    });
  }
}

/*
class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;

      accountTest();
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug painting" (press "p" in the console, choose the
          // "Toggle Debug Paint" action from the Flutter Inspector in Android
          // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
          // to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.display1,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
*/
