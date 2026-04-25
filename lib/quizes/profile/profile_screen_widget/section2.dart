import 'package:QuizSphere/quizes/home/onboarding_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Section2 extends StatelessWidget {
  const Section2({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
      
        ListTile(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) {
                return const HomeScreen();
              },
            ),
          ),
          leading: Icon(Icons.quiz),
          title: Text('Quizes'),
          trailing: Icon(Icons.arrow_forward_ios_rounded),
        ),
        ListTile(
          leading: Icon(Icons.download),
          title: Text('Lectures Downloaded'),
          trailing: Icon(Icons.arrow_forward_ios_rounded),
        ),
      ],
    );
  }
}