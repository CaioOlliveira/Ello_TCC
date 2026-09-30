import 'package:flutter/material.dart';

void showEditPermissionDenied(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text(
          'Você não tem permissão para editar esta funcionalidade.',
        ),
      ),
    );
}
