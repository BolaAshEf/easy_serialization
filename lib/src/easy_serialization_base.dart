import 'dart:isolate';
import '../utils/types_identification.dart';
import '../utils/utils.dart';

part 'generic_handling.dart';
part 'prop.dart';


//*/////////////////////////// Type Definitions ///////////////////////////*//

typedef ToMarkupObjCallback<OBJ extends Object> = MarkupObj Function(OBJ obj);
typedef FromMarkupObjCallback<OBJ extends Object> = OBJ Function(MarkupObj markupObj);




//*/////////////////////////// Type Nodes System ///////////////////////////*//

final _headSerializationNode = _SerializationNode.objectSerializationNode;
final _serializationNodes = <TypeID, _SerializationNode>{
  SerializationConfig._objectConfig.typeID : _SerializationNode.objectSerializationNode,
};

/// Before we start any serialization process we must ensure that primitive types are registered.
bool _primitivesAdded = false;


final _primitivesSerializableObjects = <SerializationConfig>[
  /// The types that can be serialized directly 
  /// in any circumstances(between isolates or as json).
  SerializationConfig<num>._primitive(),
  SerializationConfig<int>._primitive(),
  SerializationConfig<double>._primitive(),
  SerializationConfig<String>._primitive(),
  SerializationConfig<bool>._primitive(),

  // TODO : These types can be sent only between isolates.
  SerializationConfig<SendPort>._primitive(), 
  SerializationConfig<Capability>._primitive(),

  /// This does NOT mean that enum is sendable by default.
  /// 
  /// It only means that this is a parent node for all [Enum] types.
  /// 
  /// ** Also Note that if you work with same-code-isolates 
  /// you can forget about registering [Enum] types.** 
  SerializationConfig<Enum>._primitive(),
];


/// This is used so we can store all Types in tree-like-structure 
/// , so we can work with type inheritance.
/// 
/// This enables us to always use the most-specific-registered-type to serialize some Object.
class _SerializationNode{
  static final objectSerializationNode = _SerializationNode(SerializationConfig._objectConfig);

  final SerializationConfig config;
  _SerializationNode? parent;
  final children = <_SerializationNode>[];

  _SerializationNode(this.config);


  /// [nodeParamParent] is almost always [_headSerializationNode].
  static _SerializationNode? _getParentNode(
      _SerializationNode createdNode,
      _SerializationNode nodeParamParent,
      [_SerializationNode? parent]
      ){
    for(final nodeParam in nodeParamParent.children){
      if(createdNode.isChildTo(nodeParam)){
        return _getParentNode(createdNode, nodeParam, nodeParam);
      }
    }

    return parent;
  }

  /// Gets the most direct parent for [createdNode] 
  /// between already registered nodes until now.
  static _SerializationNode getParentNode(_SerializationNode createdNode) => 
      _getParentNode(createdNode, _headSerializationNode) ?? _headSerializationNode;

  bool isParentTo(_SerializationNode node) => config.isParentTo(node.config);
  bool isChildTo(_SerializationNode node) => config.isChildTo(node.config);
  bool isParentToObj(Object obj) => config.isParentToObj(obj);
}



//*/////////////////////////// Types Configration System ///////////////////////////*//

const _unitTypePropName = "\$unit#type";

/// **Note** : it is necessary to provide [OBJ] type.
/// 
/// Forbidden Types:
///   * configure the object without declaring it is nullable(this will be handled automatically).
///   * Do NOT configure [List], [Set], [Map] or and **special** generic type.
class SerializationConfig<OBJ extends Object> with TypeProvider<OBJ>, TypeHash<OBJ>{
  static MarkupObj _objectToSerialization<PREM extends Object>(PREM obj) => {_unitTypePropName: obj,};
  static PREM _objectFromSerialization<PREM extends Object>(MarkupObj markup) => markup[_unitTypePropName];

  /// This is the default serialization for all non-registered configs(including primitive types).
  static final _objectConfig = SerializationConfig<Object>._(
    _objectFromSerialization,
    _objectToSerialization,
  );

  final ToMarkupObjCallback<OBJ>? _toMarkupObjCallback;
  final FromMarkupObjCallback<OBJ> _fromMarkupObj;

  SerializationConfig._(this._fromMarkupObj, this._toMarkupObjCallback){
    ensureCalcTypeID();
  }

