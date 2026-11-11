//
//  LineNumberGutterView.m
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

#import "LineNumberGutterView.h"

static const CGFloat kPadding = 8;

@interface LineNumberGutterView ()
@property (weak) NSTextView *textView;
@property (strong) NSLayoutConstraint *widthConstraint;
@end

@implementation LineNumberGutterView

- (instancetype)initWithTextView:(NSTextView *)textView {
  self = [super initWithFrame:NSZeroRect];
  if (self) {
    _textView = textView;
    _errorLines = [NSIndexSet indexSet];
    [self setTranslatesAutoresizingMaskIntoConstraints:NO];
    _widthConstraint = [self.widthAnchor constraintEqualToConstant:[self thicknessForLineCount:1]];
    [_widthConstraint setActive:YES];
    if (@available(macOS 14.0, *)) {
      [self setClipsToBounds:YES];  // not the default for apps built with the macOS 14 SDK
    }
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    // Text storage edits include programmatic setString:, not just typing.
    [nc addObserver:self selector:@selector(textDidChange:) name:NSTextStorageDidProcessEditingNotification object:[textView textStorage]];
    NSClipView *clip = [[textView enclosingScrollView] contentView];
    [clip setPostsBoundsChangedNotifications:YES];
    [nc addObserver:self selector:@selector(boundsDidChange:) name:NSViewBoundsDidChangeNotification object:clip];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)isFlipped {
  return YES;
}

- (NSFont *)numberFont {
  return [NSFont monospacedDigitSystemFontOfSize:10 weight:NSFontWeightRegular];
}

- (CGFloat)thicknessForLineCount:(NSUInteger)count {
  NSUInteger digits = MAX((NSUInteger)2, (NSUInteger)floor(log10((double)MAX(count, (NSUInteger)1))) + 1);
  CGFloat digitWidth = [@"8" sizeWithAttributes:@{NSFontAttributeName: [self numberFont]}].width;
  return ceil(digits * digitWidth + kPadding * 2);
}

- (NSUInteger)lineCount {
  NSString *text = [self.textView string];
  NSUInteger count = 1;
  for (NSUInteger i = 0; i < [text length]; i++) {
    if ([text characterAtIndex:i] == '\n') count++;
  }
  return count;
}

- (void)textDidChange:(NSNotification *)note {
  // Runs during text storage editing, where changing layout isn't allowed.
  dispatch_async(dispatch_get_main_queue(), ^{ [self updateThickness]; });
  [self setNeedsDisplay:YES];
}

- (void)updateThickness {
  CGFloat thickness = [self thicknessForLineCount:[self lineCount]];
  if ([self.widthConstraint constant] != thickness) [self.widthConstraint setConstant:thickness];
  [self setNeedsDisplay:YES];
}

- (void)boundsDidChange:(NSNotification *)note {
  [self setNeedsDisplay:YES];
}

- (void)setErrorLines:(NSIndexSet *)errorLines {
  _errorLines = [errorLines copy];
  [self setNeedsDisplay:YES];
}

// Draws `number` level with a line fragment given in text view coordinates.
- (void)drawNumber:(NSUInteger)number fragment:(NSRect)fragment scrollOffset:(CGFloat)offset {
  BOOL isError = [self.errorLines containsIndex:number];
  NSDictionary *attrs = @{
    NSFontAttributeName: isError ? [NSFont monospacedDigitSystemFontOfSize:10 weight:NSFontWeightBold] : [self numberFont],
    NSForegroundColorAttributeName: isError ? [NSColor systemRedColor] : [NSColor secondaryLabelColor],
  };
  NSString *label = [NSString stringWithFormat:@"%lu", (unsigned long)number];
  NSSize size = [label sizeWithAttributes:attrs];
  CGFloat top = NSMinY(fragment) + [self.textView textContainerInset].height - offset;
  [label drawAtPoint:NSMakePoint(NSWidth([self bounds]) - size.width - kPadding, top + (NSHeight(fragment) - size.height) / 2)
      withAttributes:attrs];
}

- (void)drawRect:(NSRect)dirtyRect {
  NSTextView *textView = self.textView;
  [[textView backgroundColor] setFill];
  NSRectFill([self bounds]);
  [[NSColor separatorColor] setFill];
  NSRectFill(NSMakeRect(NSWidth([self bounds]) - 1, 0, 1, NSHeight([self bounds])));
  if (textView == nil) return;

  NSLayoutManager *layoutManager = [textView layoutManager];
  NSString *text = [textView string];
  // The gutter's top lines up with the clip view's, so this is the scroll position.
  CGFloat offset = NSMinY([[[textView enclosingScrollView] contentView] bounds]);

  NSRange glyphs = [layoutManager glyphRangeForBoundingRect:[textView visibleRect] inTextContainer:[textView textContainer]];
  NSRange chars = [layoutManager characterRangeForGlyphRange:glyphs actualGlyphRange:NULL];

  // Line number of the first visible line.
  NSUInteger index = [text lineRangeForRange:NSMakeRange(MIN(chars.location, [text length]), 0)].location;
  NSUInteger line = 1;
  for (NSUInteger i = 0; i < index; i++) {
    if ([text characterAtIndex:i] == '\n') line++;
  }

  while (index < [text length] && index <= NSMaxRange(chars)) {
    NSRange lineRange = [text lineRangeForRange:NSMakeRange(index, 0)];
    NSUInteger glyph = [layoutManager glyphIndexForCharacterAtIndex:index];
    [self drawNumber:line fragment:[layoutManager lineFragmentRectForGlyphAtIndex:glyph effectiveRange:NULL] scrollOffset:offset];
    line++;
    index = NSMaxRange(lineRange);
  }

  // The empty line after a trailing newline (or an empty document).
  NSRect extra = [layoutManager extraLineFragmentRect];
  if (!NSIsEmptyRect(extra) && ([text length] == 0 || [text hasSuffix:@"\n"])) {
    [self drawNumber:line fragment:extra scrollOffset:offset];
  }
}

@end
