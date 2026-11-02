//
//  SlateTests.m
//  Slate
//
//  Created by Jigish Patel on 5/18/11.
//  Copyright 2011 Jigish Patel. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see http://www.gnu.org/licenses

#import "SlateTests.h"
#import "JSController.h"
#import "Operation.h"

@implementation SlateTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testExample
{
    XCTAssertTrue(true, @"Basic sanity check");
}

- (void)testJavaScriptCoreEvaluation
{
    JSController *jsc = [[JSController alloc] init];
    XCTAssertNotNil(jsc, @"JSController should instantiate");
    id res = [jsc run:@"1 + 2"];
    XCTAssertEqual([res integerValue], (NSInteger)3, @"1 + 2 should equal 3");

    id op = [jsc run:@"slate.operation('push', { 'direction': 'left', 'style': 'bar' });"];
    XCTAssertNotNil(op, @"slate.operation should return non-nil");
    XCTAssertTrue([op isKindOfClass:[Operation class]], @"Should return an Operation");
}

@end
