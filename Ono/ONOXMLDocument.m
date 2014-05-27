// ONOXMLDocument.m
//
// Copyright (c) 2014 Mattt Thompson (http://mattt.me/)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "ONOXMLDocument.h"

#import <libxml2/libxml/xmlreader.h>
#import <libxml2/libxml/xpath.h>
#import <libxml2/libxml/HTMLparser.h>

static NSRegularExpression * ONOIdRegularExpression() {
    static NSRegularExpression *_ONOIdRegularExpression = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _ONOIdRegularExpression = [NSRegularExpression regularExpressionWithPattern:@"\\#([\\w-_]+)" options:(NSRegularExpressionOptions)0 error:nil];
    });

    return _ONOIdRegularExpression;
}

static NSRegularExpression * ONOClassRegularExpression() {
    static NSRegularExpression *_ONOClassRegularExpression = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _ONOClassRegularExpression = [NSRegularExpression regularExpressionWithPattern:@"\\.([^\\.]+)" options:(NSRegularExpressionOptions)0 error:nil];
    });

    return _ONOClassRegularExpression;
}

static NSRegularExpression * ONOAttributeRegularExpression() {
    static NSRegularExpression *_ONOAttributeRegularExpression = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _ONOAttributeRegularExpression = [NSRegularExpression regularExpressionWithPattern:@"\\[(\\w+)\\]" options:(NSRegularExpressionOptions)0 error:nil];
    });

    return _ONOAttributeRegularExpression;
}

NSString * ONOXPathFromCSS(NSString *CSS) {
    NSMutableArray *mutableXPathExpressions = [NSMutableArray array];
    [[CSS componentsSeparatedByString:@","] enumerateObjectsUsingBlock:^(NSString *expression, NSUInteger idx, BOOL *stop) {
        if (expression && [expression length] > 0) {
            __block NSMutableArray *mutableXPathComponents = [NSMutableArray arrayWithObject:@"./"];
            __block NSString *prefix = nil;

            [[[expression stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] enumerateObjectsUsingBlock:^(NSString *token, NSUInteger idx, __unused BOOL *stop) {
                if ([token isEqualToString:@"*"] && idx != 0) {
                    [mutableXPathComponents addObject:@"/*"];
                } else if ([token isEqualToString:@">"]) {
                    prefix = @"";
                } else if ([token isEqualToString:@"+"]) {
                    prefix = @"following-sibling::*[1]/self::";
                } else if ([token isEqualToString:@"~"]) {
                    prefix = @"following-sibling::";
                } else {
                    if (!prefix && idx != 0) {
                        prefix = @"descendant::";
                    }

                    NSRange symbolRange = [token rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"#.[]"]];
                    if (symbolRange.location != NSNotFound) {
                        NSMutableString *mutableXPathComponent = [NSMutableString stringWithString:[token substringToIndex:symbolRange.location]];
                        NSRange range = NSMakeRange(0, [token length]);

                        {
                            NSTextCheckingResult *result = [ONOIdRegularExpression() firstMatchInString:CSS options:(NSMatchingOptions)0 range:range];
                            if ([result numberOfRanges] > 1) {
                                [mutableXPathComponent appendFormat:@"%@[@id = '%@']", (symbolRange.location == 0) ? @"*" : @"", [token substringWithRange:[result rangeAtIndex:1]]];
                            }
                        }

                        {
                            for (NSTextCheckingResult *result in [ONOClassRegularExpression() matchesInString:token options:(NSMatchingOptions)0 range:range]) {
                                if ([result numberOfRanges] > 1) {
                                    [mutableXPathComponent appendFormat:@"%@[contains(concat(' ',normalize-space(@class),' '),' %@ ')]", (symbolRange.location == 0) ? @"*" : @"", [token substringWithRange:[result rangeAtIndex:1]]];
                                }
                            }
                        }

                        {
                            for (NSTextCheckingResult *result in [ONOAttributeRegularExpression() matchesInString:token options:(NSMatchingOptions)0 range:range]) {
                                if ([result numberOfRanges] > 1) {
                                    [mutableXPathComponent appendFormat:@"[@%@]", [token substringWithRange:[result rangeAtIndex:1]]];
                                }
                            }
                        }

                        token = mutableXPathComponent;
                    }

                    if (prefix) {
                        token = [prefix stringByAppendingString:token];
                        prefix = nil;
                    }

                    [mutableXPathComponents addObject:token];
                }
            }];

            [mutableXPathExpressions addObject:[mutableXPathComponents componentsJoinedByString:@"/"]];
        }
    }];

    return [mutableXPathExpressions componentsJoinedByString:@" | "];
}

