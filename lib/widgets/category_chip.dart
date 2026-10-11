import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/ls_colors.dart';
import 'ls_tag.dart';

/// The exception category as a small outlined tag.
class CategoryChip extends StatelessWidget {
  const CategoryChip({super.key, required this.category});

  final ExceptionCategory category;

  @override
  Widget build(BuildContext context) {
    final c = context.ls;
    return LsTag(text: category.label, border: c.line, textColor: c.ink);
  }
}
