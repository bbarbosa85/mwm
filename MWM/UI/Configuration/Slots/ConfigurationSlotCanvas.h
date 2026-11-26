//
//  ConfigurationSlotCanvas.h
//  Slate
//
//  A screen drawn large, with guide lines at halves, thirds and quarters and one
//  slot on it that can be dragged and resized from its sides and corners.
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

@class ConfigurationSlotCanvas;

NS_ASSUME_NONNULL_BEGIN

@protocol ConfigurationSlotCanvasDelegate <NSObject>
// The slot was moved or resized by dragging.
- (void)slotCanvas:(ConfigurationSlotCanvas *)canvas didChangeRect:(CGRect)rect;
@end

@interface ConfigurationSlotCanvas : NSView

@property (weak, nullable) id<ConfigurationSlotCanvasDelegate> delegate;
// The slot as fractions of the screen (origin at the top left); NO slot when hasSlot is NO.
@property (assign, nonatomic) BOOL hasSlot;
@property (assign, nonatomic) CGRect rect;
@property (copy, nullable) NSString *title;
// Presets can be shown but not changed.
@property (assign, nonatomic) BOOL editable;
// Width / height of the screen being previewed.
@property (assign, nonatomic) CGFloat aspect;
// How many equal parts the grid divides the screen into (4 = quarters); 0 for none.
// The slot snaps to its lines.
@property (assign, nonatomic) NSInteger gridDivisions;

// The screen's area in the view's coordinates (not flipped).
- (NSRect)screenRect;
// For tests: the slot's rectangle on the view.
- (NSRect)viewRectForSlot:(CGRect)rect;
// For tests: drag from a point to another as the mouse would, optionally with ⌥ held.
- (void)dragFrom:(NSPoint)from to:(NSPoint)to free:(BOOL)free;
// The same, keeping the slot's proportions while it is resized (⇧).
- (void)dragFrom:(NSPoint)from to:(NSPoint)to free:(BOOL)free proportional:(BOOL)proportional;

@end

NS_ASSUME_NONNULL_END
