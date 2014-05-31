library test;

import 'package:encodable/transform.dart';
import 'package:unittest/unittest.dart';

class Test {
  List<String> a;
  String b;
}

final val = "hello";
final setMap = {'a': val};
final subMap = {'a': setMap};
final nullMap = {'a': null};
final intMap = {'a': 1};
final stringMap = {'a': "hello"};
final extendedMap = {'a': val, 'b': val};

class Private extends Decodable with Encodable {
  var _a;
}

class Empty extends Decodable with Encodable {
  var a;
}

class Some extends Decodable with Encodable {
  var a = val;
}

class Extended extends Some with Decodable, Encodable {
  var b = val;
}

class Super {
  var b = val;
}

class MultipleExtended extends Some with Super, Decodable, Encodable {
}

class Sub extends Decodable with Encodable {
  Some a = new Some()..a = val;
}

class Specific extends Decodable with Encodable {
  String a;
}

class SpecificSub extends Decodable with Encodable {
  Specific a;
}

class SpecificList extends Decodable {
  List<String> a;
}

class SpecificMap extends Decodable {
  Map<String, String> a;
}


void main() {
  
  group('encodable', () {
    group('toJson', () {
      
      test('empty', () {
        expect(new Empty().toJson(), isEmpty);
        expect(new Empty().toJson(includeEmpty: true), equals(nullMap));
      });
      
      test('private', () {
        expect(new Private().toJson(), isEmpty);
      });
      
      test('some', () {
        expect(new Some().toJson(), equals(setMap));
      });
      
      test('sub', () {
        expect(new Sub().toJson(), equals(subMap));
      });
      
      test('inherited', () {
        var e = new Extended();
        e.a = "blob";
        expect(e.toJson(), equals(extendedMap));
      });
      
      test('multiple inherit', () {
        expect(new MultipleExtended().toJson(), equals(extendedMap));
      });
      
      test('cycle', () {
        var a = new Empty();
        var b = new Empty();
        a.a = b;
        b.a = a;
        expect(() => a.toJson(), throws);
      });
      
      test('not include empty', () {
        var e = new Empty()..a = new Empty();
        expect(e.toJson(), equals({}));
      });
      
      test('list', () {
        var l = new Empty()..a = [new Empty()];
        expect(l.toJson(), isEmpty);
        expect(l.toJson(includeEmpty: true), equals({'a': [nullMap]}));
      });
      
      test('map', () {
        var l = new Empty()..a = {'a': new Empty()};
        expect(l.toJson(), equals({}));
        expect(l.toJson(includeEmpty: true), {'a': {'a': nullMap}});
      });
    });
  });
  
  group("decodable", () {
    group("fromJson", () {
      
      test('valid', () {
        var e = new Empty()..fromMap(setMap);
        expect(e.toJson(), equals(setMap));
      });
      
      
      test('invalid', () {
        expect(() => new Specific()..fromMap(intMap), throws);
        expect(() => new Specific()..fromMap({}, throwOnMissingKey: true), throws);
  
        var s = new Specific()..fromMap({});
        expect(s.toJson(), equals({}));
      });
      
      test('inherited', () {
        var e = new Extended()..fromMap(extendedMap);
        expect(e.toJson(), equals(extendedMap));
      });
      
      test('specific sub', () {
        var s = new SpecificSub()..fromMap(subMap);
        expect(s.toJson(), equals(subMap));
      });
      
      test('unknown type', () {
        var s = new Some()..fromMap(setMap);
        expect(s.toJson(), setMap);
        
        s.a = new List<String>();
        s.a.add("hello");
        expect(s.toJson(), equals({'a': ["hello"]}));
      });
    });
    
    group("validate", () {
      
      test('valid type', () {
        expect(new Specific().validate({'a': ""}), isTrue);
      });
      
      test('invalid type', () {
        expect(new Specific().validate({'a': 1}), isFalse);
      });
      
      test('should not modify', () {
        var s = new Specific()..validate(setMap);
        expect(s.toJson(), equals({}));
      });
      
      test('contains extra keys', () {
        expect(new Specific().validate({'a': "", 'b': ""}), isTrue);
      });
      
      test('missing key', () {
        expect(new Specific().validate({}), isFalse);
      });
      
  
      group('list', () {
        test('wrong specific type', () {
          expect(new SpecificList().validate({'a': new List<int>()}), isFalse);
        });
        
        test('correct specific type', () {
          expect(new SpecificList().validate({'a': new List<String>()}), isTrue);
        });
        
        test('general, wrong content type', () {
          expect(new SpecificList().validate({'a': [1]}), isFalse);
        });
        
        test('general, correct content type', () {
          expect(new SpecificList().validate({'a': ['a']}), isTrue);
        });
      });
      
      
      group('map', () {
        test('specific, wrong template type', () {
          expect(new SpecificMap().validate({'a': new Map<String, int>()}), isFalse);
        });
        
        test('specific, wrong key type', () {
          expect(new SpecificMap().validate({'a': new Map<int, String>()}), isFalse);
        });
        
        test('general, wrong content type', () {
          expect(new SpecificMap().validate({'a': {'a': 1}}), isFalse);
        });
        
        test('general, correct content type', () {
          expect(new SpecificMap().validate({'a': {'a': 'a'}}), isTrue);
        });
      });
    });
  });
}