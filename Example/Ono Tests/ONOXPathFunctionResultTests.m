// ONOXPathFunctionResultTests.m
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

#pragma mark -

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
