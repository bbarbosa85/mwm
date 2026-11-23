//
//  ConfigurationDisplaysView.m
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

#import "ConfigurationDisplaysView.h"
#import "MWMTheme.h"
#import "MWMComponents.h"
#import "ConfigurationBlockView.h"
#import "MWMConfigDocument.h"
#import "MWMDisplays.h"

// Column widths shared by the header and every row.
static const CGFloat kNameWidth = 200;
static const CGFloat kScreenWidth = 210;
static const CGFloat kSizeWidth = 100;
static const CGFloat kStatusWidth = 170;

#pragma mark - Arrangement drawing

// The connected screens, drawn to scale where they sit.
@interface ConfigurationArrangementView : ConfigurationBlockView
@property (copy) NSArray<MWMDisplay *> *displays;
@end

@implementation ConfigurationArrangementView

- (NSSize)intrinsicContentSize {
  return NSMakeSize(NSViewNoIntrinsicMetric, 150);
}

- (void)drawRect:(NSRect)dirtyRect {
  if ([self.displays count] == 0) return;
  CGFloat minX = CGFLOAT_MAX, minY = CGFLOAT_MAX, maxX = -CGFLOAT_MAX, maxY = -CGFLOAT_MAX;
  for (MWMDisplay *d in self.displays) {
    minX = MIN(minX, d.originX); minY = MIN(minY, d.originY);
    maxX = MAX(maxX, d.originX + d.width); maxY = MAX(maxY, d.originY + d.height);
  }
  NSRect area = NSInsetRect([self bounds], 24, 20);
  CGFloat scale = MIN(area.size.width / (maxX - minX), area.size.height / (maxY - minY));
  CGFloat offsetX = area.origin.x + (area.size.width - (maxX - minX) * scale) / 2;
  CGFloat offsetY = area.origin.y + (area.size.height - (maxY - minY) * scale) / 2;
  NSDictionary *nameAttributes = @{NSFontAttributeName: [NSFont systemFontOfSize:12 weight:NSFontWeightMedium], NSForegroundColorAttributeName: [MWMTheme textPrimary]};
  NSDictionary *sizeAttributes = @{NSFontAttributeName: [MWMTheme fontCaption], NSForegroundColorAttributeName: [MWMTheme textSecondary]};
  for (MWMDisplay *d in self.displays) {
    // y grows downward in the model; this view isn't flipped.
    NSRect rect = NSMakeRect(offsetX + (d.originX - minX) * scale,
                             offsetY + (maxY - d.originY - d.height) * scale, d.width * scale, d.height * scale);
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:6 yRadius:6];
    [[[MWMTheme accent] colorWithAlphaComponent:0.12] setFill];
    [path fill];
    [[MWMTheme textTertiary] setStroke];
    [path setLineWidth:1.5];
    [path stroke];
    NSString *title = d.builtIn ? @"Built-in" : d.name;
    NSSize titleSize = [title sizeWithAttributes:nameAttributes];
    NSString *size = [d sizeText];
    NSSize sizeSize = [size sizeWithAttributes:sizeAttributes];
    CGFloat midY = NSMidY(rect);
    [title drawAtPoint:NSMakePoint(NSMidX(rect) - titleSize.width / 2, midY) withAttributes:nameAttributes];
    [size drawAtPoint:NSMakePoint(NSMidX(rect) - sizeSize.width / 2, midY - sizeSize.height - 2) withAttributes:sizeAttributes];
  }
}

@end

#pragma mark - Page

@interface ConfigurationDisplaysView ()
@property (strong) NSStackView *stack;
@property (strong) NSTextField *statusLabel;
@property (copy) NSArray<MWMDisplay *> *displays;
@end

@implementation ConfigurationDisplaysView

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _displays = @[];
    _stack = [NSStackView stackViewWithViews:@[]];
    [_stack setOrientation:NSUserInterfaceLayoutOrientationVertical];
    [_stack setAlignment:NSLayoutAttributeLeading];
    [_stack setSpacing:10];
    [_stack setEdgeInsets:NSEdgeInsetsMake(8, 20, 20, 20)];
    [_stack setTranslatesAutoresizingMaskIntoConstraints:NO];
    NSScrollView *scroll = [MWMComponents scrollViewWithContent:_stack];
    [self addSubview:scroll];
    [MWMComponents pinView:scroll toEdgesOf:self insets:NSEdgeInsetsMake(0, 0, 0, 0)];
  }
  return self;
}

