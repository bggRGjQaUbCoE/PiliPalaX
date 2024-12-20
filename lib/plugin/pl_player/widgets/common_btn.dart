import 'package:flutter/material.dart';

class ComBtn extends StatelessWidget {
  final Widget? icon;
  final GestureTapCallback? fuc;

  const ComBtn({
    this.icon,
    this.fuc,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: GestureDetector(
        onTap: fuc,
        child: icon!,
      ),
    );
  }
}
