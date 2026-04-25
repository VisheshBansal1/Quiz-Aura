// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';

// class CurrentUserProgress extends StatelessWidget {
//   const CurrentUserProgress({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) return const SizedBox();

//     return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
//       stream: FirebaseFirestore.instance
//           .collection('users')
//           .doc(user.uid)
//           .snapshots(),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return _skeleton();
//         }

//         if (!snapshot.hasData || !snapshot.data!.exists) {
//           return _empty();
//         }

//         final data = snapshot.data!.data()!;

//         final String name = data['name'] ?? 'You';
//         final String imagePath = data['profileImage'] ?? '';
//         final int xp = (data['xp'] ?? 0) as int;
//         final int levelXp = (data['levelXp'] ?? 100) as int;
//         final int rank = (data['rank'] ?? 0) as int;

//         final double progress =
//             levelXp > 0 ? (xp / levelXp).clamp(0.0, 1.0) : 0;

//         ImageProvider? avatar;
//         if (imagePath.isNotEmpty) {
//           if (imagePath.startsWith('http')) {
//             avatar = NetworkImage(imagePath);
//           } else if (File(imagePath).existsSync()) {
//             avatar = FileImage(File(imagePath));
//           }
//         }

//         return Container(
//           padding: const EdgeInsets.all(16),
//           decoration: BoxDecoration(
//             color: const Color(0xFF1C1A2E),
//             borderRadius: BorderRadius.circular(22),
//           ),
//           child: Row(
//             children: [
//               /// AVATAR
//               CircleAvatar(
//                 radius: 28,
//                 backgroundColor: Colors.deepPurpleAccent,
//                 backgroundImage: avatar,
//                 child: avatar == null
//                     ? const Icon(Icons.person, color: Colors.white, size: 30)
//                     : null,
//               ),

//               const SizedBox(width: 14),

//               /// USER INFO
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       name,
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontWeight: FontWeight.bold,
//                         fontSize: 16,
//                       ),
//                     ),

//                     const SizedBox(height: 4),

//                     Text(
//                       "$xp / $levelXp XP",
//                       style: TextStyle(
//                         color: Colors.grey.shade300,
//                         fontSize: 13,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),

//                     const SizedBox(height: 8),

//                     ClipRRect(
//                       borderRadius: BorderRadius.circular(6),
//                       child: LinearProgressIndicator(
//                         value: progress,
//                         minHeight: 6,
//                         backgroundColor: Colors.white24,
//                         valueColor: const AlwaysStoppedAnimation(
//                           Colors.deepPurpleAccent,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),

//               const SizedBox(width: 12),

//               /// RANK
//               Column(
//                 crossAxisAlignment: CrossAxisAlignment.end,
//                 children: [
//                   Text(
//                     "#$rank",
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     "${(levelXp - xp).clamp(0, levelXp)} XP left",
//                     style: const TextStyle(
//                       color: Colors.white54,
//                       fontSize: 12,
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   // ------------------ STATES ------------------

//   Widget _skeleton() {
//     return Container(
//       height: 90,
//       decoration: BoxDecoration(
//         color: Colors.grey.shade800,
//         borderRadius: BorderRadius.circular(22),
//       ),
//     );
//   }

//   Widget _empty() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.grey.shade900,
//         borderRadius: BorderRadius.circular(22),
//       ),
//       child: const Text(
//         "Progress not available",
//         style: TextStyle(color: Colors.white54),
//       ),
//     );
//   }
// }
