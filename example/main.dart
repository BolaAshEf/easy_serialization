import 'dart:isolate';

import 'package:easy_serialization/easy_serialization.dart';

final customSerializableObjects = <SerializationConfig>[
  /// How to configure a Type that is NOT yours(from different library),
  /// or just types you do NOT want to use [SerializableMixin] with.
  SerializationConfig<Offset>(
    toMarkupObj: (obj) => {"dx": obj.dx, "dy": obj.dy,},
    fromMarkupObj: (markup) => Offset(markup["dx"], markup["dy"],),
  ),

  /// How to configure Enum Type.
  ShapeFillType.values.config,

  /// How to configure your types.
  
  /// [SerializationConfig.abstract] is used for createing a List of that abstract type. 
  SerializationConfig.abstract<Shape>(),
  SerializationConfig.serializable<Circle>(Circle.fromMarkup),
  SerializationConfig.serializable<Rectangle>(Rectangle.fromMarkup),
  SerializationConfig.serializable<Square>(Square.fromMarkup),
];

void main() async {
  // You must configure this exact list at FIRST in each new isolate or service you use.
  Prop.registerSerializationConfigs(customSerializableObjects);

  final circle = Circle(5.0)
    ..fill = ShapeFillType.solid
    ..offset = Offset(20, 20);

  final rect = Rectangle(10, 10)
    ..fill = ShapeFillType.outlined
    ..offset = Offset(10, 10);

  final square = Square(75);


  final list = <List<Shape>>[[circle], [rect, square], []];

  /// [Prop.valueToMarkup] and [Prop.valueFromMarkup] will figure the type statically,
  /// but it is preferable to pass the types explicitly, specially for [List].

  /// Notice here you MUST provide an empty list instance.
  /// 
  /// This markup can be sent to any isolate, 
  /// or if you want json parse it using json.encode and json.decode.
  final msg = Prop.valueToMarkup<List<List<Shape>>>(list, emptyList: []);

  Isolate.spawn(isolateMain, msg);

  await Future.delayed(const Duration(seconds: 2));
}

/// This could be the entrypoint of any service like [flutter_background_service] package
/// or overlay service like [overlay_window] package,
/// 
/// or even a client-server-app
/// (But in this case both must be compiled together[in future updates this will become clear]).
void isolateMain(MarkupObj msg) {
  // You must configure this exact list at FIRST in each new isolate or service you use.
  Prop.registerSerializationConfigs(customSerializableObjects);

  /// Notice here you MUST provide an empty list instance.
  /// Notice here any inner empty list will be ignored.
  final ml = Prop.valueFromMarkup<List<List<Shape>>>(
    msg, emptyList: [],
  );
  
  print(ml);
  print(ml[0][0].offset.dx); // 20

  print(ml.runtimeType); // List<List<Shape>>
  print(ml[0].runtimeType); // List<Circle>
  print(ml[1].runtimeType); // List<Rectangle>
}


/// Representative of [Offset] type that comes with Flutter SDK.
class Offset{
  final double dx, dy;
  const Offset(this.dx, this.dy);
}

enum ShapeFillType{
  solid,
  outlined,
}

abstract class Shape with SerializableMixin{
  Offset offset = const Offset(0, 0);
  ShapeFillType fill = ShapeFillType.solid;
  Shape();

  double area();

  /// If these objects are primitives then pass them directly,
  /// else use [Prop] to serialize them like this.
  @override
  MarkupObj toMarkupObj() => {
    "offset" : Prop.valueToMarkup(offset),
    "fill" : Prop.valueToMarkup(fill),
  };

  /// If these objects are primitives then pass them directly,
  /// else use [Prop] to serialize them like this.
  Shape.fromMarkup(MarkupObj markup) :
    offset = Prop.valueFromMarkup(markup["offset"]),
    fill = Prop.valueFromMarkup(markup["fill"]);
}

class Circle extends Shape{
  double radius;
  Circle(this.radius);

  @override
  double area() => 3.14 * radius * radius;

  @override
  MarkupObj toMarkupObj() => {
    ...super.toMarkupObj(),
    "radius" : radius,
  };

  Circle.fromMarkup(MarkupObj markup) : 
    radius = markup["radius"], 
    super.fromMarkup(markup);
}

class Rectangle extends Shape {
  double height, width;
  Rectangle(this.height, this.width);

  @override
  double area() => height * width;

  @override
  MarkupObj toMarkupObj() => {
    ...super.toMarkupObj(),
    "height" : height,
    "width" : width,
  };

  Rectangle.fromMarkup(MarkupObj markup) : 
    height = markup["height"],
    width = markup["width"],  
    super.fromMarkup(markup);
}

class Square extends Rectangle{
  Square(double sideLen) : super(sideLen, sideLen);

  Square.fromMarkup(MarkupObj markup) : super.fromMarkup(markup);
}
