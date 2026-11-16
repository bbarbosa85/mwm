//
//  ConfigurationSlotCanvas.m
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

#import "ConfigurationSlotCanvas.h"
#import "SlateSlots.h"

static const CGFloat kRulerHeight = 20;
static const CGFloat kHandle = 11;
static const CGFloat kSnapPixels = 8;      // how close counts as "on a guide"
static const CGFloat kMinimumSize = 0.02;  // a slot is never thinner than 2%

typedef NS_OPTIONS(NSUInteger, SlotEdges) {
  SlotEdgeNone = 0, SlotEdgeLeft = 1, SlotEdgeRight = 2, SlotEdgeTop = 4, SlotEdgeBottom = 8,
  SlotEdgeAll = 15,  // moving the whole slot
};

@interface ConfigurationSlotCanvas ()
@property (assign) SlotEdges dragging;
@property (assign) CGRect rectAtMouseDown;
@property (assign) NSPoint mouseDownPoint;
@end

@implementation ConfigurationSlotCanvas

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _aspect = 16.0 / 9.0;
    _editable = YES;
    _gridDivisions = 4;
  }
  return self;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }

- (void)setRect:(CGRect)rect { _rect = rect; [self setNeedsDisplay:YES]; }
- (void)setHasSlot:(BOOL)hasSlot { _hasSlot = hasSlot; [self setNeedsDisplay:YES]; }
- (void)setEditable:(BOOL)editable { _editable = editable; [self setNeedsDisplay:YES]; }
- (void)setGridDivisions:(NSInteger)divisions { _gridDivisions = divisions; [self setNeedsDisplay:YES]; }
- (void)setAspect:(CGFloat)aspect { _aspect = aspect > 0.2 ? aspect : 16.0 / 9.0; [self setNeedsDisplay:YES]; }

#pragma mark - Geometry

// The largest screen of the right shape that fits under the ruler.
- (NSRect)screenRect {
  NSRect area = NSMakeRect(8, 8, NSWidth([self bounds]) - 16, NSHeight([self bounds]) - kRulerHeight - 16);
  CGFloat width = area.size.width, height = width / self.aspect;
  if (height > area.size.height) { height = area.size.height; width = height * self.aspect; }
  return NSMakeRect(NSMidX(area) - width / 2, NSMinY(area), width, height);
}

- (NSRect)viewRectForSlot:(CGRect)r {
  NSRect screen = [self screenRect];
  return NSMakeRect(NSMinX(screen) + r.origin.x * NSWidth(screen),
                    NSMaxY(screen) - (r.origin.y + r.size.height) * NSHeight(screen),
                    r.size.width * NSWidth(screen), r.size.height * NSHeight(screen));
}

#pragma mark - Drawing

