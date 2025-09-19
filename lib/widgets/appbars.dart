import 'package:flutter/material.dart';

/// Top-level app bar used across screens.
/// Set [transparent] to true when using a gradient background and
/// `extendBodyBehindAppBar: true` on the Scaffold.
PreferredSizeWidget topLevelAppBar(String title, {bool transparent = false}) {
  return AppBar(
    title: Text(title),
    centerTitle: true,
    elevation: 0,
    backgroundColor: transparent ? Colors.transparent : null, // use theme otherwise
    foregroundColor: transparent ? Colors.white : null,       // readable over gradient
  );
}