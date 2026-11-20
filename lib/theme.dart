import 'package:flutter/material.dart';

/// Slides are laid out on a fixed 1920x1080 canvas and scaled to fit.
const canvasSize = Size(1920, 1080);

/// Google Slides points to canvas pixels (9144000 EMU wide = 1920 px).
double pt(double points) => points * 12700 * 1920 / 9144000;

abstract final class Palette {
  static const accent = Color.fromRGBO(39, 196, 245, 1); // rgb(.153,.769,.961)
  static const text = Color.fromRGBO(244, 247, 251, 1);
  static const muted = Color.fromRGBO(140, 158, 184, 1); // rgb(.55,.62,.72)
  static const soft = Color.fromRGBO(195, 204, 218, 1);
  static const warn = Color.fromRGBO(255, 178, 89, 1);
  static const statBlue = Color.fromRGBO(121, 192, 255, 1);
  static const background = Color.fromRGBO(13, 17, 23, 1);
}

TextStyle zalando(
  double points, {
  double weight = 400,
  Color color = Palette.text,
  bool italic = false,
  double height = 1.15,
}) => TextStyle(
  fontFamily: 'Zalando Sans',
  fontSize: pt(points),
  fontVariations: [FontVariation.weight(weight)],
  fontStyle: italic ? FontStyle.italic : FontStyle.normal,
  color: color,
  height: height,
  letterSpacing: -0.01 * pt(points),
);

/// Bold, the deck's default for headline text.
TextStyle headline(double points, {Color color = Palette.text}) =>
    zalando(points, weight: 700, color: color);
