//
//  LineNumberGutterView.h
//  Slate
//
//  Line numbers for a non-wrapping NSTextView. Sits beside the text view's
//  scroll view (same top and bottom) and follows its scrolling.
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

@interface LineNumberGutterView : NSView

// The text view must already be the document view of a scroll view.
- (instancetype)initWithTextView:(NSTextView *)textView;

// Resizes the gutter for the current line count. Runs automatically after edits.
- (void)updateThickness;

// 1-based line numbers drawn in red.
@property (copy, nonatomic) NSIndexSet *errorLines;

@end

NS_ASSUME_NONNULL_END
