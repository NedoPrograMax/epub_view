import 'package:flutter/material.dart';

class SelectionToolbarItem extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const SelectionToolbarItem({
    super.key,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: 15,
              letterSpacing: -0.24,
              height: 1.33,
              color: Color.fromRGBO(35, 33, 41, 1),
            ),
          ),
        ),
      ),
    );
  }
}
