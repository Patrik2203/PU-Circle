
// Avatar widget with placeholder
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../utils/colors.dart';

class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final String? initials;
  final VoidCallback? onTap;

  const UserAvatar({
    Key? key,
    this.imageUrl,
    this.size = 40.0,
    this.initials,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor:
        imageUrl == null ? AppColors.primary : Colors.transparent,
        child: imageUrl == null
            ? (initials != null
            ? Text(
          initials!,
          style: TextStyle(
            color: Colors.white,
            fontSize: size / 3,
            fontWeight: FontWeight.bold,
          ),
        )
            : Icon(
          Icons.person,
          size: size / 2,
          color: Colors.white,
        ))
            : ClipRRect(
          borderRadius: BorderRadius.circular(size / 2),
          child: Image.network(
            imageUrl!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }
              return CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                    : null,
                valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary),
                strokeWidth: 2,
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.person,
                size: size / 2,
                color: Colors.white,
              );
            },
          ),
        ),
      ),
    );
  }
}