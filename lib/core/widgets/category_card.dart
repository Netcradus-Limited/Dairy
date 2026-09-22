import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../../models/category.dart';

/// Reusable Category Card Component matching Sawariya Dairy Discovery Screen
class CategoryCard extends StatefulWidget {
  final Category category;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  const CategoryCard({
    super.key,
    required this.category,
    this.onTap,
    this.width = 195,
    this.height = 205,
  });

  @override
  State<CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<CategoryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cat = widget.category;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.white, Color(0xFFF0FDF4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered
                ? const Color(0xFF0F4A2F)
                : const Color(0xFFDCFCE7),
            width: _isHovered ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? const Color(0xFF0F4A2F).withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.02),
              blurRadius: _isHovered ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onTap?.call();
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top: Product Image
                  Expanded(
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Builder(builder: (context) {
                          final image = cat.resolvedImageUrl;
                          if (image.isEmpty) {
                            return const Center(
                              child: Icon(
                                Icons.image_outlined,
                                color: AppColors.textMuted,
                                size: 36,
                              ),
                            );
                          }
                          if (image.startsWith('http')) {
                            return Image.network(
                              image,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Center(
                                child: Icon(
                                  Icons.image_outlined,
                                  color: AppColors.textMuted,
                                  size: 36,
                                ),
                              ),
                            );
                          }
                          return Image.asset(
                            image,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Center(
                              child: Icon(
                                Icons.image_outlined,
                                color: AppColors.textMuted,
                                size: 36,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Bottom: Title, Subtitle, and Circular Arrow Button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              cat.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                                height: 1.2,
                              ),
                            ),
                            if (cat.subtitle.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                cat.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF64748B),
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        height: 28,
                        width: 28,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: Color(0xFF0F4A2F),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
