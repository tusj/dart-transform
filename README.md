dart-transform
==============

Automatic support for encoding and decoding of dart objects in JSON by support of mirrors

## Usage
```dart
import 'package:transform/transform.dart';

// Encodable adds support to extract to JSON
// Decodable adds support to parse from JSON
class A extends Encodable with Decodable {
  var a = "hi";
  var b = 2;
}

void main() {
  var from = new A();
  var json = from.toJson(); // extract to JSON map
  var to = new A()..fromMap(json); // parse from map
  // "to" now contains same content as "from"
}
```

## Status
All unittests passing, but could use some more unittests.
Some ugly code should be cleaned up.
No performance optimization has been done.
