//
//  ConfigurationBlockView.m
//  Slate
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

#import "ConfigurationBlockView.h"

@implementation ConfigurationFlippedView
- (BOOL)isFlipped { return YES; }
@end

@implementation ConfigurationBlockView
- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    [self setWantsLayer:YES];
    [[self layer] setCornerRadius:12];
  }
  return self;
}
- (void)viewDidChangeEffectiveAppearance {
  [super viewDidChangeEffectiveAppearance];
  [self.effectiveAppearance performAsCurrentDrawingAppearance:^{
    [[self layer] setBackgroundColor:[[[NSColor labelColor] colorWithAlphaComponent:0.05] CGColor]];
  }];
}
- (void)viewDidMoveToWindow {
  [super viewDidMoveToWindow];
  [self viewDidChangeEffectiveAppearance];
}
@end

@implementation ConfigurationSlotThumbnail
- (NSSize)intrinsicContentSize { return NSMakeSize(NSViewNoIntrinsicMetric, 84); }
- (void)drawRect:(NSRect)dirtyRect {
  NSRect bounds = NSInsetRect([self bounds], 1, 1);
  CGFloat height = MIN(NSHeight(bounds), NSWidth(bounds) / 1.7), width = height * 1.7;
  NSRect screen = NSMakeRect(NSMidX(bounds) - width / 2, NSMidY(bounds) - height / 2, width, height);
  NSBezierPath *frame = [NSBezierPath bezierPathWithRoundedRect:screen xRadius:6 yRadius:6];
  [[[NSColor labelColor] colorWithAlphaComponent:0.05] setFill];
  [frame fill];
  [[NSColor tertiaryLabelColor] setStroke];
  [frame setLineWidth:1.2];
  [frame stroke];
  if (!self.valid) return;
  NSRect slot = NSMakeRect(NSMinX(screen) + 3 + self.rect.origin.x * (NSWidth(screen) - 6),
                           NSMaxY(screen) - 3 - (self.rect.origin.y + self.rect.size.height) * (NSHeight(screen) - 6),
                           self.rect.size.width * (NSWidth(screen) - 6), self.rect.size.height * (NSHeight(screen) - 6));
  NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:slot xRadius:3 yRadius:3];
  [[[NSColor controlAccentColor] colorWithAlphaComponent:0.25] setFill];
  [path fill];
  [[NSColor controlAccentColor] setStroke];
  [path setLineWidth:1.5];
  [path stroke];
}
@end

