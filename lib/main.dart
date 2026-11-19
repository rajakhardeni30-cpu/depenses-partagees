import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Depenses partagees',
      home: const HomePage(),
    );
  }
}
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController nomController = TextEditingController();
  final TextEditingController montantController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  void ajouterDepense() {
    if (nomController.text.isEmpty || montantController.text.isEmpty) {
      return;
    }
    FirebaseFirestore.instance.collection('depenses').add({
      'nom': nomController.text,
      'montant': double.parse(montantController.text),
      'description': descriptionController.text,
      'date': DateTime.now(),
    });
    nomController.clear();
    montantController.clear();
    descriptionController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Depenses partagees'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),

    );
  }
}