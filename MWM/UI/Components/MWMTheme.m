//
//  MWMTheme.m
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

#import "MWMTheme.h"

const CGFloat MWMSpacingXS = 4;
const CGFloat MWMSpacingS = 8;
const CGFloat MWMSpacingM = 12;
const CGFloat MWMSpacingL = 16;
const CGFloat MWMSpacingXL = 20;

const CGFloat MWMRadiusS = 6;
const CGFloat MWMRadiusM = 10;
const CGFloat MWMRadiusL = 12;

const CGFloat MWMOpacityWash = 0.08;
const CGFloat MWMOpacitySelected = 0.16;
const CGFloat MWMOpacityStrong = 0.25;
const CGFloat MWMOpacityOutline = 0.55;

static NSColor *Named(NSString *name, NSColor *fallback) {
  NSColor *color = [NSColor colorNamed:name bundle:[NSBundle bundleForClass:[MWMTheme class]]];
  return color ?: fallback;
}

@implementation MWMTheme

+ (NSColor *)surface { return Named(@"MWMSurface", [[NSColor labelColor] colorWithAlphaComponent:0.05]); }
+ (NSColor *)surfaceStrong { return Named(@"MWMSurfaceStrong", [[NSColor labelColor] colorWithAlphaComponent:0.10]); }
+ (NSColor *)stroke { return Named(@"MWMStroke", [NSColor quaternaryLabelColor]); }

+ (NSColor *)textPrimary { return [NSColor labelColor]; }
+ (NSColor *)textSecondary { return [NSColor secondaryLabelColor]; }
+ (NSColor *)textTertiary { return [NSColor tertiaryLabelColor]; }

+ (NSColor *)accent { return [NSColor controlAccentColor]; }
+ (NSColor *)success { return Named(@"MWMSuccess", [NSColor systemGreenColor]); }
+ (NSColor *)feature { return Named(@"MWMFeature", [NSColor systemPurpleColor]); }
+ (NSColor *)warning { return Named(@"MWMWarning", [NSColor systemOrangeColor]); }
+ (NSColor *)reserved { return Named(@"MWMReserved", [NSColor systemYellowColor]); }
+ (NSColor *)groupColor { return Named(@"MWMGroup", [NSColor systemPinkColor]); }
+ (NSColor *)danger { return Named(@"MWMDanger", [NSColor systemRedColor]); }

+ (NSColor *)tint:(NSColor *)color opacity:(CGFloat)opacity { return [color colorWithAlphaComponent:opacity]; }

+ (NSFont *)fontCaption { return [NSFont systemFontOfSize:11]; }
+ (NSFont *)fontCaptionStrong { return [NSFont systemFontOfSize:11 weight:NSFontWeightMedium]; }
+ (NSFont *)fontSmall { return [NSFont systemFontOfSize:12]; }
+ (NSFont *)fontBody { return [NSFont systemFontOfSize:13]; }
+ (NSFont *)fontBodyStrong { return [NSFont systemFontOfSize:13 weight:NSFontWeightMedium]; }
+ (NSFont *)fontHeading { return [NSFont systemFontOfSize:15 weight:NSFontWeightMedium]; }
+ (NSFont *)fontTitle { return [NSFont systemFontOfSize:17 weight:NSFontWeightMedium]; }
+ (NSFont *)fontMono { return [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular]; }

@end
