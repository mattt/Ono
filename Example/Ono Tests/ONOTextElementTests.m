// ONOVMAPTests.m
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

@interface ONOTextElementTests : XCTestCase
@property (nonatomic, strong) ONOXMLDocument *document;

@end

@implementation ONOTextElementTests

- (void)setUp {
    [super setUp];
    
    NSError *error = nil;
    NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"text" ofType:@"xml"];
    self.document = [ONOXMLDocument XMLDocumentWithData:[NSData dataWithContentsOfFile:filePath] error:&error];
    
    XCTAssertNotNil(self.document, @"Document should not be nil");
    XCTAssertNil(error, @"Error should not be generated");
}

#pragma mark - Tag tests

- (void)testSingleElementUsingChildWithTag {
    NSString *XPath = @"/elementType/multiCheckBox/checkBoxes/checkBox";
    ONOXMLElement *checkBoxElement = [self.document firstChildWithXPath:XPath];
    
    // Test that the first text element contains "Text 0"
    ONOXMLElement *textElement = [checkBoxElement firstChildWithTag:@"text"];
    XCTAssertNotNil(textElement, @"Text element is nil");
    XCTAssertEqualObjects(textElement.tag, @"text", @"tag should be `text`");
    XCTAssertEqualObjects([textElement stringValue], @"Text 0", @"Text content should be `Text 0`");
    
    // Test that the first answerCode element contains "Code 0"
    ONOXMLElement *answerCodeElement = [checkBoxElement firstChildWithTag:@"answerCode"];
    XCTAssertNotNil(answerCodeElement, @"Answer code element is nil");
    XCTAssertEqualObjects(answerCodeElement.tag, @"answerCode", @"tag should be `answerCode`");
    XCTAssertEqualObjects([answerCodeElement stringValue], @"Code 0", @"Answer code content should be `Code 0`");
}

- (void)testTextElementsUsingChildWithTag {
    NSString *XPath = @"/elementType/multiCheckBox/checkBoxes/checkBox";
    __block NSUInteger count = 0;
    [self.document enumerateElementsWithXPath:XPath usingBlock:^(ONOXMLElement *element, NSUInteger idx, BOOL *stop) {
        XCTAssertEqualObjects(element.tag, @"checkBox", @"tag should be `checkBox`");
        
        // Test that the text element contains "Text <idx>"
        ONOXMLElement *textElement = [element firstChildWithTag:@"text"];
        XCTAssertNotNil(textElement, @"Text element is nil");
        XCTAssertEqualObjects(textElement.tag, @"text", @"tag should be `text`");
        NSString *expectedTextContent = [NSString stringWithFormat:@"Text %lu", (u_long) idx];
        XCTAssertEqualObjects([textElement stringValue], expectedTextContent, @"Text content should be `%@`", expectedTextContent);
        
        
        // Test that the answerCode element contains "Code <idx>"
        ONOXMLElement *answerCodeElement = [element firstChildWithTag:@"answerCode"];
        XCTAssertNotNil(answerCodeElement, @"Answer code element is nil");
        XCTAssertEqualObjects(answerCodeElement.tag, @"answerCode", @"tag should be `answerCode`");
        NSString *expectedAnswerCodeContent = [NSString stringWithFormat:@"Code %lu", (u_long) idx];
        XCTAssertEqualObjects([answerCodeElement stringValue], expectedAnswerCodeContent, @"Answer code content should be `%@`", expectedAnswerCodeContent);
        
        count++;
    }];
    XCTAssertEqual(8, count, @"Wrong number of elements");
}

#pragma mark - XPath tests

- (void)testSingleElementUsingChildWithXPath {
    NSString *XPath = @"/elementType/multiCheckBox/checkBoxes/checkBox";
    ONOXMLElement *checkBoxElement = [self.document firstChildWithXPath:XPath];
    
    // Test that the first text element contains "Text 0"
    ONOXMLElement *textElement = [checkBoxElement firstChildWithXPath:@"text"];
    XCTAssertNotNil(textElement, @"Text element is nil");
    XCTAssertEqualObjects(textElement.tag, @"text", @"tag should be `text`");
    XCTAssertEqualObjects([textElement stringValue], @"Text 0", @"Text content should be `Text 0`");
    
    // Test that the first answerCode element contains "Code 0"
    ONOXMLElement *answerCodeElement = [checkBoxElement firstChildWithXPath:@"answerCode"];
    XCTAssertNotNil(answerCodeElement, @"Answer code element is nil");
    XCTAssertEqualObjects(answerCodeElement.tag, @"answerCode", @"tag should be `answerCode`");
    XCTAssertEqualObjects([answerCodeElement stringValue], @"Code 0", @"Answer code content should be `Code 0`");
}

- (void)testTextElementsUsingChildWithXPath {
    NSString *XPath = @"/elementType/multiCheckBox/checkBoxes/checkBox";
    __block NSUInteger count = 0;
    [self.document enumerateElementsWithXPath:XPath usingBlock:^(ONOXMLElement *element, NSUInteger idx, BOOL *stop) {
        XCTAssertEqualObjects(@"checkBox", element.tag, @"tag should be `checkBox`");
        
        // Test that the text element contains "Text <idx>"
        ONOXMLElement *textElement = [element firstChildWithXPath:@"text"];
        XCTAssertNotNil(textElement, @"Text element is nil");
        XCTAssertEqualObjects(textElement.tag, @"text", @"tag should be `text`");
        NSString *expectedTextContent = [NSString stringWithFormat:@"Text %lu", (u_long) idx];
        XCTAssertEqualObjects([textElement stringValue], expectedTextContent, @"Text content should be `%@`", expectedTextContent);
        
        
        // Test that the answerCode element contains "Code <idx>"
        ONOXMLElement *answerCodeElement = [element firstChildWithXPath:@"answerCode"];
        XCTAssertNotNil(answerCodeElement, @"Answer code element is nil");
        XCTAssertEqualObjects(answerCodeElement.tag, @"answerCode", @"tag should be `answerCode`");
        NSString *expectedAnswerCodeContent = [NSString stringWithFormat:@"Code %lu", (u_long) idx];
        XCTAssertEqualObjects([answerCodeElement stringValue], expectedAnswerCodeContent, @"Answer code content should be `%@`", expectedAnswerCodeContent);
        
        count++;
    }];
    XCTAssertEqual(8, count, @"Wrong number of elements");
}

@end
