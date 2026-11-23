import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GroupeDetailPage extends StatefulWidget {
  final String groupeId;
  final String groupeNom;
  const GroupeDetailPage({super.key, required this.groupeId, required this.groupeNom});
  @override
  State<GroupeDetailPage> createState() => _GroupeDetailPageState();
}

class _GroupeDetailPageState extends State<GroupeDetailPage> {
  final TextEditingController nomController = TextEditingController();
  final TextEditingController montantController = TextEditingController();

  void ajouterDepense() {
    if (nomController.text.isEmpty || montantController.text.isEmpty) return;
    FirebaseFirestore.instance.collection('depenses').add({
      'nom': nomController.text,
      'montant': double.tryParse(montantController.text) ?? 0,
      'groupeId': widget.groupeId,
      'date': DateTime.now(),
    });
    nomController.clear();
    montantController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.groupeNom), backgroundColor: Colors.purple, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: nomController, decoration: const InputDecoration(labelText: 'Nom', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: montantController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Montant', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: ajouterDepense, style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white), child: const Text('Ajouter'))),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('depenses').where('groupeId', isEqualTo: widget.groupeId).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) return const Center(child: Text('Aucune depense dans ce groupe'));
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      return Card(child: ListTile(title: Text('${data['nom']} - ${data['montant']} DT'), trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => FirebaseFirestore.instance.collection('depenses').doc(docs[index].id).delete())));
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}