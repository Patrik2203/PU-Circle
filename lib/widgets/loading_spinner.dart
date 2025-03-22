// Loading spinner with optional text
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../utils/colors.dart';

class LoadingSpinner extends StatelessWidget {
  final String? text;
  final double size;

  const LoadingSpinner({
    Key? key,
    this.text,
    this.size = 40.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              strokeWidth: 3,
            ),
          ),
          if (text != null)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Text(
                text!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }
}