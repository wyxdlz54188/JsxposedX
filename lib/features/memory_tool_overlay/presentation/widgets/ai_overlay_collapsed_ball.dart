import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AiOverlayCollapsedBall extends StatelessWidget {
  const AiOverlayCollapsedBall({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14.r),
        onTap: onTap,
        child: Center(
          child: Icon(
            Icons.auto_awesome_rounded,
            size: 20.r,
            color: context.colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }
}
