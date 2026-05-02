import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class DashboardShimmer extends StatelessWidget {
  const DashboardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          // Squelette de la Balance Card
          _shimmerBox(height: 160, width: double.infinity, borderRadius: 25),
          const SizedBox(height: 32),
          // Squelette Titre "Mes Objectifs"
          _shimmerBox(height: 20, width: 150, borderRadius: 5),
          const SizedBox(height: 16),
          // Squelette des GoalCards (Horizontal)
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              itemBuilder: (_, __) => _shimmerBox(
                height: 200,
                width: 150,
                borderRadius: 24,
                margin: const EdgeInsets.only(right: 16),
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Squelette Titre "Marketplace"
          _shimmerBox(height: 20, width: 120, borderRadius: 5),
          const SizedBox(height: 16),
          // Squelette de la Grid Marketplace
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: 195,
            ),
            itemCount: 4,
            itemBuilder: (_, __) => _shimmerBox(
              height: 195,
              width: double.infinity,
              borderRadius: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _shimmerBox({
    required double height,
    required double width,
    required double borderRadius,
    EdgeInsets? margin,
  }) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        margin: margin,
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}
