// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';

// class CertificatesScreen extends StatelessWidget {
//   const CertificatesScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final uid = FirebaseAuth.instance.currentUser?.uid;

//     if (uid == null) {
//       return const Scaffold(
//         body: Center(
//           child: Text("User not logged in", style: TextStyle(color: Colors.white)),
//         ),
//       );
//     }

//     return Scaffold(
//       backgroundColor: const Color(0xFF0E0B1E),
//       appBar: AppBar(
//         backgroundColor: const Color(0xFF0E0B1E),
//         elevation: 0,
//         title: const Text("My Certificates"),
//         centerTitle: true,
//       ),
//       body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
//         stream: FirebaseFirestore.instance
//             .collection('users')
//             .doc(uid)
//             .collection('certificates')
//             .orderBy('issuedAt', descending: true)
//             .snapshots(),
//         builder: (context, snapshot) {
//           // 🔄 Loading
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(
//               child: CircularProgressIndicator(color: Colors.white),
//             );
//           }

//           // ❌ No certificates
//           if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//             return const Center(
//               child: Text(
//                 "No certificates earned yet",
//                 style: TextStyle(color: Colors.grey, fontSize: 16),
//               ),
//             );
//           }

//           final certificates = snapshot.data!.docs;

//           return ListView.separated(
//             padding: const EdgeInsets.all(16),
//             itemCount: certificates.length,
//             separatorBuilder: (_, __) => const SizedBox(height: 12),
//             itemBuilder: (context, index) {
//               final data = certificates[index].data();

//               final title = data['title'] ?? 'Untitled Course';
//               final instructor = data['instructor'] ?? 'Learnify';
//               final issuedAt = data['issuedAt'] as Timestamp?;
//               final dateText = issuedAt != null
//                   ? DateFormat.yMMMd().format(issuedAt.toDate())
//                   : 'Unknown date';

//               return Container(
//                 padding: const EdgeInsets.all(16),
//                 decoration: BoxDecoration(
//                   color: const Color(0xFF1C1A2E),
//                   borderRadius: BorderRadius.circular(16),
//                 ),
//                 child: Row(
//                   children: [
//                     // 🎓 ICON
//                     Container(
//                       width: 52,
//                       height: 52,
//                       decoration: BoxDecoration(
//                         color: Colors.deepPurpleAccent.withOpacity(0.2),
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: const Icon(
//                         Icons.workspace_premium,
//                         color: Colors.deepPurpleAccent,
//                         size: 28,
//                       ),
//                     ),

//                     const SizedBox(width: 12),

//                     // 📄 DETAILS
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             title,
//                             maxLines: 2,
//                             overflow: TextOverflow.ellipsis,
//                             style: const TextStyle(
//                               color: Colors.white,
//                               fontSize: 16,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                           const SizedBox(height: 4),
//                           Text(
//                             "Issued by $instructor",
//                             style: const TextStyle(
//                               color: Colors.white54,
//                               fontSize: 13,
//                             ),
//                           ),
//                           const SizedBox(height: 4),
//                           Text(
//                             "Issued on $dateText",
//                             style: const TextStyle(
//                               color: Colors.white38,
//                               fontSize: 12,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),

//                     const Icon(
//                       Icons.chevron_right,
//                       color: Colors.white38,
//                     ),
//                   ],
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
// }
