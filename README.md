# Ono (斧)
**A sensible way to deal with XML & HTML for iOS & Mac OS X**

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

// Support for Namespaces
NSString *author = [[document.rootElement firstChildWithTag:@"creator" inNamespace:@"dc"] stringValue];

// Automatic Conversion for Number & Date Values
NSDate *date = [[document.rootElement firstChildWithTag:@"created_at"] dateValue]; // ISO 8601 Timestamp
NSInteger numberOfWords = [[document.rootElement firstChildWithTag:@"word_count"] numberValue] integerValue];
BOOL isPublished = [[document.rootElement firstChildWithTag:@"is_published"] numberValue] boolValue];

// Convenient Accessors for Attributes
NSString *unit = [document.rootElement firstChildWithTag:@"Length"][@"unit"]
NSDictionary *authorAttributes = [[document.rootElement firstChildWithTag:@"author"] attributes];

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
