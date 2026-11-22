//
//  NSAlert+MWM.m
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

#import "NSAlert+MWM.h"

const CGFloat MWMAlertWidth = 560;

@implementation NSAlert (MWM)

+ (instancetype)mwm_alert {
  NSAlert *alert = [[NSAlert alloc] init];
  NSImage *icon = [[NSBundle mainBundle] imageForResource:@"icon"];
  if (icon != nil) [alert setIcon:icon];
  [alert mwm_widen];
  return alert;
}

- (void)mwm_widen {
  NSView *accessory = self.accessoryView;
  if (accessory == nil) {
    // An empty view as wide as we want: the alert makes its text column as wide as its widest part.
    [self setAccessoryView:[[NSView alloc] initWithFrame:NSMakeRect(0, 0, MWMAlertWidth, 1)]];
    return;
  }
  NSRect frame = accessory.frame;
  if (frame.size.width < MWMAlertWidth) {
    frame.size.width = MWMAlertWidth;
    [accessory setFrame:frame];
  }
}

@end
