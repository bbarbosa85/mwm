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
#import "NSAlert+MWM.h"

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

- (void)testAnAlertIsWideAndUsesMWMsIcon {
  NSAlert *alert = [NSAlert mwm_alert];
  [alert setMessageText:@"Your configuration was updated"];
  [alert setInformativeText:@"~/.mwm.yml now uses the new format: one entry per monitor and slot, and actions written out as fields. Nothing changes in how your shortcuts work."];
  [alert addButtonWithTitle:@"OK"];
  [alert layout];
  XCTAssertGreaterThanOrEqual(NSWidth([[alert window] frame]), 540, @"room for the message without a line break every few words");
  CGFloat widest = 0;
  NSMutableArray *queue = [NSMutableArray arrayWithObject:[[alert window] contentView]];
  while ([queue count] > 0) {
    NSView *view = [queue lastObject]; [queue removeLastObject];
    if ([view isKindOfClass:[NSTextField class]] && [[(NSTextField *)view stringValue] hasPrefix:@"~/.mwm.yml"]) widest = NSWidth(view.frame);
    [queue addObjectsFromArray:[view subviews]];
  }
  XCTAssertGreaterThanOrEqual(widest, 400, @"the message wraps at the wider width, not at a narrow column");
  XCTAssertGreaterThanOrEqual([[alert icon] size].width, 128, @"the bundle's icon, not the system's");
  NSImage *bundleIcon = [[NSBundle mainBundle] imageForResource:@"icon"];
  XCTAssertEqualObjects([[alert icon] TIFFRepresentation], [bundleIcon TIFFRepresentation]);
}

- (void)testAnAccessoryIsWidenedToo {
  NSAlert *alert = [NSAlert mwm_alert];
  NSTextField *field = [NSTextField textFieldWithString:@"name"];
  [field setFrame:NSMakeRect(0, 0, 240, 24)];
  [alert setAccessoryView:field];
  [alert mwm_widen];
  XCTAssertGreaterThanOrEqual(NSWidth(field.frame), MWMAlertWidth);
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
