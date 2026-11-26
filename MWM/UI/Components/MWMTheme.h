//
//  MWMTheme.h
//  Slate
//
//  The design tokens of the configuration window: colors, type, spacing, radii and
//  opacities, named by what they are for. Pages use these instead of writing numbers
//  and system colors in place, so the look is changed here. Colors come from the
//  asset catalog (MWMColors.xcassets, with light and dark values) and fall back to
//  system colors if it isn't found.
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

// Spacing scale, in points.
extern const CGFloat MWMSpacingXS;    // 4
extern const CGFloat MWMSpacingS;     // 8
extern const CGFloat MWMSpacingM;     // 12
extern const CGFloat MWMSpacingL;     // 16
extern const CGFloat MWMSpacingXL;    // 20: the page margin

// Corner radii.
extern const CGFloat MWMRadiusS;      // 6: key caps, small tiles
extern const CGFloat MWMRadiusM;      // 10: list rows, selections
extern const CGFloat MWMRadiusL;      // 12: cards

// How strongly a color is laid over the surface.
extern const CGFloat MWMOpacityWash;       // 0.08: faint fill
extern const CGFloat MWMOpacitySelected;   // 0.16: selected row, pill, chip
extern const CGFloat MWMOpacityStrong;     // 0.25: key states, previews
extern const CGFloat MWMOpacityOutline;    // 0.55: outline of a tinted key

@interface MWMTheme : NSObject

// Surfaces and lines.
+ (NSColor *)surface;          // card background
+ (NSColor *)surfaceStrong;    // pressed or highlighted card
+ (NSColor *)stroke;           // outlines

// Text.
+ (NSColor *)textPrimary;
+ (NSColor *)textSecondary;
+ (NSColor *)textTertiary;

// Meaning.
+ (NSColor *)accent;           // the user's accent color: selection, primary actions, "move"
+ (NSColor *)success;          // windows and apps
+ (NSColor *)feature;          // hints, grid, switcher
+ (NSColor *)warning;          // conflicts, unsaved changes
+ (NSColor *)reserved;         // keys macOS keeps
+ (NSColor *)groupColor;       // the selected modifier group: its card, its pill and its keys on the keyboard
+ (NSColor *)danger;

// A color laid over the surface at one of the opacities above.
+ (NSColor *)tint:(NSColor *)color opacity:(CGFloat)opacity;

// Type.
+ (NSFont *)fontCaption;        // 11
+ (NSFont *)fontCaptionStrong;  // 11 medium
+ (NSFont *)fontSmall;          // 12
+ (NSFont *)fontBody;           // 13
+ (NSFont *)fontBodyStrong;     // 13 medium
+ (NSFont *)fontHeading;        // 15 medium
+ (NSFont *)fontTitle;          // 17 medium
+ (NSFont *)fontMono;           // 12 monospaced

@end

NS_ASSUME_NONNULL_END