static BOOL ONOXMLNodeMatchesTagInNamespace(xmlNodePtr node, NSString *tag, NSString *namespace) {
    BOOL matchingTag = !tag || [[NSString stringWithUTF8String:(const char *)node->name] compare:tag options:NSCaseInsensitiveSearch] == NSOrderedSame;

    BOOL matchingNamespace = !namespace ? YES : (((node->ns != NULL) && (node->ns->prefix != NULL)) ? [[NSString stringWithUTF8String:(const char *)node->ns->prefix] compare:namespace options:NSCaseInsensitiveSearch] == NSOrderedSame : NO);

    return matchingTag && matchingNamespace;
}

@interface ONOXPathEnumerator : NSEnumerator <NSFastEnumeration>
@end

@interface ONOXPathEnumerator ()
@property (readwrite, nonatomic, assign) xmlXPathObjectPtr xmlXPath;
@property (readwrite, nonatomic, assign) NSUInteger cursor;
@property (readwrite, nonatomic, strong) ONOXMLDocument *document;
@end

@interface ONOXMLElement ()
@property (readwrite, nonatomic, assign) xmlNodePtr xmlNode;
@property (readwrite, nonatomic, weak) ONOXMLDocument *document;
@end

@interface ONOXMLDocument ()
@property (readwrite, nonatomic, assign) xmlDocPtr xmlDocument;
@property (readwrite, nonatomic, strong) ONOXMLElement *rootElement;
@property (readwrite, nonatomic, copy) NSString *version;
@property (readwrite, nonatomic, strong) NSNumberFormatter *numberFormatter;
@property (readwrite, nonatomic, strong) NSDateFormatter *dateFormatter;

- (ONOXMLElement *)elementWithNode:(xmlNodePtr)node;
- (ONOXPathEnumerator *)enumeratorWithXPathObject:(xmlXPathObjectPtr)XPath;
@end

#pragma mark -

@implementation ONOXPathEnumerator

- (void)dealloc {
    if (_xmlXPath) {
        xmlXPathFreeObject(_xmlXPath);
    }
}

- (id)objectAtIndex:(NSUInteger)idx {
    if (idx >= (NSUInteger)xmlXPathNodeSetGetLength(self.xmlXPath->nodesetval)) {
        return nil;
    }

    return [self.document elementWithNode:self.xmlXPath->nodesetval->nodeTab[idx]];
}

#pragma mark - NSEnumerator

- (NSArray *)allObjects {
    NSMutableArray *mutableObjects = [NSMutableArray arrayWithCapacity:(NSUInteger)self.xmlXPath->nodesetval->nodeNr];
    for (NSInteger idx = 0; idx < xmlXPathNodeSetGetLength(self.xmlXPath->nodesetval); idx++) {
        ONOXMLElement *element = [self objectAtIndex:idx];
        if (element) {
            [mutableObjects addObject:element];
        }
    }

    return [NSArray arrayWithArray:mutableObjects];
}

- (id)nextObject {
    if (self.cursor >= (NSUInteger)self.xmlXPath->nodesetval->nodeNr) {
        return nil;
    }

    return [self objectAtIndex:((NSUInteger)self.cursor++)];
}

@end

#pragma mark -

@implementation ONOXMLDocument

+ (instancetype)XMLDocumentWithString:(NSString *)string
                             encoding:(NSStringEncoding)encoding
                                error:(NSError * __autoreleasing *)error
{
    return [self XMLDocumentWithData:[string dataUsingEncoding:encoding] error:error];
}

