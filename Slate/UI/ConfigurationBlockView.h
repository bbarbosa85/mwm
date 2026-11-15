//
//  ConfigurationBlockView.h
//  Slate
//
//  Small views shared by the settings and displays pages: a softly tinted
//  rounded row, and a document view that keeps short content at the top of a
//  scroll view.
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

// A scroll view puts a short document at the bottom unless the document is flipped.
@interface ConfigurationFlippedView : NSView
@end

// A rounded, softly tinted row.
@interface ConfigurationBlockView : NSView
@end

NS_ASSUME_NONNULL_END
