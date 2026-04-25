import 'dart:io';
import 'package:QuizSphere/quizes/profile/edit_profile_screen.dart';
import 'package:flutter/material.dart';

class HeaderSection extends StatelessWidget {
  final String name;
  final String email;
  final String? imagePath;
  final Function(String, String, String?) onProfileUpdated;

  const HeaderSection({
    super.key,
    required this.name,
    required this.email,
    required this.imagePath,
    required this.onProfileUpdated,
  });

  ImageProvider _getProfileImage() {
    if (imagePath == null || imagePath!.isEmpty) {
      return const NetworkImage(
        'https://cdn-icons-png.flaticon.com/512/3135/3135715.png',
      );
    }

    // Local file path
    if (imagePath!.startsWith('/')) {
      return FileImage(File(imagePath!));
    }

    // Network URL
    return NetworkImage(imagePath!);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // ---- PROFILE IMAGE ----
          Stack(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundImage: _getProfileImage(),
                backgroundColor: Colors.grey.shade800,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 14),

          // ---- NAME + EMAIL ----
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'User' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 10),

                // ---- EDIT PROFILE BUTTON ----
                // SizedBox(
                //   height: 30,
                //   child: ElevatedButton(
                //     style: ElevatedButton.styleFrom(
                //       backgroundColor: Colors.deepPurpleAccent,
                //       padding: const EdgeInsets.symmetric(horizontal: 14),
                //       shape: RoundedRectangleBorder(
                //         borderRadius: BorderRadius.circular(6),
                //       ),
                //     ),
                //     onPressed: () async {
                //       final result = await Navigator.push(
                //         context,
                //         MaterialPageRoute(
                //           builder: (_) => EditProfileScreen(
                //             name: name,
                //             email: email,
                //             imagePath: imagePath,
                //           ),
                //         ),
                //       );

                //       if (result != null && result is Map<String, dynamic>) {
                //         onProfileUpdated(
                //           result['name'],
                //           result['email'],
                //           result['imagePath'],
                //         );
                //       }
                //     },
                //     child: const Text(
                //       'Edit Profile',
                //       style: TextStyle(
                //         fontSize: 13,
                //         fontWeight: FontWeight.w600,
                //         color: Colors.white,
                //       ),
                //     ),
                //   ),
                // ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
