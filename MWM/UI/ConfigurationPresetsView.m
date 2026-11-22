//
//  ConfigurationPresetsView.m
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

#import "ConfigurationPresetsView.h"
#import "MWMTheme.h"
#import "MWMComponents.h"
#import "ConfigurationBlockView.h"
#import "MWMSlots.h"

@implementation ConfigurationPresetsView

// The groups, in the order they're listed.
+ (NSArray<NSArray *> *)groups {
  return @[@[@"Whole screen", @[@"full"]],
           @[@"Halves", @[@"lefthalf", @"righthalf", @"tophalf", @"bottomhalf"]],
           @[@"Thirds, side by side", @[@"third1", @"third2", @"third3"]],
           @[@"Thirds, stacked", @[@"thirdrow1", @"thirdrow2", @"thirdrow3"]],
           @[@"Quarters, side by side", @[@"quarter1", @"quarter2", @"quarter3", @"quarter4"]],
           @[@"Quarters, stacked", @[@"quarterrow1", @"quarterrow2", @"quarterrow3", @"quarterrow4"]]];
}

- (NSView *)rowForPreset:(MWMSlot *)preset {
  ConfigurationSlotThumbnail *picture = [[ConfigurationSlotThumbnail alloc] init];
  picture.rect = preset.rect;
  picture.valid = YES;
  [picture setTranslatesAutoresizingMaskIntoConstraints:NO];
  [NSLayoutConstraint activateConstraints:@[[picture.widthAnchor constraintEqualToConstant:52], [picture.heightAnchor constraintEqualToConstant:32]]];

  NSButton *name = [NSButton buttonWithTitle:preset.name target:self action:@selector(copyName:)];
  [name setBordered:NO];
  [name setFont:[NSFont monospacedSystemFontOfSize:13 weight:NSFontWeightRegular]];
  [name setAlignment:NSTextAlignmentLeft];
  [name setIdentifier:preset.name];
  [name setToolTip:[NSString stringWithFormat:@"Click to copy ${%@}", preset.name]];
  [name setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];

  NSTextField *size = [MWMComponents secondaryLabel:[preset summary]];
  [size setAlignment:NSTextAlignmentRight];

  NSStackView *row = [NSStackView stackViewWithViews:@[picture, name, size]];
  [row setSpacing:14];
  [row setAlignment:NSLayoutAttributeCenterY];
  [row setEdgeInsets:NSEdgeInsetsMake(8, 0, 8, 0)];
  return row;
}

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    NSMutableArray *blocks = [NSMutableArray array];
    for (NSArray *group in [[self class] groups]) {
      NSTextField *heading = [MWMComponents sectionHeading:group[0]];
      [blocks addObject:heading];
      [blocks addObject:[NSNull null]];  // a line under the heading
      NSArray *names = group[1];
      for (NSUInteger i = 0; i < [names count]; i++) {
        [blocks addObject:[self rowForPreset:[MWMSlots presetNamed:names[i]]]];
        if (i + 1 < [names count]) [blocks addObject:[NSNull null]];
      }
    }
    NSStackView *stack = [NSStackView stackViewWithViews:@[]];
    [stack setOrientation:NSUserInterfaceLayoutOrientationVertical];
    [stack setAlignment:NSLayoutAttributeLeading];
    [stack setSpacing:0];
    [stack setEdgeInsets:NSEdgeInsetsMake(4, 20, 24, 20)];
    [stack setTranslatesAutoresizingMaskIntoConstraints:NO];
    NSArray *views = blocks;
    for (NSUInteger i = 0; i < [views count]; i++) {
      id item = views[i];
      if (item == [NSNull null]) {
        NSView *line = [MWMComponents separator];
        [stack addArrangedSubview:line];
        [[line.widthAnchor constraintEqualToAnchor:stack.widthAnchor constant:-40] setActive:YES];
        continue;
      }
      NSView *view = item;
      BOOL heading = [view isKindOfClass:[NSTextField class]];
      [stack addArrangedSubview:view];
      if (heading) {
        // Space above a group heading, except the first.
        if (i > 0) [stack setCustomSpacing:22 afterView:[[stack arrangedSubviews] objectAtIndex:[[stack arrangedSubviews] count] - 2]];
        [stack setCustomSpacing:6 afterView:view];
      } else {
        [[view.widthAnchor constraintEqualToAnchor:stack.widthAnchor constant:-40] setActive:YES];
      }
    }

    NSScrollView *scroll = [MWMComponents scrollViewWithContent:stack];

    NSTextField *footer = [MWMComponents secondaryLabel:@"19 presets · click a name to copy it"];
    [footer setFont:[MWMTheme fontCaption]];
    [footer setTranslatesAutoresizingMaskIntoConstraints:NO];
    NSView *footerLine = [MWMComponents separator];

    [self addSubview:scroll];
    [self addSubview:footerLine];
    [self addSubview:footer];
    [NSLayoutConstraint activateConstraints:@[
      [scroll.topAnchor constraintEqualToAnchor:self.topAnchor], [scroll.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
      [scroll.trailingAnchor constraintEqualToAnchor:self.trailingAnchor], [scroll.bottomAnchor constraintEqualToAnchor:footerLine.topAnchor],
      [footerLine.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20], [footerLine.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20],
      [footerLine.bottomAnchor constraintEqualToAnchor:footer.topAnchor constant:-8],
      [footer.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20], [footer.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-12],
    ]];
  }
  return self;
}

// Copies "${name}", and says so for a moment.
- (void)copyName:(NSButton *)button {
  NSString *name = [button identifier];
  [[NSPasteboard generalPasteboard] clearContents];
  [[NSPasteboard generalPasteboard] setString:[NSString stringWithFormat:@"${%@}", name] forType:NSPasteboardTypeString];
  [button setTitle:@"Copied"];
  __weak NSButton *weakButton = button;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.9 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [weakButton setTitle:name]; });
}

@end
