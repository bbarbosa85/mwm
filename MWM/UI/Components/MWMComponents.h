//
//  MWMComponents.h
//  Slate
//
//  The reusable pieces of the configuration window, built from MWMTheme: labels,
//  cards, chips, icon tiles, separators and buttons. Pages ask for these instead
//  of assembling them again.
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

// A small rounded label with a tinted background, like "● Unsaved changes" or a conflict note.
// With no color it shows quiet text and no background.
@interface MWMChipView : NSView
@property (copy, nonatomic) NSString *text;
@property (strong, nonatomic, nullable) NSColor *color;
+ (instancetype)chipWithText:(NSString *)text color:(nullable NSColor *)color;
@end

// The top of a page opened from another: a back button with the parent's name, and the title.
@interface MWMSublevelHeader : NSView
@property (readonly) NSTextField *titleLabel;
@property (readonly) NSButton *backButton;
+ (instancetype)headerWithBackTitle:(NSString *)backTitle title:(NSString *)title target:(nullable id)target action:(nullable SEL)action;
@end

// The bar under an editor, below a line: whether there is anything to save, then Save and Cancel.
@interface MWMSaveBar : NSView
@property (readonly) MWMChipView *chip;
@property (readonly) NSButton *cancelButton;
@property (readonly) NSButton *saveButton;
+ (instancetype)barWithTarget:(nullable id)target cancel:(nullable SEL)cancel save:(nullable SEL)save;
// Shows "Unsaved changes" (or "No changes"), and turns Save on only when it can be used.
- (void)setDirty:(BOOL)dirty canSave:(BOOL)canSave;
@end

@interface MWMComponents : NSObject

// Text.
+ (NSTextField *)labelWithText:(NSString *)text font:(NSFont *)font color:(NSColor *)color;
+ (NSTextField *)labelWithText:(NSString *)text size:(CGFloat)size color:(NSColor *)color weight:(NSFontWeight)weight;
// Wraps onto more lines instead of cutting off.
+ (NSTextField *)wrappingLabelWithText:(NSString *)text size:(CGFloat)size color:(NSColor *)color weight:(NSFontWeight)weight;
+ (NSTextField *)bodyLabel:(NSString *)text;          // primary text
+ (NSTextField *)secondaryLabel:(NSString *)text;     // small, secondary
+ (NSTextField *)captionLabel:(NSString *)text;       // small, tertiary
+ (NSTextField *)titleLabel:(NSString *)text;         // page and editor titles

// A rounded, softly tinted container; add content with constraints.
+ (NSView *)card;
// A card with a dashed outline and no fill: a place for something that isn't there yet.
+ (NSView *)dashedCard;
// A thin line, as between the rows of a card.
+ (NSView *)separator;
// A small, quiet heading above a group of rows.
+ (NSTextField *)sectionHeading:(NSString *)text;
// A vertical scroller around content that keeps the width of the visible area and grows downward,
// starting at the top (the default for a short page).
+ (NSScrollView *)scrollViewWithContent:(NSView *)content;
// A rounded square with a symbol in a color: what a shortcut does, a feature, a group.
+ (NSView *)iconTileWithSymbol:(NSString *)symbolName color:(NSColor *)color size:(CGFloat)size;

// Buttons: the primary one answers Return.
+ (NSButton *)secondaryButtonWithTitle:(NSString *)title target:(nullable id)target action:(nullable SEL)action;
+ (NSButton *)secondaryButtonWithTitle:(NSString *)title symbol:(NSString *)symbolName target:(nullable id)target action:(nullable SEL)action;
// A small button filled with the accent color, white text and an optional symbol. Unlike primaryButton it
// is not the window's default button, so a page can have many (one per card).
+ (NSButton *)accentButtonWithTitle:(NSString *)title symbol:(nullable NSString *)symbolName target:(nullable id)target action:(nullable SEL)action;
+ (NSButton *)primaryButtonWithTitle:(NSString *)title symbol:(NSString *)symbolName target:(nullable id)target action:(nullable SEL)action;
+ (NSButton *)primaryButtonWithTitle:(NSString *)title target:(nullable id)target action:(nullable SEL)action;
// A button for an action that deletes or removes: red with white text.
+ (NSButton *)dangerButtonWithTitle:(NSString *)title target:(nullable id)target action:(nullable SEL)action;

// A flexible space for stack views.
+ (NSView *)spacer;

// A line of text with an optional smaller line under it.
+ (NSView *)titleWithSubtitle:(NSString *)title subtitle:(nullable NSString *)subtitle;
// Text on the left, a control on the right.
+ (NSView *)controlRowWithTitle:(NSString *)title subtitle:(nullable NSString *)subtitle control:(NSView *)control;
// A card with an icon, title and description in a column on the left, and the rows on the right.
+ (NSView *)settingsBlockWithSymbol:(NSString *)symbol title:(NSString *)title subtitle:(nullable NSString *)subtitle rows:(NSArray<NSView *> *)rows titleColumnWidth:(CGFloat)width;

// A control with a small caption above it, as in a form.
+ (NSStackView *)fieldWithCaption:(NSString *)caption control:(NSView *)control;
// Views in a column, each as wide as the column less its insets.
+ (NSStackView *)columnWithViews:(NSArray<NSView *> *)views spacing:(CGFloat)spacing insets:(NSEdgeInsets)insets;
// Views side by side in equal widths, aligned at the top.
+ (NSStackView *)equalRowWithViews:(NSArray<NSView *> *)views spacing:(CGFloat)spacing;
// A titled box for one topic of a form, with an optional control at the right of the title (a help button, a chip).
// Its rows are as wide as the box less its padding.
+ (NSView *)groupBoxWithTitle:(NSString *)title views:(NSArray<NSView *> *)views accessory:(nullable NSView *)accessory;

// Puts a view against the edges of another, inset.
+ (void)pinView:(NSView *)view toEdgesOf:(NSView *)container insets:(NSEdgeInsets)insets;

// A row that can be clicked and, when selected, is tinted: a list entry, a group, a choice.
// The content is laid out inside the insets; give the returned view an identifier if tests need it.
// A selectable row with a name and a count, and optionally something under them (modifier keys, a note).
// A filter or a group in a list on the left of a page.
+ (NSView *)countRowWithTitle:(NSString *)title count:(NSUInteger)count detail:(nullable NSView *)detail detailSpacing:(CGFloat)spacing insets:(NSEdgeInsets)insets
                   boldTitle:(BOOL)boldTitle selected:(BOOL)selected onClick:(void (^)(void))onClick;

+ (NSView *)selectableRowWithContent:(NSView *)content insets:(NSEdgeInsets)insets selected:(BOOL)selected onClick:(void (^)(void))onClick;

@end

NS_ASSUME_NONNULL_END
