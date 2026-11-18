//
//  MWMAboutWindow.h
//  Slate
//
//  The About window: MWM's icon, name and version, what it is, where it comes from, links and
//  the license, all visible at once. It replaces the standard About panel, which shows an
//  icon macOS remembered and scrolls its credits.
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

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MWMAboutWindow : NSObject

// The content of the window, laid out at its width (also for tests and screenshots).
+ (NSView *)contentView;
+ (void)showWindow;

@end

NS_ASSUME_NONNULL_END
