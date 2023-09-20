<a href="https://www.buymeacoffee.com/bola" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/default-orange.png" alt="Buy Me A Coffee" height="41" width="174"></a>

## Description

This package help you systematically work with serialization, it 
offers great help especially with Serializing Lists and abstract types.

## Usage

* First you start by defining your types.

```dart
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
```

* Secondly you must register these types
 
```dart
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

  // jsut to show you the result of print in the second isolate.
  await Future.delayed(const Duration(seconds: 2));
}
```

* Then you can send and receive the markup between isolates directly
or using json.encode and json.decode if you want it as json string.
Here is the second isolate:

```dart
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
  
  print(ml); // The exact list that is sent.
  print(ml[0][0].offset.dx); // 20

  print(ml.runtimeType); // List<List<Shape>>
  print(ml[0].runtimeType); // List<Circle>
  print(ml[1].runtimeType); // List<Rectangle>
}
```

## Utils

* There is some Utility functions that you can use.

* 1- [TypeProvider<OBJ>] mixin class that ables you to store the generic type [OBJ] and use it dynamically at any time on some object.

```dart
class MyList<E> with TypeProvider<E>{
  final List<E> list;
  const MyList(this.list);
}

void main(){
  final myList = const MyList<int>([5, 6]);
  final dynamicList = myList as MyList;

  dynamicList.provType(<E>() => print(E)); // int
}
```

* 2- The [TypeHash<OBJ>] class of `utils/types_identification.dart` that ables you to get a unique ID(per compiled program) represinting each registered-class.

```dart
class Configration<E> with TypeHash<E>{
  final E obj;
  Configration(this.obj){
    ensureCalcTypeID();
  }
}

void main(){
  final config = Configration<int>(7);
  print(config.typeID.hashCodes); // [List<int>]
}
```

* 3- [withoutEmpties] on [List] that removes any empty list inside the provided list. 

```dart
final list = [1, "A", [],[5,[6],[]], [[[]]]];
print(list.withoutEmpties()); // [1, A, [5, [6]]]
```

* 4- [withSpecificTypes] on [List] that cast the list(and its sublists) to their most specific-registered-types. 
```dart
final list1 = <dynamic>[[1,2], [1.1, 2.2]];
print(list1.runtimeType); // List<dynamic>
final list2 = list1.withSpecificTypes();
print(list2.runtimeType); // List<List<num>>
print(list2[0].runtimeType); // List<int>
print(list2[1].runtimeType); // List<double>
```


## Additional information

* For more detailed example you can see `/example/main.dart`.

* This package is the first step in a series of packages I will publish.
The other packages will help you work asynchronously between isolates or even a distant server
like executing some code inside other isolate or server and wait the result and get some information.