- (void)drawRect:(NSRect)dirtyRect {
  NSRect screen = [self screenRect];
  NSBezierPath *frame = [NSBezierPath bezierPathWithRoundedRect:screen xRadius:10 yRadius:10];
  [[[NSColor labelColor] colorWithAlphaComponent:0.05] setFill];
  [frame fill];
  [[NSColor tertiaryLabelColor] setStroke];
  [frame setLineWidth:1.5];
  [frame stroke];

  // The grid: evenly spaced, faint lines.
  NSInteger n = self.gridDivisions;
  if (n >= 2) {
    NSBezierPath *lines = [NSBezierPath bezierPath];
    for (NSInteger i = 1; i < n; i++) {
      CGFloat x = NSMinX(screen) + (CGFloat)i / n * NSWidth(screen), y = NSMinY(screen) + (CGFloat)i / n * NSHeight(screen);
      [lines moveToPoint:NSMakePoint(x, NSMinY(screen))]; [lines lineToPoint:NSMakePoint(x, NSMaxY(screen))];
      [lines moveToPoint:NSMakePoint(NSMinX(screen), y)]; [lines lineToPoint:NSMakePoint(NSMaxX(screen), y)];
    }
    [lines setLineWidth:1];
    [[[NSColor labelColor] colorWithAlphaComponent:0.12] setStroke];
    [lines stroke];
  }
  // The ruler above the screen follows the grid (every line when there are few).
  NSDictionary *tick = @{NSFontAttributeName: [NSFont systemFontOfSize:10], NSForegroundColorAttributeName: [NSColor tertiaryLabelColor]};
  NSMutableArray *marks = [NSMutableArray array];
  if (n >= 2 && n <= 6) for (NSInteger i = 0; i <= n; i++) [marks addObject:@((CGFloat)i / n)];
  else [marks addObjectsFromArray:@[@0, @0.5, @1]];
  for (NSNumber *mark in marks) {
    NSString *label = [NSString stringWithFormat:@"%.0f%%", [mark doubleValue] * 100];
    NSSize size = [label sizeWithAttributes:tick];
    CGFloat x = NSMinX(screen) + [mark doubleValue] * NSWidth(screen) - size.width / 2;
    x = MIN(MAX(x, NSMinX(screen)), NSMaxX(screen) - size.width);
    [label drawAtPoint:NSMakePoint(x, NSMaxY(screen) + 3) withAttributes:tick];
  }

  if (!self.hasSlot) return;
  NSRect slot = [self viewRectForSlot:self.rect];
  NSColor *accent = self.editable ? [NSColor controlAccentColor] : [NSColor secondaryLabelColor];
  NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:slot xRadius:7 yRadius:7];
  [[accent colorWithAlphaComponent:0.18] setFill];
  [path fill];
  [accent setStroke];
  [path setLineWidth:2];
  [path stroke];

  NSDictionary *nameAttributes = @{NSFontAttributeName: [NSFont systemFontOfSize:14 weight:NSFontWeightMedium], NSForegroundColorAttributeName: accent};
  NSDictionary *summaryAttributes = @{NSFontAttributeName: [NSFont systemFontOfSize:11], NSForegroundColorAttributeName: [accent colorWithAlphaComponent:0.85]};
  NSString *name = [self.title length] > 0 ? self.title : @"New slot";
  NSString *summary = [[SlateSlot slotNamed:@"" rect:self.rect preset:NO] summary];
  NSSize nameSize = [name sizeWithAttributes:nameAttributes], summarySize = [summary sizeWithAttributes:summaryAttributes];
  if (nameSize.width < NSWidth(slot) - 8) {
    [name drawAtPoint:NSMakePoint(NSMidX(slot) - nameSize.width / 2, NSMidY(slot) + 1) withAttributes:nameAttributes];
    if (summarySize.width < NSWidth(slot) - 8) [summary drawAtPoint:NSMakePoint(NSMidX(slot) - summarySize.width / 2, NSMidY(slot) - summarySize.height - 1) withAttributes:summaryAttributes];
  }

  // Where the sides are, in percent.
  NSDictionary *tagAttributes = @{NSFontAttributeName: [NSFont systemFontOfSize:10 weight:NSFontWeightMedium], NSForegroundColorAttributeName: [NSColor whiteColor]};
  for (NSArray *tag in @[@[[NSString stringWithFormat:@"%.0f%%", self.rect.origin.x * 100], @(NSMinX(slot) + 6)],
                         @[[NSString stringWithFormat:@"%.0f%%", CGRectGetMaxX(self.rect) * 100], @(NSMaxX(slot) - 6)]]) {
    NSSize size = [tag[0] sizeWithAttributes:tagAttributes];
    CGFloat x = [tag[1] doubleValue];
    NSRect pill = NSMakeRect(x < NSMidX(slot) ? x : x - size.width - 10, NSMaxY(slot) - 20, size.width + 10, 16);
    if (NSWidth(slot) < 2 * (size.width + 16)) continue;
    [accent setFill];
    [[NSBezierPath bezierPathWithRoundedRect:pill xRadius:8 yRadius:8] fill];
    [tag[0] drawAtPoint:NSMakePoint(pill.origin.x + 5, pill.origin.y + 1.5) withAttributes:tagAttributes];
  }

  if (!self.editable) return;
  for (NSValue *value in [self handleRectsForSlot:slot]) {
    NSBezierPath *handle = [NSBezierPath bezierPathWithRoundedRect:[value rectValue] xRadius:3 yRadius:3];
    [[NSColor controlBackgroundColor] setFill];
    [handle fill];
    [accent setStroke];
    [handle setLineWidth:1.5];
    [handle stroke];
  }
}