+ (instancetype)XMLDocumentWithData:(NSData *)data
                              error:(NSError * __autoreleasing *)error
{
    xmlDocPtr document = xmlReadMemory([data bytes], (int)[data length], "", nil, XML_PARSE_RECOVER);
    if (!document) {
        return nil;
    }

    return [[self alloc] initWithDocument:document];
}

+ (instancetype)HTMLDocumentWithString:(NSString *)string
                              encoding:(NSStringEncoding)encoding
                                 error:(NSError * __autoreleasing *)error
{
    return [self HTMLDocumentWithData:[string dataUsingEncoding:encoding] error:error];
}

+ (instancetype)HTMLDocumentWithData:(NSData *)data
                               error:(NSError * __autoreleasing *)error
{
    xmlDocPtr document = htmlReadMemory([data bytes], (int)[data length], "", nil, HTML_PARSE_NOWARNING | HTML_PARSE_NOERROR);
    if (!document) {
        return nil;
    }

    return [[self alloc] initWithDocument:document];
}

#pragma mark -

- (instancetype)initWithDocument:(xmlDocPtr)document {
    self = [super init];
    if (!self) {
        return nil;
    }

    _xmlDocument = document;
    if (self.xmlDocument) {
        self.rootElement = [self elementWithNode:xmlDocGetRootElement(self.xmlDocument)];
    }

    return self;
}

- (void)dealloc {
    if (_xmlDocument) {
        xmlFreeDoc(_xmlDocument);
    }
}

#pragma mark -

- (NSNumberFormatter *)numberFormatter {
    if (!_numberFormatter) {
        _numberFormatter = [[NSNumberFormatter alloc] init];
        [_numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
    }

    return _numberFormatter;
}

- (NSDateFormatter *)dateFormatter {
    if (!_dateFormatter) {
        _dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
        [_dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
    }

    return _dateFormatter;
}

#pragma mark -

- (ONOXMLElement *)elementWithNode:(xmlNodePtr)node {
    if (!node) {
        return nil;
    }

    ONOXMLElement *element = [[ONOXMLElement alloc] init];
    element.xmlNode = node;
    element.document = self;

    return element;
}

- (ONOXPathEnumerator *)enumeratorWithXPathObject:(xmlXPathObjectPtr)XPath {
    if (!XPath || xmlXPathNodeSetIsEmpty(XPath->nodesetval)) {
        return nil;
    }

    ONOXPathEnumerator *enumerator = [[ONOXPathEnumerator alloc] init];
    enumerator.xmlXPath = XPath;
    enumerator.document = self;

    return enumerator;
}

#pragma mark - ONOSearching

- (id <NSFastEnumeration>)XPath:(NSString *)XPath {
    return [self.rootElement XPath:XPath];
}

- (void)enumerateElementsWithXPath:(NSString *)XPath
                             block:(void (^)(ONOXMLElement *))block
{
    [self.rootElement enumerateElementsWithXPath:XPath block:block];
}

- (void)enumerateElementsWithXPath:(NSString *)XPath stoppableBlock:(void (^)(ONOXMLElement *, NSUInteger, BOOL *))block
{
    [self.rootElement enumerateElementsWithXPath:XPath stoppableBlock:block];
}

- (ONOXMLElement *)firstChildWithXPath:(NSString *)XPath
{
    return [self.rootElement firstChildWithXPath:XPath];
}

- (id <NSFastEnumeration>)CSS:(NSString *)CSS {
    return [self.rootElement CSS:CSS];
}

- (void)enumerateElementsWithCSS:(NSString *)CSS
                           block:(void (^)(ONOXMLElement *))block
{
    [self.rootElement enumerateElementsWithCSS:CSS block:block];
}

- (void)enumerateElementsWithCSS:(NSString *)CSS stoppableBlock:(void (^)(ONOXMLElement *, NSUInteger, BOOL *))block
{
    [self.rootElement enumerateElementsWithCSS:CSS stoppableBlock:block];
}

- (ONOXMLElement *)firstChildWithCSS:(NSString *)CSS
{
    return [self.rootElement firstChildWithCSS:CSS];
}

#pragma mark -

- (NSString *)version {
    if (!_version) {
        self.version = [NSString stringWithUTF8String:(const char *)self.xmlDocument->version];
    }

    return _version;
}

#pragma mark - NSObject

- (NSString *)description {
    return [self.rootElement description];
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }

    if (![object isKindOfClass:[self class]]) {
        return NO;
    }

    return [self hash] == [object hash];
}

- (NSUInteger)hash {
    return (NSUInteger)self.xmlDocument;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    ONOXMLDocument *document = [[[self class] allocWithZone:zone] init];
    document.version = self.version;
    document.rootElement = self.rootElement;

    return document;
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super init];
    if (!self) {
        return nil;
    }

    self.version = [decoder decodeObjectForKey:NSStringFromSelector(@selector(version))];
    self.rootElement = [decoder decodeObjectForKey:NSStringFromSelector(@selector(rootElement))];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.version forKey:NSStringFromSelector(@selector(version))];
    [coder encodeObject:self.rootElement forKey:NSStringFromSelector(@selector(rootElement))];
}

