import 'package:flutter/material.dart';
import '../utils/colors.dart';
import '../utils/constants.dart';
import 'custom_button.dart';


// Empty state widget for various screens
class EmptyStateWidget extends StatelessWidget {
  final String message;
  final IconData icon;
  final String? actionText;
  final VoidCallback? onAction;

  const EmptyStateWidget({
    Key? key,
    required this.message,
    this.icon = Icons.sentiment_dissatisfied,
    this.actionText,
    this.onAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            if (actionText != null && onAction != null)
              Padding(
                padding: const EdgeInsets.only(top: 24.0),
                child: CustomButton(
                  text: actionText!,
                  onPressed: onAction!,
                  width: 200,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Custom chip for interests, tags, etc.
class CustomChip extends StatelessWidget {
  final String label;
  final Color? backgroundColor;
  final Color? textColor;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool isRemovable;
  final VoidCallback? onRemove;

  const CustomChip({
    Key? key,
    required this.label,
    this.backgroundColor,
    this.textColor,
    this.onTap,
    this.isSelected = false,
    this.isRemovable = false,
    this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        margin: const EdgeInsets.only(right: 8, bottom: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? backgroundColor ?? AppColors.primary
              : backgroundColor ?? Colors.grey[200],
          borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? textColor ?? Colors.white
                    : textColor ?? Colors.black87,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            if (isRemovable) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onRemove,
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: isSelected
                      ? textColor ?? Colors.white
                      : textColor ?? Colors.black87,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Custom snackbar
void showCustomSnackBar(
  BuildContext context, {
  required String message,
  bool isError = false,
  int durationSeconds = 2,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      duration: Duration(seconds: durationSeconds),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
      ),
      action: SnackBarAction(
        label: 'Dismiss',
        textColor: Colors.white,
        onPressed: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        },
      ),
    ),
  );
}
