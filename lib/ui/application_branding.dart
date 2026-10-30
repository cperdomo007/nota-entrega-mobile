import 'package:flutter/material.dart';

/// Identidad de Nota Entrega junto a la marca de Sumisistemas.
class ApplicationBranding extends StatelessWidget {
  const ApplicationBranding({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.receipt_long, size: compact ? 28 : 64),
      SizedBox(width: compact ? 8 : 16),
      if (compact) ...[
        Expanded(
          child: Text(
            'Nota Entrega',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(width: 8),
      ],
      Flexible(
        flex: compact ? 0 : 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ColoredBox(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Image.asset(
                'assets/branding/sumisistemas.jpg',
                width: compact ? 96 : 280,
                height: compact ? 44 : 124,
                fit: BoxFit.contain,
                semanticLabel: 'Sumisistemas, C.A.',
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
