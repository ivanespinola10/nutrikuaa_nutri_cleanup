import 'package:flutter/material.dart';

import '../application/commercial_policy.dart';

void showCommercialPolicy(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text(CommercialPolicy.title),
      content: const SizedBox(
        width: 700,
        child: SingleChildScrollView(
          child: SelectableText(
            '${CommercialPolicy.privacy}\n\n'
            '${CommercialPolicy.terms}\n\n'
            'Versión: ${CommercialPolicy.version}',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}
