import 'package:flutter/material.dart';
import 'package:adhan/adhan.dart';
import 'package:location/location.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AndroidAlarmManager.initialize();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  _navigateToHome() {
    Future.delayed(Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => AdhanApp()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/download.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Text(
            'Azan App',
            style: TextStyle(fontSize: 30, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class AdhanApp extends StatefulWidget {
  @override
  _AdhanAppState createState() => _AdhanAppState();
}

class _AdhanAppState extends State<AdhanApp> {
  List<String> prayerTimes = [];
  Location _location = Location();
  double latitude = 0.0;
  double longitude = 0.0;
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _getLocation();
    _initializeNotifications();
  }

  Future<void> _getLocation() async {
    var locationData = await _location.getLocation();
    setState(() {
      latitude = locationData.latitude!;
      longitude = locationData.longitude!;
    });
    fetchPrayerTimes();
  }

  Future<void> _initializeNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    final initializationSettings = InitializationSettings(android: android);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> fetchPrayerTimes() async {
    if (latitude == 0.0 || longitude == 0.0) return;

    final params = CalculationMethod.karachi.getParameters();
    final coordinates = Coordinates(latitude, longitude);
    final prayerTimesData = PrayerTimes.today(coordinates, params);

    setState(() {
      prayerTimes = [
        formatTime(prayerTimesData.fajr),
        formatTime(prayerTimesData.dhuhr),
        formatTime(prayerTimesData.asr),
        formatTime(prayerTimesData.maghrib),
        formatTime(prayerTimesData.isha),
      ];
    });

    scheduleAdhan(prayerTimesData);
  }

  String formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Future<void> scheduleAdhan(PrayerTimes prayerTimesData) async {
    final player = AudioPlayer();
    final now = DateTime.now();

    final prayerTimesList = [
      {'time': prayerTimesData.fajr, 'label': 'Fajr'},
      {'time': prayerTimesData.dhuhr, 'label': 'Dhuhr'},
      {'time': prayerTimesData.asr, 'label': 'Asr'},
      {'time': prayerTimesData.maghrib, 'label': 'Maghrib'},
      {'time': prayerTimesData.isha, 'label': 'Isha'}
    ];

    for (var prayer in prayerTimesList) {
      DateTime prayerTime = prayer['time'] as DateTime;
      if (prayerTime.isAfter(now)) {
        final difference = prayerTime.difference(now);
        Future.delayed(difference, () async {
          await player.play(AssetSource('adhan.mp3')).then((value) {
            print('${prayer['label']} Azan started playing');
          });

        player.onPlayerStateChanged.listen((state) {
  if (state == PlayerState.completed) {
    print('${prayer['label']} Azan finished playing');
  }
});


          _showNotification(prayer['label'] as String);
        });
      }
    }
  }

  Future<void> _showNotification(String prayerName) async {
    const androidDetails = AndroidNotificationDetails(
      'adhan_channel',
      'Adhan Notifications',
      channelDescription: 'Channel for Adhan notifications',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(
      0,
      'It\'s time for $prayerName!',
      'The time for $prayerName has arrived.',
      notificationDetails,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text("Azan App Created by Balach Zehri"),
        backgroundColor: Colors.white70,
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: ListView.builder(
          itemCount: prayerTimes.length,
          itemBuilder: (context, index) {
            return Card(
              margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
              child: ListTile(
                contentPadding: EdgeInsets.all(16),
                leading: Icon(Icons.access_time, color: Colors.black45),
                title: Text(
                  ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'][index],
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                ),
                subtitle: Text(
                  prayerTimes[index],
                  style: TextStyle(color: Colors.grey[600]),
                ),
                trailing: Icon(Icons.arrow_forward_ios, color: Colors.blueAccent),
              ),
            );
          },
        ),
      ),
    );
  }
}
