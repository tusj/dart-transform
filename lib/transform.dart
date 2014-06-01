library transform;

import 'dart:mirrors';
import 'package:zip/zip.dart';
import 'package:tuple/tuple.dart';

final toJsonMaxDepth = 100;

abstract class Encoder {
  Map toJson();
}

abstract class Decoder {
  fromMap(Map);
}

abstract class Validator {
  bool validate(Map);
}


class DepthError {
  final msg = "toJson depth of ${toJsonMaxDepth} is exceeded";
}

abstract class Encodable implements Encoder {
  Map toJson({bool includeEmpty: false}) =>
    _toJson(0, includeEmpty: includeEmpty);
  
  Map _toJson(int depth, {bool includeEmpty: false}) {
    if (depth > toJsonMaxDepth) {
      throw(new DepthError());
    }
    var m = {};
    var shouldInclude = (v) {
      if (includeEmpty) {
        return true;
      }
      
      if (v is List || v is Map) {
        return !v.isEmpty;
      }
      
      if (v == null) {
        return false;
      }
      return true;
    };
    
    var transform = (val) {
      var v;
      try {
        v = val._toJson(depth + 1, includeEmpty: includeEmpty);
      } on DepthError catch(e) {
        throw(e);
      } catch(e) {
        try {
          v = val.toJson();
        } catch(e) {
          v = val;
        }
      }
      return v;
    };
    
    var add = (m, k, val) {
      var v = transform(val);
      if (shouldInclude(v)) {
        m[k] = v;
      }
    };
    
    InstanceMirror im = reflect(this);
    ClassMirror cm = im.type;
    
    
    var vars = zip([cm.instanceMembers.keys, cm.instanceMembers.values])
        .where((e) => e.last.isGetter)
        .where((e) => !e.last.isPrivate)
        .where((e) => e.last.isSynthetic) // TODO Add test for non-synthetic
        .map((e) => new Tuple<Symbol, MethodMirror>(e.first, e.last));
 
    for (var field in vars) {
      var s = field.first;
      var v = field.last;
      var name = MirrorSystem.getName(field.first);
      
      var val = im.getField(v.simpleName).reflectee;
      
      if (!shouldInclude(val)) {
        continue;
      }
      
      if (val is List) {
        var l = [];
        val.forEach((e) {
          var v = transform(e);
          if (shouldInclude(v)) {
            l.add(v);
          }
        });
        val = l;

      } else if (val is Map) {
        var m = {};
        val.forEach((k, v) {
          add(m, k, v);
        });
        val = m;
      }
      
      add(m, name, val);
    }
    
    return m;
  }
}

// allows partial updates
// disallows incorrect type assignments
abstract class Decodable implements Decoder, Validator {
  final RegExp _simpleSymbolRegExp = new RegExp(r'Symbol\("([a-zA-Z]+)"\)');
  
  // Checks if m contains all the keys of name equal to the fields
  // of the class in question and of the right type
  // m can contain extra keys
  bool validate(Map m) =>
    _set(m, validateOnly: true);
  

  
  // Sets the values of the map to the members of the class
  fromMap(Map m, {bool throwOnMissingKey: false}) {
      _set(m, throwOnMissingKey: throwOnMissingKey);
  }
  
  // Validates and or sets the member variables to the values of the map
  // Returns true on success
  bool _set(Map m, {bool validateOnly: false, bool throwOnMissingKey: false}) {
    
    InstanceMirror im = reflect(this);

    var setIfNotValidate = (Symbol k, object) {
        if (!validateOnly) {
          im.setField(k, object);
        }
    };
    
    var throwInvalidAssignment = (Map m, name, VariableMirror v) =>
        throw("key \"$name\" of type ${m[name].runtimeType} is not assignable to type ${v.type.reflectedType}");
    
    var cm = im.type;
    var varsKeys = cm.declarations.keys
        .where((e) => cm.declarations[e] is VariableMirror);
    
    // Check for missing keys
    if (!varsKeys.every((s) => m.containsKey(MirrorSystem.getName(s)))) {
      if (validateOnly) {
        return false;
      }
      if (throwOnMissingKey) {
        throw("Some keys are missing");
      }
    }
    
    // For every field
    for (var k in varsKeys) {
      var v = cm.declarations[k] as VariableMirror;
      var name = MirrorSystem.getName(k);
      var val = m[name];

      // Is directly assignable?
      if (reflect(val).type.isAssignableTo(v.type)) {
        setIfNotValidate(v.simpleName, val);
        continue;
      }

      // Is map? Try to call fromMap
      if (val is Map) {
        
        var newObject = reflectClass(v.type.reflectedType).newInstance(new Symbol(''), []).reflectee;
        
        try {
          var canSet = newObject._set(val);
          if (canSet) {
            setIfNotValidate(v.simpleName, newObject);
            continue;
          }
        } catch (e) {
          if (validateOnly) {
            return false;
          }
          throwInvalidAssignment(m, name, v);
        }
      }
      
      // Is list? Check if list content is correct type
      if (val is List) {
        var valSpecific = reflect(val).type.typeArguments.first;
        var vSpecific   = v.type.typeArguments.first;
        
        if (valSpecific.reflectedType == dynamic) {

          if (val.every((e) => reflect(e).type.isAssignableTo(vSpecific))) {
            setIfNotValidate(v.simpleName, val);
            continue;
          }
          
          if (validateOnly) {
            return false;
          }
          throwInvalidAssignment(m, name, v);
        }

        if (valSpecific.isAssignableTo(vSpecific)) {
          setIfNotValidate(v.simpleName, val);
          continue;
        }
      }
      
      // No valid assignment
      if (validateOnly) {
        return false;
      }
      throwInvalidAssignment(m, name, v);
    }
    return true;
  }
}