// ONOXMLDocument.m
//
// Copyright (c) 2014 – 2018 Mattt (https://mat.tt)
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

@import libxml2.xmlreader;
@import libxml2.xpath;
@import libxml2.xpathInternals;
@import libxml2.HTMLparser;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"
#if !defined(__has_warning) || __has_warning("-Wobjc-messaging-id")
#pragma clang diagnostic ignored "-Wobjc-messaging-id"
#endif

NS_ASSUME_NONNULL_BEGIN

static NSString * const ONOXMLDocumentErrorDomain = @"com.ono.error";

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

NSString * ONOXPathFromCSS(NSString *CSS);
NSString * ONOXPathFromCSS(NSString *CSS) {
    NSMutableArray<NSString *> *mutableXPathExpressions = [NSMutableArray array];
    [[CSS componentsSeparatedByString:@","] enumerateObjectsUsingBlock:^(NSString *expression, __unused NSUInteger _idx, __unused BOOL *stop) {
        if (expression && [expression length] > 0) {
            __block NSMutableArray<NSString *> *mutableXPathComponents = [NSMutableArray arrayWithObject:@"./"];
            __block NSString *prefix = nil;

            [[[expression stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] enumerateObjectsUsingBlock:^(NSString *token, NSUInteger idx, __unused BOOL *_stop) {
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
                            NSTextCheckingResult *result = [ONOIdRegularExpression() firstMatchInString:token options:(NSMatchingOptions)0 range:range];
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

static BOOL ONOXMLNodeMatchesTagInNamespace(xmlNodePtr node, NSString *tag, NSString * _Nullable ns) {
    BOOL matchingTag = !tag || [@((const char *)node->name) compare:tag options:NSCaseInsensitiveSearch] == NSOrderedSame;

    BOOL matchingNamespace = !ns ? YES : (((node->ns != NULL) && (node->ns->prefix != NULL)) ? [@((const char *)node->ns->prefix) compare:(NSString *)ns options:NSCaseInsensitiveSearch] == NSOrderedSame : NO);

    return matchingTag && matchingNamespace;
}

static void ONOSetErrorFromXMLErrorPtr(NSError * __autoreleasing *error, xmlErrorPtr errorPtr) {
    if (error && errorPtr) {
        NSString *message = [[NSString stringWithCString:(const char *)errorPtr->message encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSInteger code = errorPtr->code;
        NSDictionary *userInfo = @{NSLocalizedFailureReasonErrorKey: message};
        *error = [NSError errorWithDomain:ONOXMLDocumentErrorDomain code:code userInfo:userInfo];
        xmlResetError(errorPtr);
    }
}

@interface ONOXPathEnumerator : NSEnumerator <NSFastEnumeration>
@end

@interface ONOXPathFunctionResult()
@property (readwrite, nonatomic, assign) xmlXPathObjectPtr xmlXPath;
@end

@interface ONOXPathEnumerator ()
@property (readwrite, nonatomic, assign) xmlXPathObjectPtr xmlXPath;
@property (readwrite, nonatomic, assign) NSUInteger cursor;
@property (readwrite, nonatomic, strong) ONOXMLDocument *document;
@end

@interface ONOXMLElement ()
@property (readwrite, nonatomic, assign) xmlNodePtr xmlNode;
@property (readwrite, nonatomic, weak) ONOXMLDocument *document;

- (nullable xmlXPathObjectPtr)xmlXPathObjectPtrWithXPath:(NSString *)XPath;
@end

@interface ONOXMLDocument ()
@property (readwrite, nonatomic, assign) xmlDocPtr xmlDocument;
@property (readwrite, nonatomic, strong) ONOXMLElement *rootElement;
@property (readwrite, nonatomic, copy) NSString *version;
@property (readwrite, nonatomic, assign) NSStringEncoding stringEncoding;
@property (readwrite, nonatomic, strong) NSNumberFormatter *numberFormatter;
@property (readwrite, nonatomic, strong) NSDateFormatter *dateFormatter;
@property (readwrite, nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *defaultNamespaces;

- (nullable ONOXMLElement *)elementWithNode:(xmlNodePtr)node;
- (nullable ONOXPathEnumerator *)enumeratorWithXPathObject:(xmlXPathObjectPtr)XPath;
@end

#pragma mark -

@implementation ONOXPathEnumerator

- (void)dealloc {
    if (_xmlXPath) {
        xmlXPathFreeObject(_xmlXPath);
    }
}

- (nullable id)objectAtIndex:(NSInteger)idx {
    if (idx >= (NSInteger)xmlXPathNodeSetGetLength(self.xmlXPath->nodesetval)) {
        return nil;
    }

    return [self.document elementWithNode:self.xmlXPath->nodesetval->nodeTab[idx]];
}

#pragma mark - NSEnumerator

- (NSArray<ONOXMLElement *> *)allObjects {
    NSMutableArray<ONOXMLElement *> *mutableObjects = [NSMutableArray arrayWithCapacity:(NSUInteger)self.xmlXPath->nodesetval->nodeNr];
    for (NSInteger idx = 0; idx < xmlXPathNodeSetGetLength(self.xmlXPath->nodesetval); idx++) {
        ONOXMLElement *element = [self objectAtIndex:idx];
        if (element) {
            [mutableObjects addObject:element];
        }
    }

    return [NSArray arrayWithArray:mutableObjects];
}

- (nullable id)nextObject {
    if (self.cursor >= (NSUInteger)self.xmlXPath->nodesetval->nodeNr) {
        return nil;
    }

    return [self objectAtIndex:((NSInteger)self.cursor++)];
}

@end

#pragma mark -

@implementation ONOXPathFunctionResult

- (void)dealloc {
    if (_xmlXPath) {
        xmlXPathFreeObject(_xmlXPath);
    }
}

- (BOOL)boolValue {
    return self.xmlXPath->boolval > 0;
}

- (double)numericValue {
    return self.xmlXPath->floatval;
}

- (nullable NSNumber *)numberValue {
    if (!self.xmlXPath) {
        return nil;
    }
    
    return [NSNumber numberWithDouble:self.xmlXPath->floatval];
}

- (nullable NSString *)stringValue {
    if (!self.xmlXPath) {
        return nil;
    }
    
    return [NSString stringWithCString:(char *)self.xmlXPath->stringval encoding:NSUTF8StringEncoding];
}


@end

#pragma mark -

@implementation ONOXMLDocument

+ (nullable instancetype)XMLDocumentWithString:(NSString *)string
                                      encoding:(NSStringEncoding)encoding
                                         error:(NSError * __autoreleasing *)error
{
    return [self XMLDocumentWithData:[string dataUsingEncoding:encoding] error:error];
}

+ (nullable instancetype)XMLDocumentWithData:(nullable NSData *)data
                                       error:(NSError * __autoreleasing *)error
{
    xmlDocPtr document = xmlReadMemory([data bytes], (int)[data length], "", nil, XML_PARSE_NOWARNING | XML_PARSE_NOERROR | XML_PARSE_RECOVER);
    if (!document) {
        ONOSetErrorFromXMLErrorPtr(error, xmlGetLastError());
        return nil;
    }
    
    xmlResetLastError();

    return [[self alloc] initWithDocument:document];
}

+ (nullable instancetype)HTMLDocumentWithString:(NSString *)string
                                       encoding:(NSStringEncoding)encoding
                                          error:(NSError * __autoreleasing *)error
{
    return [self HTMLDocumentWithData:[string dataUsingEncoding:encoding] error:error];
}

+ (nullable instancetype)HTMLDocumentWithData:(nullable NSData *)data
                                        error:(NSError * __autoreleasing *)error
{
    xmlDocPtr document = htmlReadMemory([data bytes], (int)[data length], "", nil, HTML_PARSE_NOWARNING | HTML_PARSE_NOERROR | HTML_PARSE_RECOVER);
    if (!document) {
        ONOSetErrorFromXMLErrorPtr(error, xmlGetLastError());
        return nil;
    }

    xmlResetLastError();

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
        self.rootElement = (ONOXMLElement * )[self elementWithNode:xmlDocGetRootElement(self.xmlDocument)];
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
        NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
        [numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
        self.numberFormatter = numberFormatter;
    }

    return _numberFormatter;
}

- (NSDateFormatter *)dateFormatter {
    if (!_dateFormatter) {
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
        [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
        self.dateFormatter = dateFormatter;
    }

    return _dateFormatter;
}

#pragma mark -

- (void)definePrefix:(NSString *)prefix
 forDefaultNamespace:(NSString *)ns
{
    if (!self.defaultNamespaces) {
        self.defaultNamespaces = [NSMutableDictionary dictionary];
    }
    
    self.defaultNamespaces[ns] = prefix;
}

#pragma mark - Private Methods

- (nullable ONOXMLElement *)elementWithNode:(xmlNodePtr)node {
    if (!node) {
        return nil;
    }

    ONOXMLElement *element = [[ONOXMLElement alloc] init];
    element.xmlNode = node;
    element.document = self;

    return element;
}

- (nullable ONOXPathEnumerator *)enumeratorWithXPathObject:(xmlXPathObjectPtr)XPath {
    if (!XPath || xmlXPathNodeSetIsEmpty(XPath->nodesetval)) {
        xmlXPathFreeObject(XPath);
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

- (nullable ONOXPathFunctionResult *)functionResultByEvaluatingXPath:(NSString *)XPath {
    return [self.rootElement functionResultByEvaluatingXPath:XPath];
}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-implementations"
- (void)enumerateElementsWithXPath:(NSString *)XPath
                             block:(void (^)(ONOXMLElement *element))block
{
    if (!block) {
        return;
    }

    [self.rootElement enumerateElementsWithXPath:XPath usingBlock:^(ONOXMLElement *element, __unused NSUInteger idx, __unused BOOL *stop) {
        block(element);
    }];
}
#pragma GCC diagnostic pop

- (void)enumerateElementsWithXPath:(NSString *)XPath
                        usingBlock:(void (^)(ONOXMLElement *element, NSUInteger idx, BOOL *stop))block
{
    [self.rootElement enumerateElementsWithXPath:XPath usingBlock:block];
}

- (nullable ONOXMLElement *)firstChildWithXPath:(NSString *)XPath {
    return [self.rootElement firstChildWithXPath:XPath];
}

- (id <NSFastEnumeration>)CSS:(NSString *)CSS {
    return [self.rootElement CSS:CSS];
}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
#pragma GCC diagnostic ignored "-Wdeprecated-implementations"
- (void)enumerateElementsWithCSS:(NSString *)CSS
                           block:(void (^)(ONOXMLElement *))block
{
    [self.rootElement enumerateElementsWithCSS:CSS block:block];
}
#pragma GCC diagnostic pop

- (void)enumerateElementsWithCSS:(NSString *)CSS
                      usingBlock:(void (^)(ONOXMLElement *element, NSUInteger idx, BOOL *stop))block
{
    [self.rootElement enumerateElementsWithCSS:CSS usingBlock:block];
}

- (nullable ONOXMLElement *)firstChildWithCSS:(NSString *)CSS {
    return [self.rootElement firstChildWithCSS:CSS];
}

#pragma mark -

- (NSString *)version {
    if (!_version && self.xmlDocument->version != NULL) {
        self.version = (NSString *)@((const char *)self.xmlDocument->version);
    }

    return _version;
}

- (NSStringEncoding)stringEncoding {
    if (!_stringEncoding && self.xmlDocument->encoding != NULL) {
        NSString *encodingName = @((const char *)self.xmlDocument->encoding);
        CFStringEncoding encoding = CFStringConvertIANACharSetNameToEncoding((CFStringRef)encodingName);
        if (encoding != kCFStringEncodingInvalidId) {
            self.stringEncoding = CFStringConvertEncodingToNSStringEncoding(encoding);
        }
    }

    return _stringEncoding;
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

- (id)copyWithZone:(nullable NSZone *)zone {
    ONOXMLDocument *document = [[[self class] allocWithZone:zone] init];
    document.version = self.version;
    document.rootElement = self.rootElement;

    return document;
}

#pragma mark - NSCoding

- (nullable instancetype)initWithCoder:(NSCoder *)decoder {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    NSString *version = [decoder decodeObjectForKey:NSStringFromSelector(@selector(version))];
    ONOXMLElement *rootElement = [decoder decodeObjectForKey:NSStringFromSelector(@selector(rootElement))];
    
    if (!version || !rootElement) {
        return nil;
    }
    
    self.version = version;
    self.rootElement = rootElement;

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
@property (readwrite, nonatomic, assign) NSUInteger lineNumber;
#ifdef __cplusplus
@property (nullable, readwrite, nonatomic, copy) NSString *ns;
#else
@property (nullable, readwrite, nonatomic, copy) NSString *namespace;
#endif
@property (nullable, readwrite, nonatomic, strong) ONOXMLElement *parent;
@property (readwrite, nonatomic, strong) NSArray<ONOXMLElement *> *children;
@property (nullable, readwrite, nonatomic, strong) ONOXMLElement *previousSibling;
@property (nullable, readwrite, nonatomic, strong) ONOXMLElement *nextSibling;
@property (readwrite, nonatomic, strong) NSDictionary *attributes;
@property (nullable, readwrite, nonatomic, copy) NSString *stringValue;
@property (nullable, readwrite, nonatomic, copy) NSNumber *numberValue;
@property (nullable, readwrite, nonatomic, copy) NSDate *dateValue;
@end

@implementation ONOXMLElement
@dynamic children;

#ifdef __cplusplus
- (nullable NSString *)ns {
    if (!_ns && self.xmlNode->ns != NULL && self.xmlNode->ns->prefix != NULL) {
        self.ns = @((const char *)self.xmlNode->ns->prefix);
    }

    return _ns;
}
#else
- (nullable NSString *)namespace {
    if (!_namespace && self.xmlNode->ns != NULL && self.xmlNode->ns->prefix != NULL) {
        self.namespace = @((const char *)self.xmlNode->ns->prefix);
    }

    return _namespace;
}
#endif

- (NSString *)tag {
    if (!_tag && self.xmlNode->name != NULL) {
        self.tag = (NSString *)@((const char *)self.xmlNode->name);
    }

    return _tag;
}

- (NSUInteger)lineNumber {
    if (!_lineNumber) {
        self.lineNumber = (NSUInteger)xmlGetLineNo(self.xmlNode);
    }

    return _lineNumber;
}

#pragma mark -

- (NSDictionary<NSString *, id> *)attributes {
    if (!_attributes) {
        NSMutableDictionary<NSString *, id> *mutableAttributes = [NSMutableDictionary dictionary];
        for (xmlAttrPtr attribute = self.xmlNode->properties; attribute != NULL; attribute = attribute->next) {
            NSString *key = @((const char *)attribute->name);
            [mutableAttributes setObject:(id)[self valueForAttribute:key] forKey:key];
        }

        self.attributes = [NSDictionary dictionaryWithDictionary:mutableAttributes];
    }

    return _attributes;
}

- (nullable id)valueForAttribute:(NSString *)attribute {
    id value = nil;
    xmlChar *xmlValue = xmlGetProp(self.xmlNode, (const xmlChar *)[attribute UTF8String]);
    if (xmlValue) {
        value = @((const char *)xmlValue);
        xmlFree(xmlValue);
    }

    return value;
}

- (nullable id)valueForAttribute:(NSString *)attribute
                     inNamespace:(nullable NSString *)ns
{
    id value = nil;
    xmlChar *xmlValue = xmlGetNsProp(self.xmlNode, (const xmlChar *)[attribute UTF8String], (const xmlChar *)[ns UTF8String]);
    if (xmlValue) {
        value = @((const char *)xmlValue);
        xmlFree(xmlValue);
    }

    return value;
}

#pragma mark -

- (nullable ONOXMLElement *)parent {
    if (!_parent) {
        self.parent = [self.document elementWithNode:self.xmlNode->parent];
    }

    return _parent;
}

- (NSArray<ONOXMLElement *> *)children {
    return [self childrenAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, NSIntegerMax)]];
}

- (nullable ONOXMLElement *)firstChildWithTag:(NSString *)tag {
    return [self firstChildWithTag:tag inNamespace:nil];
}

- (nullable ONOXMLElement *)firstChildWithTag:(NSString *)tag
                         inNamespace:(nullable NSString *)ns
{
    NSArray<ONOXMLElement *> *children = [self childrenAtIndexes:[self indexesOfChildrenPassingTest:^BOOL(xmlNodePtr node, BOOL *stop) {
        *stop = ONOXMLNodeMatchesTagInNamespace(node, tag, ns);
        return *stop;
    }]];

    if ([children count] == 0) {
        return nil;
    }

    return [children objectAtIndex:0];
}

- (NSArray<ONOXMLElement *> *)childrenWithTag:(NSString *)tag {
    return [self childrenWithTag:tag inNamespace:nil];
}

- (NSArray<ONOXMLElement *> *)childrenWithTag:(NSString *)tag
                                  inNamespace:(nullable NSString *)ns
{
    return [self childrenAtIndexes:[self indexesOfChildrenPassingTest:^BOOL(xmlNodePtr node, __unused BOOL *stop) {
        return ONOXMLNodeMatchesTagInNamespace(node, tag, ns);
    }]];
}

- (NSArray<ONOXMLElement *> *)childrenAtIndexes:(NSIndexSet *)indexes {
    NSMutableArray<ONOXMLElement *> *mutableChildren = [NSMutableArray array];

    xmlNodePtr cursor = self.xmlNode->children;
    NSUInteger idx = 0;
    while (cursor) {
        if ([indexes containsIndex:idx] && cursor->type == XML_ELEMENT_NODE) {
            ONOXMLElement *element = [self.document elementWithNode:cursor];
            if (element) {
                [mutableChildren addObject:element];
            }
        }

        cursor = cursor->next;
        idx++;
    }

    return [NSArray arrayWithArray:mutableChildren];
}

- (NSIndexSet *)indexesOfChildrenPassingTest:(BOOL (^)(xmlNodePtr node, BOOL *stop))block {
    if (!block) {
        return [NSIndexSet indexSet];
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

- (nullable ONOXMLElement *)previousSibling {
    if (!_previousSibling) {
        self.previousSibling = [self.document elementWithNode:self.xmlNode->prev];
    }

    return _previousSibling;
}

- (nullable ONOXMLElement *)nextSibling {
    if (!_nextSibling) {
        self.nextSibling = [self.document elementWithNode:self.xmlNode->next];
    }

    return _nextSibling;
}

#pragma mark -

- (BOOL)isBlank {
    return [[self stringValue] length] == 0;
}

- (nullable NSString *)stringValue {
    if (!_stringValue) {
        xmlChar *key = xmlNodeGetContent(self.xmlNode);
        if (key) {
            self.stringValue = [NSString stringWithCString:(const char *)key encoding:NSUTF8StringEncoding];
        }
        xmlFree(key);
    }

    return _stringValue;
}

- (nullable NSNumber *)numberValue {
    if (!_numberValue) {
        NSString *stringValue = self.stringValue;
        if (!stringValue) {
            return nil;
        }
        
        self.numberValue = [self.document.numberFormatter numberFromString:stringValue];
    }

    return _numberValue;
}

- (nullable NSDate *)dateValue {
    if (!_dateValue) {
        NSString *stringValue = self.stringValue;
        if (!stringValue) {
            return nil;
        }
        
        self.dateValue = [self.document.dateFormatter dateFromString:stringValue];
    }

    return _dateValue;
}

#pragma mark -

- (nullable id)objectForKeyedSubscript:(id)key {
    return [self valueForAttribute:key];
}

- (nullable id)objectAtIndexedSubscript:(NSUInteger)idx {
    return [self.children objectAtIndex:idx];
}

#pragma mark - NSObject

- (NSString *)description {
    xmlBufferPtr buffer = xmlBufferCreate();
    xmlNodeDump(buffer, self.xmlNode->doc, self.xmlNode, 0, false);
    NSString *rawXMLString = @((const char *)xmlBufferContent(buffer));
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
        return [[NSArray array] objectEnumerator];
    }

    xmlXPathObjectPtr xmlXPath = [self xmlXPathObjectPtrWithXPath:XPath];
    if (!xmlXPath) {
        return [[NSArray array] objectEnumerator];;
    }
    
    return (id <NSFastEnumeration>)[self.document enumeratorWithXPathObject:xmlXPath];
}

- (nullable ONOXPathFunctionResult *)functionResultByEvaluatingXPath:(NSString *)XPath {
    xmlXPathObjectPtr xmlXPath = [self xmlXPathObjectPtrWithXPath:XPath];
    if (xmlXPath) {
        ONOXPathFunctionResult *result = [[ONOXPathFunctionResult alloc] init];
        result.xmlXPath = xmlXPath;
        
        return result;
    }
    
    return nil;
}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
#pragma GCC diagnostic ignored "-Wdeprecated-implementations"
- (void)enumerateElementsWithXPath:(NSString *)XPath
                             block:(void (^)(ONOXMLElement *element))block
{
    if (!block) {
        return;
    }

    [self enumerateElementsWithXPath:XPath usingBlock:^(ONOXMLElement *element, __unused NSUInteger idx, __unused BOOL *stop) {
        block(element);
    }];
}
#pragma GCC diagnostic pop

- (void)enumerateElementsWithXPath:(NSString *)XPath
                        usingBlock:(void (^)(ONOXMLElement *element, NSUInteger idx, BOOL *stop))block
{
    if (!block) {
        return;
    }
    
    NSUInteger idx = 0;
    BOOL stop = NO;
    for (ONOXMLElement *element in [self XPath:XPath]) {
        block(element, idx++, &stop);

        if (stop) {
            break;
        }
    }
}

- (nullable ONOXMLElement *)firstChildWithXPath:(NSString *)XPath
{
    for (ONOXMLElement *element in [self XPath:XPath]) {
        return element;
    }

    return nil;
}

- (id <NSFastEnumeration>)CSS:(NSString *)CSS {
    return [self XPath:ONOXPathFromCSS(CSS)];
}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
#pragma GCC diagnostic ignored "-Wdeprecated-implementations"
- (void)enumerateElementsWithCSS:(NSString *)CSS
                           block:(void (^)(ONOXMLElement *element))block
{
    if (!block) {
        return;
    }

    [self enumerateElementsWithCSS:ONOXPathFromCSS(CSS) usingBlock:^(ONOXMLElement *element, __unused NSUInteger idx, __unused BOOL *stop) {
        block(element);
    }];
}
#pragma GCC diagnostic pop

- (void)enumerateElementsWithCSS:(NSString *)CSS
                      usingBlock:(void (^)(ONOXMLElement *element, NSUInteger idx, BOOL *stop))block
{
    [self enumerateElementsWithXPath:ONOXPathFromCSS(CSS) usingBlock:block];
}

- (nullable ONOXMLElement *)firstChildWithCSS:(NSString *)CSS
{
    for (ONOXMLElement *element in [self CSS:CSS]) {
        return element;
    }
    
    return nil;
}

#pragma mark -

- (nullable xmlXPathObjectPtr)xmlXPathObjectPtrWithXPath:(NSString *)XPath {
    xmlXPathContextPtr context = xmlXPathNewContext(self.xmlNode->doc);
    if (context) {
        context->node = self.xmlNode;

        // Due to a bug in libxml2, namespaces may not appear in `xmlNode->ns`.
        // As a workaround, `xmlNode->nsDef` is recursed to explicitly register namespaces.
        for (xmlNodePtr node = self.xmlNode; node->parent != NULL; node = node->parent) {
            for (xmlNsPtr ns = node->nsDef; ns != NULL; ns = ns->next) {
                const xmlChar *prefix = ns->prefix;
                if (!prefix && self.document.defaultNamespaces) {
                    NSString *href = @((const char *)ns->href);
                    NSString *defaultPrefix = self.document.defaultNamespaces[href];
                    if (defaultPrefix) {
                        prefix = (const xmlChar *)[defaultPrefix UTF8String];
                    }
                }

                if (prefix) {
                    xmlXPathRegisterNs(context, prefix, ns->href);
                }
            }
        }

        xmlXPathObjectPtr xmlXPath = xmlXPathEvalExpression((const xmlChar *)[XPath UTF8String], context);
        xmlXPathFreeContext(context);

        return xmlXPath;
    }

    return NULL;
}

#pragma mark - NSObject

- (nullable NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [[self stringValue] methodSignatureForSelector:selector];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    NSString *stringValue = self.stringValue;
    if (stringValue) {
        [invocation invokeWithTarget:stringValue];
    }
}

#pragma mark - NSCopying

- (id)copyWithZone:(nullable NSZone *)zone {
    ONOXMLElement *element = [[[self class] allocWithZone:zone] init];
    element.xmlNode = self.xmlNode;
    element.document = self.document;

    return element;
}

#pragma mark - NSCoding

- (nullable instancetype)initWithCoder:(NSCoder *)decoder {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    NSString *tag = [decoder decodeObjectForKey:NSStringFromSelector(@selector(tag))];
    NSDictionary<NSString *, id> *attributes = [decoder decodeObjectForKey:NSStringFromSelector(@selector(attributes))];
    NSString *stringValue = [decoder decodeObjectForKey:NSStringFromSelector(@selector(stringValue))];
    NSArray<ONOXMLElement *> *children = [decoder decodeObjectForKey:NSStringFromSelector(@selector(children))];
    
    if (!tag || !attributes || !stringValue || !children) {
        return nil;
    }
    
    self.tag = tag;
    self.attributes = attributes;
    self.stringValue = stringValue;
    self.children = children;

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.tag forKey:NSStringFromSelector(@selector(tag))];
    [coder encodeObject:self.attributes forKey:NSStringFromSelector(@selector(attributes))];
    [coder encodeObject:self.stringValue forKey:NSStringFromSelector(@selector(stringValue))];
    [coder encodeObject:self.children forKey:NSStringFromSelector(@selector(children))];
}

@end

NS_ASSUME_NONNULL_END

#pragma clang diagnostic pop