- (void)setDocument:(MWMConfigDocument *)document {
  _document = document;
  [self reload];
}

#pragma mark - Model

- (BOOL)ordersLeftToRight {
  for (MWMConfigEntry *entry in self.document.settings) {
    if ([entry.name isEqualToString:@"orderScreensLeftToRight"]) return ![[[entry.value description] lowercaseString] isEqualToString:@"false"];
  }
  return YES;  // MWM's default
}

- (BOOL)nameIsTaken:(NSString *)name {
  for (NSArray *section in @[self.document.modifiers, self.document.monitors, self.document.positions, self.document.aliases]) {
    for (MWMConfigEntry *entry in section) if ([entry.name isEqualToString:name]) return YES;
  }
  return NO;
}

- (NSString *)freeNameFor:(NSString *)base {
  NSString *name = base;
  for (NSUInteger i = 2; [self nameIsTaken:name]; i++) name = [NSString stringWithFormat:@"%@-%lu", base, (unsigned long)i];
  return name;
}

- (NSArray<MWMConfigEntry *> *)roleEntries {
  NSMutableArray *entries = [NSMutableArray array];
  for (MWMConfigEntry *entry in self.document.monitors) if ([MWMDisplays isRole:[entry.value description]]) [entries addObject:entry];
  return entries;
}

// Screens that are connected but that no entry names yet.
- (NSArray<MWMDisplay *> *)unnamedDisplays {
  NSMutableArray *unnamed = [NSMutableArray arrayWithArray:self.displays];
  for (MWMConfigEntry *entry in [self roleEntries]) {
    MWMDisplay *display = [MWMDisplays displayForRole:[entry.value description] in:self.displays];
    if (display != nil) [unnamed removeObjectIdenticalTo:display];
  }
  return unnamed;
}

- (void)detectAgain {
  self.displays = [MWMDisplays connected];
  for (MWMDisplay *display in [self unnamedDisplays]) {
    NSString *name = [self freeNameFor:[MWMDisplays suggestedNameForDisplay:display in:self.displays]];
    [self.document.monitors addObject:[MWMConfigEntry entryWithName:name value:[MWMDisplays roleForDisplay:display in:self.displays]]];
  }
  [self.delegate displaysViewDidChangeDocument:self];
  [self reload];
}

#pragma mark - Building

- (NSTextField *)labelWithText:(NSString *)text size:(CGFloat)size color:(NSColor *)color weight:(NSFontWeight)weight {
  return [MWMComponents labelWithText:text size:size color:color weight:weight];
}

- (NSView *)statusText:(NSString *)text {
  return [self columnText:text width:kStatusWidth color:[MWMTheme textSecondary]];
}

- (NSButton *)iconButton:(NSString *)symbol tip:(NSString *)tip action:(SEL)action identifier:(NSString *)identifier {
  NSButton *button = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:tip] target:self action:action];
  [button setBordered:NO];
  [button setToolTip:tip];
  [button setIdentifier:identifier];
  return button;
}

- (NSTextField *)nameFieldForEntry:(MWMConfigEntry *)entry {
  NSTextField *field = [NSTextField textFieldWithString:entry.name];
  [field setIdentifier:entry.name];
  [field setFont:[MWMTheme fontMono]];
  [field setTarget:self];
  [field setAction:@selector(nameEdited:)];
  [[field cell] setSendsActionOnEndEditing:YES];
  [[field.widthAnchor constraintEqualToConstant:kNameWidth] setActive:YES];
  return field;
}

// A fixed-width text column.
- (NSTextField *)columnText:(NSString *)text width:(CGFloat)width color:(NSColor *)color {
  NSTextField *label = [self labelWithText:text size:12 color:color weight:NSFontWeightRegular];
  [[label.widthAnchor constraintEqualToConstant:width] setActive:YES];
  return label;
}