@end

#pragma mark -

@interface ONOXMLElement ()
@property (readwrite, nonatomic, copy) NSString *rawXMLString;
@property (readwrite, nonatomic, copy) NSString *tag;
@property (readwrite, nonatomic, copy) NSString *namespace;
@property (readwrite, nonatomic, strong) ONOXMLElement *parent;
@property (readwrite, nonatomic, strong) NSArray *children;
@property (readwrite, nonatomic, strong) ONOXMLElement *previousSibling;
@property (readwrite, nonatomic, strong) ONOXMLElement *nextSibling;
@property (readwrite, nonatomic, strong) NSDictionary *attributes;
@property (readwrite, nonatomic, copy) NSString *stringValue;
@property (readwrite, nonatomic, copy) NSNumber *numberValue;
@property (readwrite, nonatomic, copy) NSDate *dateValue;
@end

@implementation ONOXMLElement
@dynamic children;

- (NSString *)namespace {
    if (!_namespace && self.xmlNode->ns != NULL) {
        self.namespace = [NSString stringWithUTF8String:(const char *)self.xmlNode->ns->prefix];
    }

    return _namespace;
}

- (NSString *)tag {
    if (!_tag) {
        self.tag = [NSString stringWithUTF8String:(const char *)self.xmlNode->name];
    }

    return _tag;
}

#pragma mark -

- (NSDictionary *)attributes {
    if (!_attributes) {
        NSMutableDictionary *mutableAttributes = [NSMutableDictionary dictionary];
        xmlAttrPtr attribute = self.xmlNode->properties;
        while (attribute) {
            NSString *key = [NSString stringWithUTF8String:(const char *)attribute->name];
            [mutableAttributes setObject:[self valueForAttribute:key] forKey:key];
            attribute = attribute->next;
        }

        self.attributes = [NSDictionary dictionaryWithDictionary:mutableAttributes];
    }

    return _attributes;
}

- (id)valueForAttribute:(NSString *)attribute {
    id value = nil;
    const unsigned char *xmlValue = xmlGetProp(self.xmlNode, (const xmlChar *)[attribute cStringUsingEncoding:NSUTF8StringEncoding]);
    if (xmlValue) {
        value = [NSString stringWithUTF8String:(const char *)xmlValue];
        xmlFree((void *)xmlValue);
    }

    return value;
}

- (id)valueForAttribute:(NSString *)attribute
            inNamespace:(NSString *)namespace
{
    id value = nil;
    const unsigned char *xmlValue = xmlGetNsProp(self.xmlNode, (const xmlChar *)[attribute cStringUsingEncoding:NSUTF8StringEncoding], (const xmlChar *)[namespace cStringUsingEncoding:NSUTF8StringEncoding]);
    if (xmlValue) {
        value = [NSString stringWithUTF8String:(const char *)xmlValue];
        xmlFree((void *)xmlValue);
    }

    return value;
}

#pragma mark -

- (ONOXMLElement *)parent {
    if (!_parent) {
        self.parent = [self.document elementWithNode:self.xmlNode->parent];
    }

    return _parent;
}

