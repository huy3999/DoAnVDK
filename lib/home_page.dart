import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:doan_vdk/main.dart';
import 'package:doan_vdk/authentication.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:barcode_scan/barcode_scan.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:typed_data';
import 'dart:ui';
import 'dart:io';
import 'package:doan_vdk/app_theme.dart';
import 'package:doan_vdk/model/tabIcon_data.dart';
import 'package:flutter/material.dart';
import 'package:doan_vdk/bottom_navigation_bar.dart';
import 'app_theme.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Do An VDK QR Scanner',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Do An VDK QR Scanner'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title,this.userId,this.auth, this.logoutCallback}) : super(key: key);
  final String userId;
  final String title;
  final BaseAuth auth;
  final VoidCallback logoutCallback;
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  String userId ="";
  String email = "";
  String result = "Please scan the QR code or Barcode";
  static const double _topSectionTopPadding = 50.0;
  static const double _topSectionBottomPadding = 20.0;
  static const double _topSectionHeight = 50.0;
  DateFormat dateFormat = DateFormat("yyyy-MM-dd HH:mm:ss");

  GlobalKey globalKey = new GlobalKey();
  String resultFromDB ="";
  String _dataString = "Hello from this QR";
  var plate;
  String _inputErrorText;
  final TextEditingController _textController =  TextEditingController();

  AnimationController animationController;
  List<TabIconData> tabIconsList = TabIconData.tabIconsList;
  Widget tabBody = Container(
    color: AppTheme.background,
  );

  Future _scanQR() async {
    try {
      String qrResult = await BarcodeScanner.scan();
      setState(() {
        result = qrResult;
        plate = qrResult.split('-');

      });

      //while(resultFromDB == "") {
      getInfo(plate[0]).then((val) {
        print(val);
        resultFromDB = val;
        print("from db 1:" + resultFromDB);
      });
      //}
//      if(resultFromDB == "") {
//        getInfo(plate[0]).then((val) {
//          print(val);
//          resultFromDB = val;
//          print("from db 2:" + resultFromDB);
//        });
//      }
      _dataString = result;
      print(_dataString);

      plateCheckDialog(plate);
    } on PlatformException catch (ex) {
      if (ex.code == BarcodeScanner.CameraAccessDenied) {
        setState(() {
          result = "Camera permission was denied";
        });
      } else {
        setState(() {
          result = "Unknown Error $ex";
        });
      }
    } on FormatException {
      setState(() {
        result = "You pressed the back button before scanning anything";
      });
    } catch (ex) {
      setState(() {
        result = "Unknown Error $ex";
      });
    }

  }
  Future<void> _captureAndSharePng() async {
    try {
      RenderRepaintBoundary boundary = globalKey.currentContext.findRenderObject();
      var image = await boundary.toImage();
      ByteData byteData = await image.toByteData(format: ImageByteFormat.png);
      Uint8List pngBytes = byteData.buffer.asUint8List();       final tempDir = await getTemporaryDirectory();
      final file = await new File('${tempDir.path}/image.png').create();
      await file.writeAsBytes(pngBytes);
      final channel = const MethodChannel('channel:me.alfian.share/share');
      channel.invokeMethod('shareFile', 'image.png');
    } catch(e) {
      print(e.toString());
    }
  }
