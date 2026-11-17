//
//  MWMDesignGallery.h
//  Slate
//
//  A page showing every token and component of the design system, in one place:
//  the colors, the type scale, spacing and radii, and each reusable component in
//  its states. It is how a design change is checked, and what the snapshot tests
//  render. Open it from the status menu with the Option key held.
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

@interface MWMDesignGallery : NSObject

// The page, laid out at the given width.
+ (NSView *)galleryViewWithWidth:(CGFloat)width;
// Shows the gallery in its own window.
+ (void)showWindow;

@end

NS_ASSUME_NONNULL_END