// A full-width row in fixed columns (name, screen, size, status), with the actions on the right.
- (NSView *)rowWithName:(NSView *)name details:(NSArray<NSString *> *)details status:(NSView *)status actions:(NSArray<NSView *> *)actions dimmed:(BOOL)dimmed {
  ConfigurationBlockView *block = [[ConfigurationBlockView alloc] init];
  [block setTranslatesAutoresizingMaskIntoConstraints:NO];
  NSView *spacer = [MWMComponents spacer];
  NSMutableArray *views = [NSMutableArray arrayWithObjects:name,
      [self columnText:details[0] width:kScreenWidth color:[MWMTheme textSecondary]],
      [self columnText:details[1] width:kSizeWidth color:[MWMTheme textSecondary]],
      status, spacer, nil];
  [views addObjectsFromArray:actions];
  NSStackView *row = [NSStackView stackViewWithViews:views];
  [row setSpacing:12];
  [row setAlignment:NSLayoutAttributeCenterY];
  [row setTranslatesAutoresizingMaskIntoConstraints:NO];
  [block addSubview:row];
  [NSLayoutConstraint activateConstraints:@[
    [row.leadingAnchor constraintEqualToAnchor:block.leadingAnchor constant:14],
    [row.trailingAnchor constraintEqualToAnchor:block.trailingAnchor constant:-14],
    [row.topAnchor constraintEqualToAnchor:block.topAnchor constant:10],
    [row.bottomAnchor constraintEqualToAnchor:block.bottomAnchor constant:-10],
  ]];
  if (dimmed) [block setAlphaValue:0.55];
  return block;
}

// Column titles that line up with the rows under them.
- (NSView *)columnHeaderWithStatusTitle:(NSString *)statusTitle {
  NSMutableArray *views = [NSMutableArray array];
  for (NSArray *column in @[@[@"Name", @(kNameWidth)], @[@"Screen", @(kScreenWidth)], @[@"Size", @(kSizeWidth)], @[statusTitle, @(kStatusWidth)]]) {
    [views addObject:[self columnText:column[0] width:[column[1] doubleValue] color:[MWMTheme textTertiary]]];
  }
  NSStackView *header = [NSStackView stackViewWithViews:views];
  [header setSpacing:12];
  [header setEdgeInsets:NSEdgeInsetsMake(0, 14, 0, 14)];
  return header;
}

- (void)addFullWidth:(NSView *)view {
  [self.stack addArrangedSubview:view];
  [[view.widthAnchor constraintEqualToAnchor:self.stack.widthAnchor constant:-40] setActive:YES];
}

// Screen name and size, for the two columns.
- (NSArray<NSString *> *)detailsForDisplay:(MWMDisplay *)display {
  return @[display.builtIn ? @"Built-in display" : display.name, [display sizeText]];
}

// A screen that isn't connected: what the saved role says about it, size included.
- (NSArray<NSString *> *)detailsForRole:(NSString *)role {
  NSString *text = [[role substringFromIndex:[@"display:" length]] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  if ([text caseInsensitiveCompare:@"built-in"] == NSOrderedSame) return @[@"Built-in display", @"size unknown"];
  NSRegularExpression *number = [NSRegularExpression regularExpressionWithPattern:@"\\s+#[0-9]+$" options:0 error:nil];
  text = [number stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, [text length]) withTemplate:@""];
  NSRegularExpression *size = [NSRegularExpression regularExpressionWithPattern:@"\\s+([0-9]+x[0-9]+)$" options:0 error:nil];
  NSTextCheckingResult *match = [size firstMatchInString:text options:0 range:NSMakeRange(0, [text length])];
  if (match == nil) return @[text, @"size unknown"];
  return @[[text substringToIndex:[match range].location], [text substringWithRange:[match rangeAtIndex:1]]];
}

- (NSString *)roleLabelForDisplay:(MWMDisplay *)display {
  if (display.builtIn) return @"Built-in";
  NSUInteger twins = [MWMDisplays identicalCountForDisplay:display in:self.displays];
  if (twins <= 1) return @"Unique";
  NSString *role = [MWMDisplays roleForDisplay:display in:self.displays];
  NSRange hash = [role rangeOfString:@"#" options:NSBackwardsSearch];
  return [NSString stringWithFormat:@"%@ of %lu, left to right", [role substringFromIndex:hash.location + 1], (unsigned long)twins];
}