Future<void> successDialog() async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Thành công'),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Text('Đã xác minh thành công'),
              Text('Mời bạn đi qua.'),
            ],
          ),
        ),
        actions: <Widget>[
          FlatButton(
            child: Text('OK'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}
  Future<void> showQRDialog() async {
    final bodyHeight = MediaQuery.of(context).size.height - MediaQuery.of(context).viewInsets.bottom;
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Vui lòng đưa QR đến trước camera'),
          content:
          Container(
            width: 300, height: 300,
            child:  Center(
              child: RepaintBoundary(
                key: globalKey,
                child: QrImage(
                  data: _dataString,
                  size: 0.5 * bodyHeight,
                ),
              ),
            ),
          ),
          actions: <Widget>[
            FlatButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
  Future<void> plateCheckDialog(var qrResult) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Biển số xe bạn là:'),
          content:
          Text(
           qrResult[0],
            style: new TextStyle(fontSize: 17.0, color: Colors.black)
        ),
          actions: <Widget>[
            FlatButton(
              child: Text('XÁC NHẬN'),
              onPressed: () {
                addStringToSF(_dataString);
                print("add to share preference: "+ _dataString);
                String code = qrResult[0]+ '-'+qrResult[1];

                //String resultFromDB = getInfo(qrResult[0]) as String;
                //String time = dateFormat.format(DateTime.now());
                //final dbRef = FirebaseDatabase.instance.reference().child("Xe");
                print("plate check: "+code );

                if(resultFromDB == code){
                FirebaseDatabase.instance.reference().child('Xe').child(qrResult[0]).child('info')
                    .update({
                  "status": 1
                });
                }
                //_dataString = result+time;
                //print(_dataString);
                //resultFromDB= "";
                Navigator.of(context).pop();

              },
            ),
            FlatButton(
              child: Text('QUÉT LẠI'),
              onPressed: () {
                FirebaseDatabase.instance.reference().child('Xe').child(qrResult[0]).child('info')
                    .update({
                  'status': 2,
                });
                _scanQR();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
  @override
  void initState() {
    super.initState();
      widget.auth.getCurrentUser().then((user) {
      setState(() {
        if (user != null) {
          userId = user?.uid;
          email = user?.email;
        }
      });
      tabIconsList.forEach((TabIconData tab) {
        tab.isSelected = false;
      });
      tabIconsList[0].isSelected = true;

      animationController = AnimationController(
          duration: const Duration(milliseconds: 600), vsync: this);
      //tabBody = MyDiaryScreen(animationController: animationController);
    });
  }
  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  Future getDB(plate) async {
    var val = await getInfo(plate);
    print(val);
    resultFromDB = val;
  }
//  @override
//  Widget build(BuildContext context) {
//    return Scaffold(
//      appBar: AppBar(
//        title: Text("Do An VDK QR Scanner"),
//        actions: <Widget>[
//            new FlatButton(
//                child: new Text('Logout',
//                    style: new TextStyle(fontSize: 17.0, color: Colors.white)),
//                onPressed: signOut)
//          ],
//
//      ),
//      body: _contentWidget(),
//      drawer: Drawer(
//        // Add a ListView to the drawer. This ensures the user can scroll
//        // through the options in the drawer if there isn't enough vertical
//        // space to fit everything.
//        child: ListView(
//          // Important: Remove any padding from the ListView.
//          padding: EdgeInsets.zero,
//          children: <Widget>[
//            DrawerHeader(
//              child: Text(
//                email,
//                style: new TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: Colors.white),
//              ),
//              decoration: BoxDecoration(
//                color: Colors.blue,
//              ),
//            ),
//            ListTile(
//              title: Text('Item 1'),
//              onTap: () {
//                // Update the state of the app
//                // ...
//                // Then close the drawer
//                Navigator.pop(context);
//              },
//            ),
//            ListTile(
//              title: Text('Item 2'),
//              onTap: () {
//                // Update the state of the app
//                // ...
//                // Then close the drawer
//                Navigator.pop(context);
//              },
//            ),
//          ],
//        ),
//      ),
//      floatingActionButton: FloatingActionButton.extended(
//        icon: Icon(Icons.camera_alt),
//        label: Text("Scan"),
//        onPressed: _scanQR,
//      ),
//      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
//    );
//  }
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: FutureBuilder<bool>(
          future: getData(),
          builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox();
            } else {
              return Stack(
                children: <Widget>[
                  _contentWidget(),
                  //tabBody,
                  bottomBar(),
                ],
              );
            }
          },
        ),
      ),
    );
  }
  _contentWidget() {
    final bodyHeight = MediaQuery.of(context).size.height - MediaQuery.of(context).viewInsets.bottom;
    return  Container(
      //color: const Color(0xFFFFFFFF),
      child:  Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(
              top: _topSectionTopPadding,
              left: 70.0,
              right: 10.0,
              bottom: _topSectionBottomPadding,
            ),
            child:  Container(
              height: 100.0,
              width: 300.0,
              child:  Column(
                mainAxisSize: MainAxisSize.max,
                //crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child:  Text(
                      "Tạo QR để qua cổng",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25),
                    )

                  ),
                  Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child:

                    SizedBox(
                      width: 120,
                      height: 100,
                      child: Container(
                        //width: 200, height: 100,
                        alignment: Alignment.topCenter,
                        color: Colors.transparent,
                        child: SizedBox(
                          width: 120,
                          height: 100,
                          child: Padding(
                            padding: const EdgeInsets.all(1.0),
                              child: Container(
                                // alignment: Alignment.center,s
                                decoration: BoxDecoration(
                                  color: AppTheme.nearlyDarkBlue,
                                  gradient: LinearGradient(
                                      colors: [
                                        AppTheme.nearlyDarkBlue,
                                        //Color(#6A88E5),
                                        Color.fromRGBO(106, 136, 229, 100)
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight),
                                  shape: BoxShape.rectangle,
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                        color: AppTheme.nearlyDarkBlue
                                            .withOpacity(0.4),
                                        offset: const Offset(8.0, 16.0),
                                        blurRadius: 16.0),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    splashColor: Colors.white.withOpacity(0.1),
                                    highlightColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    onTap: () {
                                      setState(() {
                                        getStringValuesSF();
                                        print(_dataString);
                                        showQRDialog();
                                      });
                                    },
                                    child: Center(
                                      child:
                                      Text("TẠO QR",
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25, color: Colors.white)
                                      ),
                                    )

                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
//                    FlatButton(
//                      child:  Text("TẠO QR",style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25)),
//                        color: Colors.blueAccent,
//                        textColor: Colors.white,
//                      onPressed: (){
//                        setState(() {
//                          getStringValuesSF();
//                          print(_dataString);
//                          showQRDialog();
//                        });
//                      }
//                    ),
                  )
                  //),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  Future<bool> getData() async {
    await Future<dynamic>.delayed(const Duration(milliseconds: 200));
    return true;
  }

  Widget bottomBar() {
    return Column(
      children: <Widget>[
        const Expanded(
          child: SizedBox(),
        ),
        BottomBarView(
          tabIconsList: tabIconsList,
          addClick: _scanQR,
          changeIndex: (int index) {
            if (index == 0 || index == 2) {
              animationController.reverse().then<dynamic>((data) {
                if (!mounted) {
                  return;
                }
                setState(() {
                  tabBody = _contentWidget();//(animationController:animationController);
                  // MyDiaryScreen(animationController: animationController);
                });
              });
            } else if (index == 1 || index == 3) {
              animationController.reverse().then<dynamic>((data) {
                if (!mounted) {
                  return;
                }
                setState(() {
                  //tabBody = TrainingScreen(animationController: animationController);
                });
              });
            }
          },
        ),
      ],
    );
  }
  Future<String> getInfo(String plate) async {
    String resultFromDB = (await FirebaseDatabase.instance.reference().child("Xe/"+plate+"/info/code").once()).value;
    //print('sadasdsadasd');
    print("info: "+resultFromDB);
    //resultFromDB = result;
    return resultFromDB;
  }
  addStringToSF(value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('qrcode',value);
  }
  getStringValuesSF() async{
    SharedPreferences prefs = await SharedPreferences.getInstance();
    //Return String
    _dataString = prefs.getString('qrcode');
    //print(stringValue);


  }
   signOut() async {
    try {
      await widget.auth.signOut();
      widget.logoutCallback();
    } catch (e) {
      print(e);
    }
  }

}
