//
//  ONODefaultNamespaceXPathTests.m
//  Ono Example
//
//  Created by CHEN Xian’an on 1/5/15.
//  Copyright (c) 2015 Mattt Thompson. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "Ono.h"

@interface ONODefaultNamespaceXPathTests : XCTestCase
@property (nonatomic, strong) ONOXMLDocument *document;
@end

@implementation ONODefaultNamespaceXPathTests

- (void)setUp {
    [super setUp];
    NSError *error = nil;
    NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"ocf" ofType:@"xml"];
    self.document = [ONOXMLDocument XMLDocumentWithData:[NSData dataWithContentsOfFile:filePath] error:&error];
    
    XCTAssertNotNil(self.document, @"Document should not be nil");
    XCTAssertNil(error, @"Error should not be generated");
}

#pragma mark -

- (void)testAbsoluteXPathWithDefaultNamespace {
    [self.document definePrefix:@"ocf" forDefaultNamespace:@"urn:oasis:names:tc:opendocument:xmlns:container"];
    NSString *XPath = @"/ocf:container/ocf:rootfiles/ocf:rootfile";
    NSUInteger count = 0;
    for (ONOXMLElement *element in [self.document XPath:XPath]) {
        XCTAssertEqualObjects(@"rootfile", element.tag, @"tag should be `rootfile`");
        count++;
    }
    
    XCTAssertEqual(1, count, @"Element should be found at XPath '%@'", XPath);
}

- (void)testRelativeXPathWithDefaultNamespace {
    [self.document definePrefix:@"ocf" forDefaultNamespace:@"urn:oasis:names:tc:opendocument:xmlns:container"];
    NSString *absXPath = @"/ocf:container/ocf:rootfiles";
    NSString *relXPath = @"./ocf:rootfile";
    NSUInteger count = 0;
    for (ONOXMLElement *absElement in [self.document XPath:absXPath]) {
        for (ONOXMLElement *relElement in [absElement XPath:relXPath]) {
            XCTAssertEqualObjects(@"rootfile", relElement.tag, @"tag should be `rootfile`");
            count++;
        }
    }
    
    XCTAssertEqual(1, count, @"Element should be found at XPath '%@' relative to XPath '%@'", relXPath, absXPath);
}

@end
