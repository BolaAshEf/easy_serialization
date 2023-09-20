import 'package:equatable/equatable.dart';
import 'utils.dart';

final _typesIDsMap = <Type, TypeID>{};

/// Get an [typeID] for [OBJ] that represent this type only.
/// 
/// [typeID] contains the type id, which is a **List<int>** that can be sent as json.
mixin class TypeHash<OBJ>{
  /// Any Type that is used with [TypeHash] should be stored in [_typesIDsMap].
  /// 
  /// This is because we need to check for Types [hashcodes] collisions.
  TypeID ensureCalcTypeID(){
    final typeID = _typesIDsMap.putIfAbsent(OBJ, () => TypeID(TypeProvider<OBJ>()));

    while(_typesIDsMap.values.containsDuplicates()){
      // increment
      TypeID.setIDsLevel();
    }

    return typeID;
  }

  TypeID get typeID => _typesIDsMap[OBJ] ?? ensureCalcTypeID();
}

const _propHashCodesMarkupName = "\$hash#codes";
/// We pass [TypeProvider] instead of generic type, to make the [runtimeType] is equal at all time
/// for [EquatableMixin] to work properly and compare only the [hashCodes].
class TypeID with SerializableMixin, EquatableMixin{
  final TypeProvider? _provider;
  final List<int>? _mainIDS;
  
  List<int> get hashCodes => _mainIDS
      ?? _provider!.provType(<OBJ>() => _getTypeIDS<OBJ>());

  TypeID(TypeProvider this._provider) : _mainIDS = null;

  @override
  List<Object?> get props => [...hashCodes];

  @override
  MarkupObj toMarkupObj() => {
    _propHashCodesMarkupName : hashCodes,
  };

  TypeID.fromMarkup(MarkupObj markup) : _mainIDS = List.from(markup[_propHashCodesMarkupName]), _provider = null;


  static int _idsLevel = 0;
  static List<int> _getTypeIDS<T>(){
    assert(_idsLevel > -1);

    final typeIDS = <int>[];

    TypeProvider t = TypeProvider<T>();
    typeIDS.add((T).hashCode);
    for(int i = 0; i < _idsLevel; i++){
      t.provType(<CURRENT>(){
        typeIDS.add((List<CURRENT>).hashCode);
        t = TypeProvider<List<CURRENT>>();
      });
    }

    return typeIDS;
  }

  /// The Higher the [level] the lesser the chance of a collision occurs.
  /// 
  /// 1 or at most 2 is a good value.
  static void setIDsLevel([int? level]){
    level ??= _idsLevel + 1;
    assert(level > -1);
    _idsLevel = level;
  }
}


extension _DuplicatesChecker on Iterable{
  bool containsDuplicates(){
    final set = <dynamic>{};
    for(final e in this){
      if(!set.add(e)){return true;}
    }
    return false;
  }
}
