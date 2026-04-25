import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  final List<String> languages = [
    "English",
    "Hindi",
    "Spanish",
    "French",
  ];

  String? selectedLang;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentLanguage();
  }

  // 🔥 Load saved language from Firestore
  Future<void> _loadCurrentLanguage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      setState(() {
        selectedLang = doc.data()?['language'] ?? "English";
      });
    } else {
      setState(() => selectedLang = "English");
    }
  }

  // 🔥 Save language
  Future<void> _selectLanguage(String lang) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => isSaving = true);

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({
      'language': lang,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;

    Navigator.pop(context, lang);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0B1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E0B1E),
        title: const Text("Select Language"),
        centerTitle: true,
      ),
      body: selectedLang == null
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : ListView.separated(
              itemCount: languages.length,
              separatorBuilder: (_, __) =>
                  const Divider(color: Colors.white12),
              itemBuilder: (context, index) {
                final lang = languages[index];

                return RadioListTile<String>(
                  value: lang,
                  groupValue: selectedLang,
                  activeColor: Colors.deepPurpleAccent,
                  title: Text(
                    lang,
                    style: const TextStyle(color: Colors.white),
                  ),
                  onChanged: isSaving
                      ? null
                      : (val) {
                          if (val == null) return;
                          setState(() => selectedLang = val);
                          _selectLanguage(val);
                        },
                );
              },
            ),
    );
  }
}
