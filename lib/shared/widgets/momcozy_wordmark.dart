import 'package:flutter/material.dart';

/// Displays the approved wordmark within the same crop as the product design.
class MomCozyWordmark extends StatelessWidget {
  const MomCozyWordmark({super.key, this.width = 100});
  final double width;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Momcozy',
    image: true,
    child: ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: width * .24,
        child: ClipRect(
          child: Stack(
            children: [
              Positioned(
                left: -width * .02,
                top: -width * .19,
                width: width * 1.04,
                child: Image.asset('assets/images/momcozy_logo.png'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
