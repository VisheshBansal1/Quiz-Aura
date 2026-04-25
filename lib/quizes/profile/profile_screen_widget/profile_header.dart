import 'dart:io';
import 'package:flutter/material.dart';

class ProfileHeader extends StatelessWidget {
  final String userName;
  final String userEmail;
  final File? profileImage;
  final VoidCallback onPickImage;
  final Function(String) onEmailChanged;

  const ProfileHeader({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.profileImage,
    required this.onPickImage,
    required this.onEmailChanged,
  });

  void _showEditEmailDialog(BuildContext context) {
    final TextEditingController emailController =
        TextEditingController(text: userEmail);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text(
          "Edit Email",
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Enter new email",
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder:
                UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
            focusedBorder:
                UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
            ),
            onPressed: () {
              if (emailController.text.isNotEmpty) {
                onEmailChanged(emailController.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            GestureDetector(
              onTap: onPickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundImage:
                    profileImage != null ? FileImage(profileImage!) : null,
                backgroundColor: Colors.grey.shade700,
                child: profileImage == null
                    ? const Icon(Icons.person, size: 50, color: Colors.white)
                    : null,
              ),
            ),
            Positioned(
              bottom: 4,
              right: 4,
              child: GestureDetector(
                onTap: onPickImage,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.deepPurple,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          userName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              userEmail,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => _showEditEmailDialog(context),
              child: const Icon(Icons.edit, size: 16, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }
}