  SerializationConfig({
    required FromMarkupObjCallback<OBJ> fromMarkupObj,
    required ToMarkupObjCallback<OBJ> toMarkupObj,
  }) : assert(_checkType<OBJ>()), _toMarkupObjCallback = toMarkupObj, _fromMarkupObj = fromMarkupObj{
    ensureCalcTypeID();
  }

  static SerializationConfig abstract<SER_OBJ extends SerializableMixin>(){
    assert(_checkType<SER_OBJ>());
    const err = SerializationError("This type is abstract, so you must configure its children.");
    return SerializationConfig<SER_OBJ>(
      fromMarkupObj: (_) => throw err,
      toMarkupObj: (_) => throw err,
    );
  }

  static SerializationConfig serializable<SER_OBJ extends SerializableMixin>(FromMarkupObjCallback<SER_OBJ> fromMarkupObj){
    assert(_checkType<SER_OBJ>());
    return SerializationConfig<SER_OBJ>._(fromMarkupObj, null,);
  }

  factory SerializationConfig._primitive() => SerializationConfig<OBJ>._(
    (markup) => _objectFromSerialization<OBJ>(markup),
    (obj) => _objectToSerialization<OBJ>(obj),
  );

  static SerializationConfig? _getMostSpecificObjectChildrenConfig(Object obj, _SerializationNode nodeParamParent){
    for(final nodeParam in nodeParamParent.children){
      if(nodeParam.isParentToObj(obj)){
        final specificConfig = _getMostSpecificObjectChildrenConfig(obj, nodeParam,);
        return specificConfig ?? nodeParam.config;
      }
    }

    return null;
  }

  static SerializationConfig _getMostSpecificConfig(Object obj) =>
      _getMostSpecificObjectChildrenConfig(
        obj,
        _SerializationNode.objectSerializationNode,
      ) ?? SerializationConfig._objectConfig;

  MarkupObj _toMarkupObj(OBJ obj) => _toMarkupObjCallback != null
      ? _toMarkupObjCallback!(obj)
      : (obj as SerializableMixin).toMarkupObj();



  bool isParentTo(SerializationConfig other) =>
      other.provType(<OTHER>() => provType(<MINE>() => isSubtype<OTHER, MINE>()),);

  bool isChildTo(SerializationConfig other) =>
      other.provType(<OTHER>() => provType(<MINE>() => isSubtype<MINE, OTHER>()),);

  bool isParentToObj(Object obj) =>
      provType(<MINE>() => obj is MINE);

  static bool _checkType<TYPE>(){
    return !isSubtype<TYPE?, TYPE>() && TYPE != (Object)
        && !TYPE.toString().contains("<")
        && !TYPE.toString().contains("?")
        && !isSubtype<TYPE, List>()
        && !isSubtype<TYPE, Map>();
  }
}


const _enumTypePropName = "\$enum#type";

/// Basic Configration for [Enum] types that identify an enum using its [index].
/// 
/// You can quickly use create a configration just by calling [config] on any Enum.values List.
/// 
/// **Note** : it is necessary to provide [OBJ] type.
class EnumSerializationConfig<OBJ extends Enum> extends SerializationConfig<OBJ>{
  static MarkupObj _enumToSerialization<E extends Enum>(E obj) => {_enumTypePropName: obj.index,};
  static E _enumFromSerialization<E extends Enum>(MarkupObj markup, List<E> enumValues) => enumValues[markup[_enumTypePropName]];

  EnumSerializationConfig(List<OBJ> enumValues,) : super._(
        (markup) => _enumFromSerialization<OBJ>(markup, enumValues),
        (obj) => _enumToSerialization<OBJ>(obj),
  );
}



//*/////////////////////////// Extensions and Other Things ///////////////////////////*//


/// Special class type that we use as a represintitave of [null].
/// 
/// We use it just to get unique id for [null].
abstract class _NullObj{const _NullObj._();}
final _nullConfigId = TypeHash<_NullObj>().typeID;

extension EnumSerializationConfigExt<E extends Enum> on List<E>{
  EnumSerializationConfig<E> get config => EnumSerializationConfig<E>(this);
}

class SerializationError<OBJ extends Object> implements Exception{
  final OBJ errorObj;
  const SerializationError(this.errorObj);

  @override
  String toString() => errorObj.toString();
}