- (void)reload {
  for (NSView *view in [[self.stack arrangedSubviews] copy]) {
    [self.stack removeArrangedSubview:view];
    [view removeFromSuperview];
  }
  if (self.document == nil) return;
  self.displays = [MWMDisplays connected];

  // Top: what was detected, and the button to look again.
  NSString *count = [NSString stringWithFormat:@"%lu screen%@ connected", (unsigned long)[self.displays count], [self.displays count] == 1 ? @"" : @"s"];
  NSTextField *status = [self labelWithText:count size:13 color:[MWMTheme textPrimary] weight:NSFontWeightMedium];
  NSButton *detect = [NSButton buttonWithTitle:@"Detect Again" target:self action:@selector(detectPressed:)];
  [detect setToolTip:@"Look at the connected screens again and add any that aren't named yet"];
  NSView *spacer = [MWMComponents spacer];
  NSStackView *header = [NSStackView stackViewWithViews:@[status, spacer, detect]];
  [header setAlignment:NSLayoutAttributeCenterY];
  [self addFullWidth:header];

  ConfigurationArrangementView *arrangement = [[ConfigurationArrangementView alloc] init];
  arrangement.displays = self.displays;
  [arrangement setTranslatesAutoresizingMaskIntoConstraints:NO];
  [self addFullWidth:arrangement];

  // A row for each named screen: connected ones first, the others dimmed.
  [self addFullWidth:[self columnHeaderWithStatusTitle:@"Role"]];
  NSMutableArray *notConnected = [NSMutableArray array];
  for (MWMConfigEntry *entry in [self roleEntries]) {
    MWMDisplay *display = [MWMDisplays displayForRole:[entry.value description] in:self.displays];
    if (display == nil) { [notConnected addObject:entry]; continue; }
    [self addFullWidth:[self rowWithName:[self nameFieldForEntry:entry] details:[self detailsForDisplay:display]
                                  status:[self statusText:[self roleLabelForDisplay:display]]
                                 actions:@[[self iconButton:@"minus.circle" tip:@"Remove this name" action:@selector(removeEntry:) identifier:entry.name]]
                                  dimmed:NO]];
  }
  for (MWMDisplay *display in [self unnamedDisplays]) {
    NSButton *add = [NSButton buttonWithTitle:@"Add" target:self action:@selector(addDisplay:)];
    [add setIdentifier:[MWMDisplays roleForDisplay:display in:self.displays]];
    NSTextField *name = [self labelWithText:[MWMDisplays suggestedNameForDisplay:display in:self.displays] size:12 color:[MWMTheme textSecondary] weight:NSFontWeightRegular];
    [name setFont:[MWMTheme fontMono]];
    [[name.widthAnchor constraintEqualToConstant:kNameWidth] setActive:YES];
    [self addFullWidth:[self rowWithName:name details:[self detailsForDisplay:display]
                                  status:[self statusText:@"Not named yet"] actions:@[add] dimmed:NO]];
  }
  for (MWMConfigEntry *entry in notConnected) {
    [self addFullWidth:[self rowWithName:[self nameFieldForEntry:entry] details:[self detailsForRole:[entry.value description]]
                                  status:[self statusText:@"Not connected"]
                                 actions:@[[self iconButton:@"minus.circle" tip:@"Remove this name" action:@selector(removeEntry:) identifier:entry.name]]
                                  dimmed:YES]];
  }

  // Old references (numbers, sizes) keep working; a number can become a role.
  NSMutableArray *others = [NSMutableArray array];
  for (MWMConfigEntry *entry in self.document.monitors) if (![MWMDisplays isRole:[entry.value description]]) [others addObject:entry];
  if ([others count] > 0) {
    NSTextField *title = [self labelWithText:@"Other references" size:13 color:[MWMTheme textPrimary] weight:NSFontWeightMedium];
    NSTextField *note = [self labelWithText:@"Numbers and sizes still work. A screen number changes when you plug or unplug a screen; a role doesn't." size:11 color:[MWMTheme textSecondary] weight:NSFontWeightRegular];
    NSStackView *heading = [NSStackView stackViewWithViews:@[title, note]];
    [heading setOrientation:NSUserInterfaceLayoutOrientationVertical];
    [heading setAlignment:NSLayoutAttributeLeading];
    [heading setSpacing:2];
    [self addFullWidth:heading];
    [self addFullWidth:[self columnHeaderWithStatusTitle:@"Reference"]];
    for (MWMConfigEntry *entry in others) [self addFullWidth:[self otherRowForEntry:entry]];
  }
}

