import 'package:flutter/material.dart';

class Section1 extends StatelessWidget {
  const Section1({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.favorite_border),
          title: Text('Favorite'),
          trailing: Icon(Icons.arrow_forward_ios_rounded),
        ),
        ListTile(
          leading: Icon(Icons.download_sharp),
          title: Text('Download'),
          trailing: Icon(Icons.arrow_forward_ios_rounded),
        ),
      ],
    );
  }
}