- (NSArray *)children {
    return [self childrenAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, NSIntegerMax)]];
}

- (ONOXMLElement *)firstChildWithTag:(NSString *)tag {
    return [self firstChildWithTag:tag inNamespace:nil];
}

- (ONOXMLElement *)firstChildWithTag:(NSString *)tag
                         inNamespace:(NSString *)namespace
{
    NSArray *children = [self childrenAtIndexes:[self indexesOfChildrenPassingTest:^BOOL(xmlNodePtr node, BOOL *stop) {
        *stop = ONOXMLNodeMatchesTagInNamespace(node, tag, namespace);
        return *stop;
    }]];

    if ([children count] == 0) {
        return nil;
    }

    return [children objectAtIndex:0];
}

- (NSArray *)childrenWithTag:(NSString *)tag {
    return [self childrenWithTag:tag inNamespace:nil];
}

- (NSArray *)childrenWithTag:(NSString *)tag
                 inNamespace:(NSString *)namespace
{

    return [self childrenAtIndexes:[self indexesOfChildrenPassingTest:^BOOL(xmlNodePtr node, BOOL *stop) {
        return ONOXMLNodeMatchesTagInNamespace(node, tag, namespace);
    }]];
}

- (NSArray *)childrenAtIndexes:(NSIndexSet *)indexes {
    NSMutableArray *mutableChildren = [NSMutableArray array];

    xmlNodePtr cursor = self.xmlNode->children;
    NSUInteger idx = 0;
    while (cursor) {
        if ([indexes containsIndex:idx] && cursor->type == XML_ELEMENT_NODE) {
            [mutableChildren addObject:[self.document elementWithNode:cursor]];
        }

        cursor = cursor->next;
        idx++;
    }

    return [NSArray arrayWithArray:mutableChildren];
}

- (NSIndexSet *)indexesOfChildrenPassingTest:(BOOL (^)(xmlNodePtr node, BOOL *stop))block {
    if (!block) {
        return nil;
    }

    NSMutableIndexSet *mutableIndexSet = [NSMutableIndexSet indexSet];

    xmlNodePtr cursor = self.xmlNode->children;
    NSUInteger idx = 0;
    BOOL stop = NO;
    while (cursor && !stop) {
        if (block(cursor, &stop)) {
            [mutableIndexSet addIndex:idx];
        }

        cursor = cursor->next;
        idx++;
    }

    return mutableIndexSet;
}

- (ONOXMLElement *)previousSibling {
    if (!_previousSibling) {
        self.previousSibling = [self.document elementWithNode:self.xmlNode->prev];
    }

    return _previousSibling;
}

- (ONOXMLElement *)nextSibling {
    if (!_nextSibling) {
        self.nextSibling = [self.document elementWithNode:self.xmlNode->next];
    }

    return _nextSibling;
}

#pragma mark -

- (BOOL)isBlank {
    return [[self stringValue] length] == 0;
}

- (NSString *)stringValue {
    if (!_stringValue) {
        xmlChar *key = xmlNodeGetContent(self.xmlNode);
        self.stringValue = key ? [NSString stringWithUTF8String:(const char *)key] : @"";
        xmlFree(key);
    }

    return _stringValue;
}

- (NSNumber *)numberValue {
    if (!_numberValue) {
        self.numberValue = [self.document.numberFormatter numberFromString:[self stringValue]];
    }

    return _numberValue;
}

- (NSDate *)dateValue {
    if (!_dateValue) {
        self.dateValue = [self.document.dateFormatter dateFromString:[self stringValue]];
    }

    return _dateValue;
}

#pragma mark -

- (id)objectForKeyedSubscript:(id)key {
    return [self valueForAttribute:key];
}

- (id)objectAtIndexedSubscript:(NSUInteger)idx {
    return [self.children objectAtIndex:idx];
}

#pragma mark - NSObject

