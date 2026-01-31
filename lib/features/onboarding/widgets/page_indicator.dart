import 'package:flutter/material.dart';
import 'package:smashrite/core/theme/app_theme.dart';

class PageIndicator extends StatelessWidget {
  final int currentPage;
  final int pageCount;

  const PageIndicator({
    super.key,
    required this.currentPage,
    required this.pageCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        pageCount,
        (index) => Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: index < pageCount - 1 ? 8 : 0),
            decoration: BoxDecoration(
              color:
                  index <= currentPage
                      ? const Color(0xFF1E3A8A) // Dark blue for active
                      : const Color(0xFFE5E7EB), // Light gray for inactive
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}
