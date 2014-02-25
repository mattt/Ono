// ONOXMLDocument.h
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

#import <Foundation/Foundation.h>

@class ONOXMLElement;

/**
 
 */
@protocol ONOSearching

/**
 
 */
- (id <NSFastEnumeration>)XPath:(NSString *)XPath;

/**
 
 */
- (void)enumerateElementsWithXPath:(NSString *)XPath
                             block:(void (^)(ONOXMLElement *element))block;

///

/**
 
 */
- (id <NSFastEnumeration>)CSS:(NSString *)CSS;

/**
 
 */
- (void)enumerateElementsWithCSS:(NSString *)CSS
                           block:(void (^)(ONOXMLElement *element))block;
@end

#pragma mark -

/**
 
 */
@interface ONOXMLDocument : NSObject <ONOSearching, NSCopying, NSCoding>

/**
 
 */
@property (readonly, nonatomic, copy) NSString *version;

/**
 
 */
@property (readonly, nonatomic, assign) NSStringEncoding encoding;

/**
 
 */
@property (readonly, nonatomic, strong) ONOXMLElement *rootElement;

/**
 
 */
+ (instancetype)XMLDocumentWithString:(NSString *)string
                             encoding:(NSStringEncoding)encoding
                                error:(NSError * __autoreleasing *)error;

/**
 
 */
+ (instancetype)XMLDocumentWithData:(NSData *)data
                              error:(NSError * __autoreleasing *)error;

///

/**
 
 */
+ (instancetype)HTMLDocumentWithString:(NSString *)string
                              encoding:(NSStringEncoding)encoding
                                 error:(NSError * __autoreleasing *)error;

/**
 
 */
+ (instancetype)HTMLDocumentWithData:(NSData *)data
                               error:(NSError * __autoreleasing *)error;

@end

#pragma mark -

/**
 
 */
@interface ONOXMLElement : NSObject <ONOSearching, NSCopying, NSCoding>

/**
 
 */
@property (readonly, nonatomic, strong) ONOXMLDocument *document;

/**
 
 */
@property (readonly, nonatomic, copy) NSString *tag;

///

/**

 */
@property (readonly, nonatomic, strong) NSDictionary *attributes;

/**

 */
- (id)valueForAttribute:(NSString *)key;

/**

 */
- (id)valueForAttribute:(NSString *)key
            inNamespace:(NSString *)namespace;

///

/**
 
 */
@property (readonly, nonatomic, strong) ONOXMLElement *parent;

/**
 
 */
@property (readonly, nonatomic, strong) NSArray *children;

/**
 
 */
@property (readonly, nonatomic, strong) ONOXMLElement *previousSibling;

/**
 
 */
@property (readonly, nonatomic, strong) ONOXMLElement *nextSibling;

/**
 
 */
- (ONOXMLElement *)firstChildWithTag:(NSString *)tag;

/**
 
 */
- (ONOXMLElement *)firstChildWithTag:(NSString *)tag
                         inNamespace:(NSString *)namespace;

/**
 
 */
- (NSArray *)childrenWithTag:(NSString *)tag;

/**

 */
- (NSArray *)childrenWithTag:(NSString *)tag
                 inNamespace:(NSString *)namespace;

///

/**

 */
@property (readonly, nonatomic, assign, getter = isBlank) BOOL blank;

/**
 
 */
- (NSString *)stringValue;

/**
 
 */
- (NSNumber *)numberValue;

/**
 
 */
- (NSDate *)dateValue;

///

/**
 
 */
- (id)objectAtIndexedSubscript:(NSUInteger)idx;

/**
 
 */
- (id)objectForKeyedSubscript:(id)key;

@end


///

/**
 
 */
extern NSString * const ONOErrorDomain;