- (NSString *)description {
    xmlBufferPtr buffer = xmlBufferCreate();
    xmlNodeDump(buffer, self.xmlNode->doc, self.xmlNode, 0, false);
    NSString *rawXMLString = [NSString stringWithUTF8String:(const char *)xmlBufferContent(buffer)];
    xmlBufferFree(buffer);

    return rawXMLString;
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }

    if (![object isKindOfClass:[self class]]) {
        return NO;
    }

    return [self hash] == [object hash];
}

- (NSUInteger)hash {
    return (NSUInteger)self.xmlNode;
}

#pragma mark - ONOSearching

- (id <NSFastEnumeration>)XPath:(NSString *)XPath {
    if (!XPath) {
        return nil;
    }

    ONOXPathEnumerator *enumerator = nil;
    xmlXPathContextPtr context = xmlXPathNewContext(self.xmlNode->doc);
    if (context) {
        context->node = self.xmlNode;

        xmlXPathObjectPtr xmlXPath = xmlXPathEvalExpression((xmlChar *)[XPath cStringUsingEncoding:NSUTF8StringEncoding], context);
        enumerator = [self.document enumeratorWithXPathObject:xmlXPath];

        xmlXPathFreeContext(context);
    }

    return enumerator;
}

- (void)enumerateElementsWithXPath:(NSString *)XPath
                             block:(void (^)(ONOXMLElement *element))block
{
    if (!block) {
        return;
    }

    [self enumerateElementsWithXPath:XPath stoppableBlock:^(ONOXMLElement *element, NSUInteger idx, BOOL *stop) {
        block(element);
    }];
}

- (void)enumerateElementsWithXPath:(NSString *)XPath stoppableBlock:(void (^)(ONOXMLElement *, NSUInteger, BOOL *))block
{
    if (!block) {
        return;
    }
    
    NSUInteger currentIndex = 0;
    for (ONOXMLElement *element in [self XPath:XPath]) {
        BOOL stop = NO;
        block(element, currentIndex++, &stop);
        if (stop) {
            break;
        }
    }
}

- (ONOXMLElement *)firstChildWithXPath:(NSString *)XPath
{
    for (ONOXMLElement *element in [self XPath:XPath]) {
        return element;
    }
    return nil;
}

- (id <NSFastEnumeration>)CSS:(NSString *)CSS {
    return [self XPath:ONOXPathFromCSS(CSS)];
}

- (void)enumerateElementsWithCSS:(NSString *)CSS
                           block:(void (^)(ONOXMLElement *element))block
{
    [self enumerateElementsWithXPath:ONOXPathFromCSS(CSS) block:block];
}

- (void)enumerateElementsWithCSS:(NSString *)CSS stoppableBlock:(void (^)(ONOXMLElement *, NSUInteger, BOOL *))block
{
    [self enumerateElementsWithXPath:ONOXPathFromCSS(CSS) stoppableBlock:block];
}

- (ONOXMLElement *)firstChildWithCSS:(NSString *)CSS
{
    for (ONOXMLElement *element in [self CSS:CSS]) {
        return element;
    }
    return nil;
}

#pragma mark - NSObject

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [[self stringValue] methodSignatureForSelector:selector];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    [invocation invokeWithTarget:[self stringValue]];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    ONOXMLElement *element = [[[self class] allocWithZone:zone] init];
    element.xmlNode = self.xmlNode;
    element.document = self.document;

    return element;
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super init];
    if (!self) {
        return nil;
    }

    self.tag = [decoder decodeObjectForKey:NSStringFromSelector(@selector(tag))];
    self.attributes = [decoder decodeObjectForKey:NSStringFromSelector(@selector(attributes))];
    self.stringValue = [decoder decodeObjectForKey:NSStringFromSelector(@selector(stringValue))];
    self.children = [decoder decodeObjectForKey:NSStringFromSelector(@selector(children))];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.tag forKey:NSStringFromSelector(@selector(tag))];
    [coder encodeObject:self.attributes forKey:NSStringFromSelector(@selector(attributes))];
    [coder encodeObject:self.stringValue forKey:NSStringFromSelector(@selector(stringValue))];
    [coder encodeObject:self.children forKey:NSStringFromSelector(@selector(children))];
}

@end
