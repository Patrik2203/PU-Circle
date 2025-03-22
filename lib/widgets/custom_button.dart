// Custom button with various styles
import 'package:flutter/material.dart';

import '../utils/colors.dart';
import '../utils/constants.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isOutlined;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? iconData;
  final double height;
  final double? width;
  final bool isDisabled;

  const CustomButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.backgroundColor,
    this.textColor,
    this.iconData,
    this.height = 50.0,
    this.width,
    this.isDisabled = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width ?? double.infinity,
      child: isOutlined
          ? OutlinedButton(
        onPressed: isDisabled || isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: isDisabled
                ? Colors.grey
                : backgroundColor ?? AppColors.primary,
          ),
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(AppConstants.smallBorderRadius),
          ),
        ),
        child: _buildButtonContent(),
      )
          : ElevatedButton(
        onPressed: isDisabled || isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDisabled
              ? Colors.grey
              : backgroundColor ?? AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(AppConstants.smallBorderRadius),
          ),
          elevation: 0,
        ),
        child: _buildButtonContent(),
      ),
    );
  }

  Widget _buildButtonContent() {
    return isLoading
        ? const SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        strokeWidth: 2,
      ),
    )
        : Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (iconData != null) ...[
          Icon(
            iconData,
            color: isOutlined
                ? textColor ?? AppColors.primary
                : textColor ?? Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: TextStyle(
            color: isOutlined
                ? textColor ?? AppColors.primary
                : textColor ?? Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}