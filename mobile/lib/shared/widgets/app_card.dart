import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    required this.title,
    required this.description,
    this.icon,
    this.onTap,
    super.key,
  });

  final String title;
  final String description;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: AppSizes.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSizes.xs),
                    Text(description),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
