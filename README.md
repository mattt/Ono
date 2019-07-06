# Ono (斧)

Foundation lacks a convenient, cross-platform way to work with HTML and XML.
[`NSXMLParser`](https://developer.apple.com/documentation/foundation/nsxmlparser?language=objc)
is an event-driven,
[<abbr title="Simple API for XML">SAX</abbr>](https://en.wikipedia.org/wiki/Simple_API_for_XML)-style API
that can be cumbersome to work with.
[`NSXMLDocument`](https://developer.apple.com/documentation/foundation/nsxmldocument),
offers a more convenient
[<abbr title="Document Object Model">DOM</abbr>](https://en.wikipedia.org/wiki/Document_Object_Model)-style API,
but is only supported on macOS.

**Ono offers a sensible way to work with XML & HTML on Apple platforms in Objective-C and Swift**

Whether your app needs to
scrape a website, parse an RSS feed, or interface with a XML-RPC webservice,
Ono will make your day a whole lot less terrible.

> Ono (斧) means "axe", in homage to [Nokogiri](http://nokogiri.org) (鋸), which means "saw".

## Features

- [x] Simple, modern API following standard Objective-C conventions, including extensive use of blocks and `NSFastEnumeration`
- [x] Extremely performant document parsing and traversal, powered by `libxml2`
- [x] Support for both [XPath](http://en.wikipedia.org/wiki/XPath) and [CSS](http://en.wikipedia.org/wiki/Cascading_Style_Sheets) queries
- [x] Automatic conversion of date and number values
- [x] Correct, common-sense handling of XML namespaces for elements and attributes
- [x] Ability to load HTML and XML documents from either `NSString` or `NSData`
- [x] Full documentation
- [x] Comprehensive test suite

## Installation

[CocoaPods](http://cocoapods.org) is the recommended method of installing Ono.
Add the following line to your `Podfile`:

#### Podfile

```ruby
pod 'Ono'
```

## Usage

### Swift

```swift
import Foundation
import Ono

guard let url = Bundle.main.url(forResource: "nutrition", withExtension: "xml"),
    let data = try? Data(contentsOf: url) else
{
    fatalError("Missing resource: nutrition.xml")
}

let document = try ONOXMLDocument(data: data)
document.rootElement.tag

for element in document.rootElement.children.first?.children ?? [] {
    let nutrient = element.tag
    let amount = element.numberValue!
    let unit = element.attributes["units"]!

    print("- \(amount)\(unit) \(nutrient)")
}

document.enumerateElements(withXPath: "//food/name") { (element, _, _) in
    print(element)
}

document.enumerateElements(withCSS: "food > serving[units]") { (element, _, _) in
    print(element)
}
```

### Objective-C

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
NSInteger numberOfWords = [[[document.rootElement firstChildWithTag:@"word_count"] numberValue] integerValue];
BOOL isPublished = [[[document.rootElement firstChildWithTag:@"is_published"] numberValue] boolValue];

// Convenient Accessors for Attributes
NSString *unit = [document.rootElement firstChildWithTag:@"Length"][@"unit"];
NSDictionary *authorAttributes = [[document.rootElement firstChildWithTag:@"author"] attributes];

// Support for XPath & CSS Queries
[document enumerateElementsWithXPath:@"//Content" usingBlock:^(ONOXMLElement *element, NSUInteger idx, BOOL *stop) {
    NSLog(@"%@", element);
}];
```

## Demo

Build and run the example project in Xcode to see `Ono` in action,
or check out the provided Swift Playground.

## Requirements

Ono is compatible with iOS 5 and higher, as well as macOS 10.7 and higher.
It requires the `libxml2` library,
which is included automatically when installed with CocoaPods,
or added manually by adding "libxml2.dylib"
to the target's "Link Binary With Libraries" build phase.

## Contact

[Mattt](https://twitter.com/mattt)

## License

Ono is available under the MIT license.
See the LICENSE file for more info.
