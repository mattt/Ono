# Ono (斧)
**A sensible way to deal with XML for iOS & Mac OS X**

> Ono (斧) means "axe", in homage to [Nokogiri](http://nokogiri.org) (鋸), which means "saw".

## Usage

```objective-c
#import "Ono.h"

NSData *data = ...;
NSError *error;

ONOXMLDocument *document = [ONOXMLDocument XMLDocumentWithData:data error:&error];
for (ONOXMLElement *element in document.rootElement.children) {
    NSLog(@"%@: %@", element.tag, element.attributes);
}

// Automatic Conversion for Number & Date Values
NSDate *date = [[document firstChildWithTag:@"CreatedAt"] dateValue]; // ISO 8601 Timestamp
NSInteger numberOfBytes = [[document firstChildWithTag:@"ContentSize"] numberValue] integerValue];
BOOL isPublic = [[document firstChildWithTag:@"Public"] numberValue] boolValue];

// Support for XPath & CSS Queries
[document enumerateElementsWithXPath:@"//Content" block:^(ONOXMLElement *element) {
    NSLog(@"%@", element);
}];
```

### Contact

[Mattt Thompson](http://github.com/mattt)
[@mattt](https://twitter.com/mattt)

## License

Ono is available under the MIT license. See the LICENSE file for more info.
