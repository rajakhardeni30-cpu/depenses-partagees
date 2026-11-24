import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'groupe_detail_page.dart';

class GroupesPage extends StatefulWidget {
  const GroupesPage({super.key});
  @override
  State<GroupesPage> createState() => _GroupesPageState();
}

class _GroupesPageState extends State<GroupesPage> {
  final TextEditingController nomController = TextEditingController();

  void creerGroupe() {
    if (nomController.text.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    FirebaseFirestore.instance.collection('groupes').add({
      'nom': nomController.text,
      'devise': 'TND',
      'createur': user?.uid ?? '',
      'createurEmail': user?.email ?? 'inconnu',
      'membres': [user?.uid ?? ''],
      'membresEmails': [user?.email ?? ''],
      'creeLe': DateTime.now(),
    });
    nomController.clear();
    Navigator.pop(context);
  }

  void showAddDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nouveau Groupe'),
        content: TextField(
          controller: nomController,
          decoration: const InputDecoration(labelText: 'Nom du groupe', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(onPressed: creerGroupe, child: const Text('Creer')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Mes Groupes'), backgroundColor: Colors.purple, foregroundColor: Colors.white),
      floatingActionButton: FloatingActionButton(onPressed: showAddDialog, backgroundColor: Colors.purple, child: const Icon(Icons.add, color: Colors.white)),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('groupes').where('membres', arrayContains: user?.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('Aucun groupe, creez-en un !'));
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.purple, child: Icon(Icons.group, color: Colors.white)),
                  title: Text(data['nom'] ?? ''),
                  subtitle: Text('Cree par: ${data['createurEmail'] ?? ''}'),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => GroupeDetailPage(groupeId: docs[index].id, groupeNom: data['nom'])));
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => FirebaseFirestore.instance.collection('groupes').doc(docs[index].id).delete(),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}