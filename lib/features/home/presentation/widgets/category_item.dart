import 'package:flutter/material.dart';

class CategoryItem extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Color? iconColor;
  final Color? bgColor;
  final bool isLarge;
  final String? imageUrl;

  const CategoryItem({
    super.key,
    required this.title,
    this.icon,
    this.iconColor,
    this.bgColor,
    this.isLarge = false,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isLarge ? 12.0 : 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(isLarge ? 20 : 16),
            width: isLarge ? 72 : 56,
            height: isLarge ? 72 : 56,
            decoration: BoxDecoration(
              color: bgColor ?? Colors.grey.shade50,
              shape: BoxShape.circle,
            ),
            child: imageUrl != null && imageUrl!.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.image, color: Colors.grey),
                    ),
                  )
                : Icon(
                    icon ?? Icons.category,
                    color: iconColor ?? Colors.black87,
                    size: isLarge ? 32 : 24,
                  ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: isLarge ? 80 : 70,
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isLarge ? 14 : 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
