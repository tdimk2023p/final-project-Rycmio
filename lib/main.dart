import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:todovoice/data/database.dart';
import 'package:todovoice/util/efab.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../util/dialog_box.dart';
import '../util/todo_tile.dart';

void main() async {
  // ini the hive
  await Hive.initFlutter();

  // open a box
  var box = await Hive.openBox('mybox');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TodoVoice',
      theme: ThemeData(
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xff375076),
        ),
        colorScheme: ColorScheme.fromSeed(
          primary: const Color(0xff375076),
          secondary: const Color(0xff9DB2BF),
          seedColor: const Color(0xff375076),
          background: const Color(0xff27374D),
          brightness: Brightness.dark,
        ),
        textTheme: TextTheme(
          titleLarge: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: const Color(0xffF8FCFF)),
          titleMedium: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xffF8FCFF)),
          bodyMedium: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xffF8FCFF)),
        ),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'TO DO Voice'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // reference the hive box
  final _myBox = Hive.box('mybox');
  ToDoDatabase db = ToDoDatabase();

  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _currentLocaleId = '';

  @override
  void initState() {
    // if this is the 1st time ever opening the app, then create default data
    if (_myBox.get("TODOLIST") == null) {
      db.createInitialData();
    } else {
      // there already axists data
      db.loadData();
    }
    initSpeech();
    super.initState();
  }

  void initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    var locales = await _speechToText.systemLocale();
    _currentLocaleId = locales?.localeId ?? '';
    setState(() {});
  }

  void _onSpeechResult(result) {
    setState(() {
      _controller.text = "${result.recognizedWords}";
    });
  }

  void _startListening() async {
    await _speechToText.listen(
      onResult: _onSpeechResult,
      localeId: _currentLocaleId,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 40),
    );
    setState(() {});
  }

  void _stopListening() async {
    await _speechToText.stop();
    if (_controller.text == '') {
      return;
    }
    saveNewTask();
    _controller.clear();
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // list of tasks
  // List toDoList = [
  //   ["make todo", false],
  //   ["sleep", false],
  // ];

  // checkbox was tapped
  void checkBoxChanged(bool? value, int index) {
    setState(() {
      db.toDoList[index][1] = !db.toDoList[index][1];
    });
    db.updateDataBase();
  }

  // save new task
  void saveNewTask() {
    setState(() {
      db.toDoList.add([_controller.text, false]);
      _controller.clear();
    });
    db.updateDataBase();
    //Navigator.of(context).pop();
  }

  // create new task
  void createNewTask() {
    showDialog(
        context: context,
        builder: (context) {
          return DialogBox(
              controller: _controller,
              onSave: () {
                saveNewTask();
                _controller.clear();
                Navigator.of(context).pop();
                _controller.clear();
              },
              onCancel: () {
                Navigator.of(context).pop();
                _controller.clear();
              });
        });
  }

  // delete task
  void deleteTask(int index) {
    setState(() {
      db.toDoList.removeAt(index);
    });
    db.updateDataBase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          title: Center(
            child: Text(
              widget.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView.builder(
            reverse: true,
            shrinkWrap: true,
            itemCount: db.toDoList.length,
            itemBuilder: (context, index) {
              return ToDoTile(
                taskName: db.toDoList[index][0],
                taskCompleted: db.toDoList[index][1],
                onChanged: (value) => checkBoxChanged(value, index),
                deleteFunction: (context) => deleteTask(index),
              );
            },
          ),
        ),
        floatingActionButton: ExpandableFab(
          distance: 70,
          children: [
            IconButton(
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                minimumSize: const Size(65, 65),
              ),
              onPressed: () {
                createNewTask();
                _controller.clear();
              },
              icon: const Icon(Icons.task),
            ),
            AvatarGlow(
              animate: _speechToText.isListening,
              glowColor: Theme.of(context).colorScheme.secondary,
              endRadius: 75.0,
              duration: const Duration(milliseconds: 2000),
              repeatPauseDuration: const Duration(milliseconds: 100),
              repeat: true,
              child: GestureDetector(
                onLongPressStart: (details) => _startListening(),
                onLongPressEnd: (details) {
                  _stopListening();
                  setState(() {});
                },
                child: IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    minimumSize: const Size(65, 65),
                  ),
                  onPressed: () {},
                  icon: Icon(
                      _speechToText.isNotListening ? Icons.mic_off : Icons.mic),
                ),
              ),
            ),
          ],
        ));
  }
}