// Four corners and four sides, in the order of the edge masks below.
- (NSArray<NSValue *> *)handleRectsForSlot:(NSRect)s {
  NSMutableArray *rects = [NSMutableArray array];
  for (NSNumber *edges in [self handleEdges]) {
    NSPoint p = [self pointForEdges:(SlotEdges)[edges unsignedIntegerValue] inSlot:s];
    [rects addObject:[NSValue valueWithRect:NSMakeRect(p.x - kHandle / 2, p.y - kHandle / 2, kHandle, kHandle)]];
  }
  return rects;
}

- (NSArray<NSNumber *> *)handleEdges {
  return @[@(SlotEdgeLeft | SlotEdgeTop), @(SlotEdgeRight | SlotEdgeTop), @(SlotEdgeLeft | SlotEdgeBottom), @(SlotEdgeRight | SlotEdgeBottom),
           @(SlotEdgeTop), @(SlotEdgeBottom), @(SlotEdgeLeft), @(SlotEdgeRight)];
}

// The point of a handle: a corner, or the middle of a side.
- (NSPoint)pointForEdges:(SlotEdges)edges inSlot:(NSRect)s {
  CGFloat x = (edges & SlotEdgeLeft) ? NSMinX(s) : (edges & SlotEdgeRight) ? NSMaxX(s) : NSMidX(s);
  CGFloat y = (edges & SlotEdgeTop) ? NSMaxY(s) : (edges & SlotEdgeBottom) ? NSMinY(s) : NSMidY(s);
  return NSMakePoint(x, y);
}

#pragma mark - Mouse

// Which sides a point on the slot grabs: a handle's sides, the whole slot, or none.
- (SlotEdges)edgesAtPoint:(NSPoint)point {
  if (!self.hasSlot || !self.editable) return SlotEdgeNone;
  NSRect slot = [self viewRectForSlot:self.rect];
  NSArray *edges = [self handleEdges];
  NSArray *rects = [self handleRectsForSlot:slot];
  for (NSUInteger i = 0; i < [rects count]; i++) {
    if (NSPointInRect(point, NSInsetRect([rects[i] rectValue], -4, -4))) return (SlotEdges)[edges[i] unsignedIntegerValue];
  }
  // The sides themselves can be grabbed along their length.
  CGFloat grab = 6;
  BOOL inX = point.x >= NSMinX(slot) && point.x <= NSMaxX(slot), inY = point.y >= NSMinY(slot) && point.y <= NSMaxY(slot);
  if (inY && fabs(point.x - NSMinX(slot)) <= grab) return SlotEdgeLeft;
  if (inY && fabs(point.x - NSMaxX(slot)) <= grab) return SlotEdgeRight;
  if (inX && fabs(point.y - NSMaxY(slot)) <= grab) return SlotEdgeTop;
  if (inX && fabs(point.y - NSMinY(slot)) <= grab) return SlotEdgeBottom;
  return NSPointInRect(point, slot) ? SlotEdgeAll : SlotEdgeNone;
}

- (void)mouseDown:(NSEvent *)event {
  NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
  self.dragging = [self edgesAtPoint:point];
  self.rectAtMouseDown = self.rect;
  self.mouseDownPoint = point;
}

- (void)mouseDragged:(NSEvent *)event {
  NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
  [self dragTo:point free:([event modifierFlags] & NSEventModifierFlagOption) != 0];
}

