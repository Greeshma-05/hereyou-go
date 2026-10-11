import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/category.dart';

IconData categoryIcon(Category category) => switch (category) {
  Category.food => Icons.restaurant_rounded,
  Category.medicine => Icons.local_pharmacy_outlined,
  Category.hygiene => Icons.spa_outlined,
  Category.baby => Icons.child_care_rounded,
  Category.travel => Icons.luggage_outlined,
};
// Category names and distinct pictograms identify categories in every palette.
Color categoryColor(BuildContext context, Category category) =>
    AppTheme.colors(context).tint;

class CategoryArtwork extends StatelessWidget {
  const CategoryArtwork(this.category, {super.key, this.size = 76, this.icon});
  final Category category;
  final double size;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          categoryColor(context, category),
          AppTheme.colors(context).surface,
        ],
      ),
      border: Border.all(color: AppTheme.colors(context).border),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Icon(
      icon ?? categoryIcon(category),
      size: size * .42,
      color: AppTheme.colors(context).accent,
    ),
  );
}

class CategoryFilters extends StatelessWidget {
  const CategoryFilters({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  final Category? selected;
  final ValueChanged<Category?> onSelected;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        Padding(
          padding: EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text('All'),
            labelStyle: TextStyle(
              color: selected == null
                  ? AppTheme.colors(context).onAccent
                  : AppTheme.colors(context).ink,
            ),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          ),
        ),
        for (final category in Category.values)
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: Icon(
                categoryIcon(category),
                size: 17,
                color: selected == category
                    ? AppTheme.colors(context).onAccent
                    : AppTheme.colors(context).accent,
              ),
              labelStyle: TextStyle(
                color: selected == category
                    ? AppTheme.colors(context).onAccent
                    : AppTheme.colors(context).ink,
              ),
              label: Text(category.label),
              selected: selected == category,
              onSelected: (_) => onSelected(category),
            ),
          ),
      ],
    ),
  );
}
