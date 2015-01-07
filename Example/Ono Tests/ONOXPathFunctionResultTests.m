//
//  ONOXPathFunctionResultTests.m
//  Ono Example
//
//  Created by CHEN Xian’an on 1/7/15.
//  Copyright (c) 2015 Mattt Thompson. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "Ono.h"

@interface ONOXPathFunctionResultTests : XCTestCase
@property (nonatomic, strong) ONOXMLDocument *document;
@end

@implementation ONOXPathFunctionResultTests

- (void)setUp {
    [super setUp];
    
    NSError *error = nil;
    NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"atom" ofType:@"xml"];
    self.document = [ONOXMLDocument XMLDocumentWithData:[NSData dataWithContentsOfFile:filePath] error:&error];
    [self.document definePrefix:@"atom" forDefaultNamespace:@"http://www.w3.org/2005/Atom"];
    
    XCTAssertNotNil(self.document, @"Document should not be nil");
    XCTAssertNil(error, @"Error should not be generated");
}

- (void)testFunctionResultBoolVaule {
    NSString *XPath = @"starts-with('Ono','O')";
    ONOXPathFunctionResult *result = [self.document.rootElement functionResultByEvaluatingXPath:XPath];
    XCTAssertTrue(result.boolValue, "Result boolVaule should be true");
}

- (void)testFunctionResultNumericValue {
    NSString *XPath = @"count(./atom:link)";
    ONOXPathFunctionResult *result = [self.document.rootElement functionResultByEvaluatingXPath:XPath];
    XCTAssertEqual(result.numericValue, 2, "Number of child links should be 2");
}

- (void)testFunctionResultStringVaule {
    NSString *XPath = @"string(./atom:entry[1]/dc:language[1]/text())";
    ONOXPathFunctionResult *result = [self.document.rootElement functionResultByEvaluatingXPath:XPath];
    XCTAssertEqualObjects(result.stringValue, @"en-us", "Result stringValue should be `en-us`");
}

@end