- (void)mouseUp:(NSEvent *)event {
  self.dragging = SlotEdgeNone;
}

- (void)resetCursorRects {
  if (self.hasSlot && self.editable) [self addCursorRect:[self viewRectForSlot:self.rect] cursor:[NSCursor openHandCursor]];
}

// The grid line within tolerance of a value, or NAN.
static CGFloat NearLine(CGFloat v, CGFloat tolerance, NSInteger divisions) {
  if (divisions < 2) return NAN;
  CGFloat line = round(v * divisions) / divisions;
  return fabs(v - line) <= tolerance ? line : NAN;
}

// Moves the sides being dragged. They snap to the grid unless free (⌥).
- (void)dragTo:(NSPoint)point free:(BOOL)free {
  if (self.dragging == SlotEdgeNone) return;
  NSRect screen = [self screenRect];
  CGFloat dx = (point.x - self.mouseDownPoint.x) / NSWidth(screen);
  CGFloat dy = -(point.y - self.mouseDownPoint.y) / NSHeight(screen);  // up on screen is smaller y
  CGFloat toleranceX = kSnapPixels / NSWidth(screen), toleranceY = kSnapPixels / NSHeight(screen);
  CGRect start = self.rectAtMouseDown;
  CGFloat left = CGRectGetMinX(start), right = CGRectGetMaxX(start), top = CGRectGetMinY(start), bottom = CGRectGetMaxY(start);
  // One side: onto a grid line when near one, else to a whole percent (or as it is when free).
  CGFloat (^snap)(CGFloat, CGFloat) = ^CGFloat(CGFloat v, CGFloat tolerance) {
    if (free) return round(v * 1000) / 1000;
    return [SlateSlots snapped:v tolerance:tolerance divisions:self.gridDivisions];
  };
  // Moving: whichever side of the slot is nearer a grid line lands on it.
  CGFloat (^place)(CGFloat, CGFloat, CGFloat) = ^CGFloat(CGFloat origin, CGFloat length, CGFloat tolerance) {
    if (free) return round(origin * 1000) / 1000;
    CGFloat near = NearLine(origin, tolerance, self.gridDivisions), far = NearLine(origin + length, tolerance, self.gridDivisions);
    if (!isnan(near) && (isnan(far) || fabs(near - origin) <= fabs(far - length - origin))) return near;
    if (!isnan(far)) return far - length;
    return round(origin * 100) / 100;
  };
  if (self.dragging == SlotEdgeAll) {
    CGFloat width = right - left, height = bottom - top;
    CGFloat nl = MIN(MAX(place(left + dx, width, toleranceX), 0), 1 - width);
    CGFloat nt = MIN(MAX(place(top + dy, height, toleranceY), 0), 1 - height);
    left = nl; right = nl + width; top = nt; bottom = nt + height;
  } else {
    if (self.dragging & SlotEdgeLeft) left = MIN(MAX(snap(left + dx, toleranceX), 0), right - kMinimumSize);
    if (self.dragging & SlotEdgeRight) right = MAX(MIN(snap(right + dx, toleranceX), 1), left + kMinimumSize);
    if (self.dragging & SlotEdgeTop) top = MIN(MAX(snap(top + dy, toleranceY), 0), bottom - kMinimumSize);
    if (self.dragging & SlotEdgeBottom) bottom = MAX(MIN(snap(bottom + dy, toleranceY), 1), top + kMinimumSize);
  }
  CGRect updated = CGRectMake(left, top, right - left, bottom - top);
  if (CGRectEqualToRect(updated, self.rect)) return;
  self.rect = updated;
  [self.delegate slotCanvas:self didChangeRect:updated];
}

- (void)dragFrom:(NSPoint)from to:(NSPoint)to free:(BOOL)free {
  self.dragging = [self edgesAtPoint:from];
  self.rectAtMouseDown = self.rect;
  self.mouseDownPoint = from;
  [self dragTo:to free:free];
  self.dragging = SlotEdgeNone;
}

@end