// Old references: the screen a number points at, or the size a size reference looks for.
- (NSArray<NSString *> *)detailsForOtherEntry:(MWMConfigEntry *)entry target:(nullable MWMDisplay *)target {
  if (target != nil) return [self detailsForDisplay:target];
  NSString *text = [[entry.value description] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  NSRegularExpression *size = [NSRegularExpression regularExpressionWithPattern:@"^[0-9]+x[0-9]+$" options:0 error:nil];
  if ([size numberOfMatchesInString:text options:0 range:NSMakeRange(0, [text length])] == 1) return @[@"Any screen", text];
  return @[@"No connected screen", @"size unknown"];
}

- (NSView *)otherRowForEntry:(MWMConfigEntry *)entry {
  NSTextField *value = [NSTextField textFieldWithString:[entry.value description]];
  [value setIdentifier:entry.name];
  [value setFont:[MWMTheme fontMono]];
  [value setTarget:self];
  [value setAction:@selector(valueEdited:)];
  [[value cell] setSendsActionOnEndEditing:YES];
  [[value.widthAnchor constraintEqualToConstant:kStatusWidth] setActive:YES];
  NSMutableArray *actions = [NSMutableArray array];
  NSString *text = [[entry.value description] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  BOOL isNumber = [text length] > 0 && [text rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]].location == NSNotFound;
  // A number only means "Nth from the left" when MWM orders screens that way.
  MWMDisplay *target = isNumber && [self ordersLeftToRight] ? [MWMDisplays displayForNumber:[text integerValue] leftToRight:[self ordersLeftToRight] in:self.displays] : nil;
  if (target != nil) {
    NSButton *convert = [NSButton buttonWithTitle:@"Use role" target:self action:@selector(convertEntry:)];
    [convert setIdentifier:entry.name];
    [convert setToolTip:[NSString stringWithFormat:@"Point at %@ by its role instead of its number", target.builtIn ? @"the built-in display" : target.name]];
    [actions addObject:convert];
  }
  [actions addObject:[self iconButton:@"minus.circle" tip:@"Remove" action:@selector(removeEntry:) identifier:entry.name]];
  return [self rowWithName:[self nameFieldForEntry:entry] details:[self detailsForOtherEntry:entry target:target]
                    status:value actions:actions dimmed:NO];
}

#pragma mark - Actions

- (MWMConfigEntry *)monitorNamed:(NSString *)name {
  for (MWMConfigEntry *entry in self.document.monitors) if ([entry.name isEqualToString:name]) return entry;
  return nil;
}

- (void)detectPressed:(id)sender {
  [self detectAgain];
}

- (void)addDisplay:(NSButton *)button {
  for (MWMDisplay *display in self.displays) {
    if (![[MWMDisplays roleForDisplay:display in:self.displays] isEqualToString:[button identifier]]) continue;
    NSString *name = [self freeNameFor:[MWMDisplays suggestedNameForDisplay:display in:self.displays]];
    [self.document.monitors addObject:[MWMConfigEntry entryWithName:name value:[button identifier]]];
    break;
  }
  [self.delegate displaysViewDidChangeDocument:self];
  [self reload];
}

- (void)removeEntry:(NSButton *)button {
  MWMConfigEntry *entry = [self monitorNamed:[button identifier]];
  if (entry == nil) return;
  [self.document.monitors removeObjectIdenticalTo:entry];
  [self.delegate displaysViewDidChangeDocument:self];
  [self reload];
}

- (void)convertEntry:(NSButton *)button {
  MWMConfigEntry *entry = [self monitorNamed:[button identifier]];
  NSInteger number = [[entry.value description] integerValue];
  MWMDisplay *display = [MWMDisplays displayForNumber:number leftToRight:[self ordersLeftToRight] in:self.displays];
  if (entry == nil || display == nil) return;
  entry.value = [MWMDisplays roleForDisplay:display in:self.displays];
  [self.delegate displaysViewDidChangeDocument:self];
  [self reload];
}

- (void)nameEdited:(NSTextField *)field {
  MWMConfigEntry *entry = [self monitorNamed:[field identifier]];
  NSString *name = [[field stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (entry == nil || [name isEqualToString:entry.name]) return;
  if ([name length] == 0 || [self nameIsTaken:name]) {  // a name is needed, and must be new
    NSBeep();
    [field setStringValue:entry.name];
    return;
  }
  entry.name = name;
  [field setIdentifier:name];
  [self.delegate displaysViewDidChangeDocument:self];
  [self reload];
}

- (void)valueEdited:(NSTextField *)field {
  MWMConfigEntry *entry = [self monitorNamed:[field identifier]];
  NSString *text = [[field stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (entry == nil || [text length] == 0 || [text isEqualToString:[entry.value description]]) return;
  entry.value = text;
  [self.delegate displaysViewDidChangeDocument:self];
  [self reload];
}

@end
