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
