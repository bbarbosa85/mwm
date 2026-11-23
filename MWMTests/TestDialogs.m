//
//  TestDialogs.m
//
//  MWM's alerts and About window: its own icon, wide enough to read.
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

#import <XCTest/XCTest.h>
#import "MWMAboutWindow.h"
#import "MWMAlert.h"

@interface TestDialogs : XCTestCase
@end

@implementation TestDialogs

- (NSArray<NSString *> *)textsIn:(NSView *)root {
  NSMutableArray *texts = [NSMutableArray array];
  NSMutableArray *queue = [NSMutableArray arrayWithObject:root];
  while ([queue count] > 0) {
    NSView *view = [queue lastObject];
    [queue removeLastObject];
    if ([view isKindOfClass:[NSTextField class]]) [texts addObject:[(NSTextField *)view stringValue]];
    if ([view isKindOfClass:[NSButton class]]) [texts addObject:[(NSButton *)view title]];
    [queue addObjectsFromArray:[view subviews]];
  }
  return texts;
}

- (void)testAnAlertHasATileATitleTheSentenceAndButtons {
  MWMAlert *alert = [MWMAlert alert];
  [alert setKind:MWMAlertKindConfirm];
  [alert setMessageText:@"Discard your changes?"];
  [alert setInformativeText:@"This slot has changes that haven't been saved."];
  [alert addButtonWithTitle:@"Keep editing"];
  [alert addDestructiveButtonWithTitle:@"Discard"];
  NSView *content = [[alert window] contentView];
  NSArray *texts = [self textsIn:content];
  XCTAssertTrue([texts containsObject:@"Discard your changes?"]);
  XCTAssertTrue([texts containsObject:@"This slot has changes that haven't been saved."]);
  XCTAssertTrue([texts containsObject:@"Keep editing"]);
  XCTAssertTrue([texts containsObject:@"Discard"]);
  XCTAssertEqualWithAccuracy(NSWidth([[alert window] frame]), 440, 1);
}

- (void)testTheFirstButtonIsTheDefaultAndCancelAnswersEscape {
  MWMAlert *alert = [MWMAlert alert];
  NSButton *first = [alert addButtonWithTitle:@"Keep editing"];
  NSButton *cancel = [alert addButtonWithTitle:@"Cancel"];
  NSButton *last = [alert addDestructiveButtonWithTitle:@"Delete"];
  XCTAssertEqualObjects(first.keyEquivalent, @"\r");
  XCTAssertEqualObjects(cancel.keyEquivalent, @"\e");
  XCTAssertEqualObjects(last.keyEquivalent, @"");
  XCTAssertEqual(first.tag, NSAlertFirstButtonReturn);
  XCTAssertEqual(last.tag, NSAlertFirstButtonReturn + 2);
}

- (void)testAnAlertWithNoButtonsGetsOK {
  MWMAlert *alert = [MWMAlert alert];
  [alert setMessageText:@"Done"];
  XCTAssertTrue([[self textsIn:[[alert window] contentView]] containsObject:@"OK"]);
}

- (void)testAnAccessoryFillsTheAlertsWidth {
  MWMAlert *alert = [MWMAlert alert];
  NSTextField *field = [NSTextField textFieldWithString:@"name"];
  [field setFrame:NSMakeRect(0, 0, 240, 24)];
  [alert setAccessoryView:field];
  [alert setMessageText:@"Rename"];
  [alert addButtonWithTitle:@"OK"];
  NSWindow *window = [alert window];
  [[window contentView] layoutSubtreeIfNeeded];
  XCTAssertGreaterThanOrEqual(NSWidth(field.frame), 390);
}

- (void)testTheAboutWindowShowsEverythingAtOnce {
  NSView *content = [MWMAboutWindow contentView];
  XCTAssertGreaterThanOrEqual(NSWidth(content.frame), 540);
  NSArray *texts = [self textsIn:content];
  XCTAssertTrue([texts containsObject:@"MWM"]);
  XCTAssertTrue([[texts valueForKey:@"description"] componentsJoinedByString:@"|"].length > 0);
  BOOL hasVersion = NO, hasSlate = NO, hasLinks = NO;
  for (NSString *text in texts) {
    if ([text hasPrefix:@"Version "]) hasVersion = YES;
    if ([text containsString:@"fork of Slate"]) hasSlate = YES;
    if ([text isEqualToString:@"Contributors"]) hasLinks = YES;
  }
  XCTAssertTrue(hasVersion);
  XCTAssertTrue(hasSlate);
  XCTAssertTrue(hasLinks);
  XCTAssertLessThan(NSHeight(content.frame), 700, @"fits on screen without scrolling");
}

@end
