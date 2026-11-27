import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'ticket_ai_service.dart';
import 'profil_screen.dart';

class GroupeDetailPage extends StatefulWidget {
  final String groupeId;
  final String groupeNom;
  const GroupeDetailPage({super.key, required this.groupeId, required this.groupeNom});
  @override
  State<GroupeDetailPage> createState() => _GroupeDetailPageState();
}

class _GroupeDetailPageState extends State<GroupeDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final libelleController = TextEditingController();
  final montantController = TextEditingController();
  String categorie = 'courses';
  String payeurId = '';
  Set<String> participants = {};
  bool repartitionEgale = true;
  Map<String, int> partsManuelles = {};
  final categories = ['courses', 'restauration', 'transport', 'logement', 'factures', 'loisirs', 'autre'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    payeurId = FirebaseAuth.instance.currentUser?.email ?? FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  String formatMontant(int millimes) {
    double dt = millimes / 1000;
    String s = dt.toStringAsFixed(3).replaceAll('.', ',');
    return '$s DT';
  }

  Map<String, int> calculerSoldes(List<QueryDocumentSnapshot> depenses, List<dynamic> membres) {
    Map<String, int> paye = {for (var m in membres) m.toString(): 0};
    Map<String, int> du = {for (var m in membres) m.toString(): 0};
    for (var d in depenses) {
      final data = d.data() as Map<String, dynamic>;
      int montant = (data['montant'] as num?)?.toInt() ?? 0;
      String payeur = data['payeur'] ?? '';
      Map<String, dynamic> parts = Map<String, dynamic>.from(data['parts'] ?? {});
      if (paye.containsKey(payeur)) paye[payeur] = paye[payeur]! + montant;
      parts.forEach((uid, v) {
        if (du.containsKey(uid)) du[uid] = du[uid]! + (v as num).toInt();
      });
    }
    Map<String, int> soldes = {};
    for (var m in membres) {
      String uid = m.toString();
      soldes[uid] = (paye[uid] ?? 0) - (du[uid] ?? 0);
    }
    return soldes;
  }

  List<Map<String, dynamic>> calculerRemboursements(Map<String, int> soldes) {
    Map<String, int> tmp = Map.from(soldes);
    List<Map<String, dynamic>> result = [];
    while (true) {
      String? debiteur;
      String? creancier;
      int maxDette = 0;
      int maxCreance = 0;
      tmp.forEach((uid, s) {
        if (s < -maxDette) { maxDette = -s; debiteur = uid; }
        if (s > maxCreance) { maxCreance = s; creancier = uid; }
      });
      if (debiteur == null || creancier == null) break;
      int montant = maxDette < maxCreance ? maxDette : maxCreance;
      result.add({'de': debiteur, 'a': creancier, 'montant': montant});
      tmp[debiteur!] = tmp[debiteur]! + montant;
      tmp[creancier!] = tmp[creancier]! - montant;
      if (result.length > 20) break;
    }
    return result;
  }

  Future<void> ajouterDepense(List<dynamic> membres, Map<String, String> nomsMembres) async {
    if (libelleController.text.isEmpty || montantController.text.isEmpty) return;
    if (participants.isEmpty) return;
    double montantDT = double.tryParse(montantController.text.replaceAll(',', '.')) ?? 0;
    int montantMillimes = (montantDT * 1000).round();
    if (montantMillimes <= 0) return;
    Map<String, int> parts = {};
    if (repartitionEgale) {
      int n = participants.length;
      int base = montantMillimes ~/ n;
      int reste = montantMillimes - (base * n);
      int i = 0;
      for (var uid in participants) {
        parts[uid] = base + (i == 0 ? reste : 0);
        i++;
      }
    } else {
      int somme = 0;
      partsManuelles.forEach((k, v) { if (participants.contains(k)) somme += v; });
      if (somme != montantMillimes) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La somme des parts doit etre egale au montant')));
        return;
      }
      parts = Map.from(partsManuelles);
    }
    await FirebaseFirestore.instance.collection('groupes').doc(widget.groupeId).collection('depenses').add({
      'libelle': libelleController.text,
      'montant': montantMillimes,
      'payeur': payeurId,
      'payeurNom': nomsMembres[payeurId] ?? payeurId,
      'parts': parts,
      'participants': participants.toList(),
      'categorie': categorie,
      'date': DateTime.now(),
      'auteur': FirebaseAuth.instance.currentUser?.uid,
    });
    libelleController.clear();
    montantController.clear();
    partsManuelles.clear();
    Navigator.pop(context);
  }

  Future<void> scannerTicket() async {
    final picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);
    if (photo == null) return;
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    Uint8List bytes = await photo.readAsBytes();
    Uint8List? compressed = await FlutterImageCompress.compressWithList(bytes, minWidth: 1024, minHeight: 1024, quality: 80);
    bytes = compressed ?? bytes;
    final result = await TicketAiService().analyserTicket(bytes);
    Navigator.pop(context);
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible de lire le ticket')));
      return;
    }
    libelleController.text = result.commerce.isNotEmpty ? result.commerce : 'Ticket';
    montantController.text = result.total.toString().replaceAll('.', ',');
    setState(() {
      if (categories.contains(result.categorie)) categorie = result.categorie;
    });
    if (result.ecart) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Attention ecart: Total ${result.total} vs Somme ${result.sommeLignes}'), backgroundColor: Colors.orange));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket lu avec succes')));
    }
  }

  void showAddDialog(List<dynamic> membres, Map<String, String> nomsMembres) {
    participants = membres.map((e) => e.toString()).toSet();
    if (!membres.contains(payeurId) && membres.isNotEmpty) payeurId = membres.first.toString();
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Nouvelle depense'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      await scannerTicket();
                      setStateDialog(() {});
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Scanner un ticket'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: libelleController, decoration: const InputDecoration(labelText: 'Libelle', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: montantController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Montant DT ex: 12,500', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: categorie,
                    items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setStateDialog(() => categorie = v ?? 'courses'),
                    decoration: const InputDecoration(labelText: 'Categorie', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: membres.contains(payeurId) ? payeurId : null,
                    items: membres.map((m) => DropdownMenuItem(value: m.toString(), child: Text(nomsMembres[m.toString()] ?? m.toString()))).toList(),
                    onChanged: (v) => setStateDialog(() => payeurId = v ?? ''),
                    decoration: const InputDecoration(labelText: 'Payeur', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Repartition: '),
                      ChoiceChip(label: const Text('Egale'), selected: repartitionEgale, onSelected: (_) => setStateDialog(() => repartitionEgale = true)),
                      ChoiceChip(label: const Text('Par montants'), selected: !repartitionEgale, onSelected: (_) => setStateDialog(() => repartitionEgale = false)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Align(alignment: Alignment.centerLeft, child: Text('Participants:', style: TextStyle(fontWeight: FontWeight.bold))),
                  ...membres.map((m) {
                    String uid = m.toString();
                    return CheckboxListTile(
                      title: Text(nomsMembres[uid] ?? uid),
                      value: participants.contains(uid),
                      onChanged: (v) => setStateDialog(() {
                        if (v == true) participants.add(uid); else participants.remove(uid);
                      }),
                    );
                  }),
                  if (!repartitionEgale) ...[
                    const Text('Parts en DT pour chaque participant:'),
                    ...participants.map((uid) {
                      return TextField(
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: nomsMembres[uid] ?? uid),
                        onChanged: (val) {
                          double d = double.tryParse(val.replaceAll(',', '.')) ?? 0;
                          partsManuelles[uid] = (d * 1000).round();
                        },
                      );
                    }),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
              ElevatedButton(onPressed: () => ajouterDepense(membres, nomsMembres), child: const Text('Ajouter')),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('groupes').doc(widget.groupeId).snapshots(),
      builder: (context, groupeSnap) {
        if (!groupeSnap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final groupeData = groupeSnap.data!.data() as Map<String, dynamic>? ?? {};
        List<dynamic> membres = groupeData['membresEmails'] ?? groupeData['membres'] ?? [];
        Map<String, String> nomsMembres = {};
        for (var m in membres) {
          String id = m.toString();
          nomsMembres[id] = id.split('@')[0];
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.groupeNom),
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.person_add),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) {
                      final emailCtrl = TextEditingController();
                      return AlertDialog(
                        title: const Text('Ajouter membre'),
                        content: TextField(
                          controller: emailCtrl,
                          decoration: const InputDecoration(labelText: 'Email du membre'),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                          ElevatedButton(
                            onPressed: () async {
                              String newEmail = emailCtrl.text.trim().toLowerCase();
                              if (newEmail.isEmpty) return;
                              final snap = await FirebaseFirestore.instance.collection('groupes').doc(widget.groupeId).get();
                              final data = snap.data() as Map<String, dynamic>? ?? {};
                              List membresEmails = List.from(data['membresEmails'] ?? data['membres'] ?? []);
                              if (!membresEmails.contains(newEmail)) {
                                membresEmails.add(newEmail);
                                await FirebaseFirestore.instance.collection('groupes').doc(widget.groupeId).update({'membresEmails': membresEmails});
                              }
                              Navigator.pop(context);
                            },
                            child: const Text('Ajouter'),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'Depenses'),
                Tab(text: 'Soldes'),
                Tab(text: 'Remboursements'),
                Tab(text: 'Statistiques'),
                Tab(text: 'Profil'),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => showAddDialog(membres, nomsMembres),
            backgroundColor: Colors.purple,
            child: const Icon(Icons.add, color: Colors.white),
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('groupes').doc(widget.groupeId).collection('depenses').orderBy('date', descending: true).snapshots(),
            builder: (context, depSnap) {
              if (!depSnap.hasData) return const Center(child: CircularProgressIndicator());
              final depenses = depSnap.data!.docs;
              final soldes = calculerSoldes(depenses, membres);
              final remboursements = calculerRemboursements(soldes);
              return TabBarView(
                controller: _tabController,
                children: [
                  depenses.isEmpty
                      ? const Center(child: Text('Aucune depense'))
                      : ListView.builder(
                    itemCount: depenses.length,
                    itemBuilder: (context, i) {
                      final d = depenses[i].data() as Map<String, dynamic>;
                      return Card(
                        child: ListTile(
                          title: Text('${d['libelle']} - ${formatMontant((d['montant'] as num?)?.toInt() ?? 0)}'),
                          subtitle: Text('Paye par ${d['payeurNom'] ?? ''} • ${d['categorie'] ?? ''}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => FirebaseFirestore.instance.collection('groupes').doc(widget.groupeId).collection('depenses').doc(depenses[i].id).delete(),
                          ),
                        ),
                      );
                    },
                  ),
                  ListView(
                    children: membres.map((m) {
                      String uid = m.toString();
                      int solde = soldes[uid] ?? 0;
                      Color c = solde > 0 ? Colors.green : (solde < 0 ? Colors.red : Colors.grey);
                      String texte = solde > 0 ? 'On lui doit ${formatMontant(solde)}' : (solde < 0 ? 'Il doit ${formatMontant(-solde)}' : 'Solde nul');
                      return Card(child: ListTile(title: Text(nomsMembres[uid] ?? uid), subtitle: Text(texte), trailing: Icon(Icons.account_circle, color: c)));
                    }).toList(),
                  ),
                  remboursements.isEmpty
                      ? const Center(child: Text('Aucun remboursement a effectuer'))
                      : ListView.builder(
                    itemCount: remboursements.length,
                    itemBuilder: (context, i) {
                      final r = remboursements[i];
                      return Card(
                        child: ListTile(
                          title: Text('${nomsMembres[r['de']] ?? r['de']} doit ${formatMontant(r['montant'])} a ${nomsMembres[r['a']] ?? r['a']}'),
                          trailing: ElevatedButton(
                            onPressed: () async {
                              await FirebaseFirestore.instance.collection('groupes').doc(widget.groupeId).collection('remboursements').add({
                                'de': r['de'],
                                'a': r['a'],
                                'montant': r['montant'],
                                'date': DateTime.now(),
                              });
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Remboursement enregistre')));
                            },
                            child: const Text('Effectue'),
                          ),
                        ),
                      );
                    },
                  ),
                  Builder(builder: (context) {
                    Map<String, int> parCat = {};
                    for (var d in depenses) {
                      final data = d.data() as Map<String, dynamic>;
                      String cat = data['categorie'] ?? 'autre';
                      parCat[cat] = (parCat[cat] ?? 0) + ((data['montant'] as num?)?.toInt() ?? 0);
                    }
                    if (parCat.isEmpty) return const Center(child: Text('Aucune statistique'));
                    return ListView(
                      children: parCat.entries.map((e) => Card(child: ListTile(title: Text(e.key), trailing: Text(formatMontant(e.value))))).toList(),
                    );
                  }),
                  const ProfilScreen(),
                ],
              );
            },
          ),
        );
      },
    );
  }
}