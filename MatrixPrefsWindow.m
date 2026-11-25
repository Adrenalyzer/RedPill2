// This file is part of Red Pill
// A 3D OpenGL "Matrix" screensaver for Mac OS X
// Copyright (C) 2002, 2003 mathew <meta@pobox.com>
// Copyright (C) 2016 px3 <rr@rdsroot.net>
//
// Red Pill is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
// or visit <URL:http://www.fsf.org/>

#import "MatrixPrefsWindow.h"

// Tags for the controls built in code (high numbers so they can't clash with the nib's)
#define TAG_GLYPH_HEX 9001
#define TAG_TIP_HEX 9002
#define TAG_RGB_BASE 9010     // + 10 * row (0 glyph, 1 tip) + channel (0 R, 1 G, 2 B)
#define TAG_SWATCH_BASE 9031  // + row
#define TAG_PRESET_POPUP 9040
#define TAG_DRIFT_SLIDER 9050
#define TAG_DRIFT_LABEL 9051
#define TAG_SAVE_BASE 9060    // + slot (1 to 3)
#define TAG_CUSTOM_BASE 100   // popup item tags for Custom 1 to 3 are 101 to 103

// The 16 built-in presets: the most vivid full-strength hue for each, plus a lighter tip color.
// (The animation dims colors as they cycle, so these start at maximum vividness.)
typedef struct { const char *name; const char *glyph; const char *tip; } RPPreset;
#define NUM_PRESETS 16
static const RPPreset kPresets[NUM_PRESETS] = {
   {"Classic Green", "00FF00", "66FF66"},
   {"Lime",          "80FF00", "CCFF80"},
   {"Yellow",        "FFFF00", "FFFF99"},
   {"Gold",          "FFCC00", "FFEE88"},
   {"Orange",        "FF9900", "FFD966"},
   {"Ember",         "FF5500", "FFAA80"},
   {"Red",           "FF0000", "FF8080"},
   {"Hot Pink",      "FF0066", "FF99C2"},
   {"Magenta",       "FF00FF", "FF99FF"},
   {"Violet",        "9900FF", "CC99FF"},
   {"Indigo",        "5533FF", "AA99FF"},
   {"Blue",          "0066FF", "80B3FF"},
   {"Sky",           "00AAFF", "99DDFF"},
   {"Cyan",          "00FFFF", "99FFFF"},
   {"Turquoise",     "00FFC8", "99FFE6"},
   {"Emerald",       "00FF80", "99FFCC"}
};

static NSString *const kCustomGlyphKeys[3] = {CUSTOM1_GLYPH_KEY, CUSTOM2_GLYPH_KEY, CUSTOM3_GLYPH_KEY};
static NSString *const kCustomTipKeys[3] = {CUSTOM1_TIP_KEY, CUSTOM2_TIP_KEY, CUSTOM3_TIP_KEY};
static NSString *const kCustomGlyphDefaults[3] = {CUSTOM1_GLYPH_DEFAULT, CUSTOM2_GLYPH_DEFAULT, CUSTOM3_GLYPH_DEFAULT};
static NSString *const kCustomTipDefaults[3] = {CUSTOM1_TIP_DEFAULT, CUSTOM2_TIP_DEFAULT, CUSTOM3_TIP_DEFAULT};

// Make a plain text label for the color panel
static NSTextField *RPLabel(NSString *text, NSRect frame, NSTextAlignment align)
{
   NSTextField *label = [[NSTextField alloc] initWithFrame:frame];
   [label setStringValue:text];
   [label setBezeled:NO];
   [label setDrawsBackground:NO];
   [label setEditable:NO];
   [label setSelectable:NO];
   [label setAlignment:align];
   [label setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
   return label;
}

@interface MatrixPrefsWindow ()
- (ScreenSaverDefaults *)rpDefaults;
- (void)rpBuildPanelIn:(NSWindow *)w;
- (void)rpLoadPanelFromDefaults:(ScreenSaverDefaults *)defaults;
- (void)rpSetRow:(int)row hex:(NSString *)hex;
- (NSString *)rpHexForRow:(int)row;
- (void)rpSyncPopup;
@end

@implementation MatrixPrefsWindow

// The saver's stored settings (nil if we can't tell what they're called)
- (ScreenSaverDefaults *)rpDefaults
{
   NSString *identifier = [[NSBundle bundleForClass:[self class]] bundleIdentifier];
   if (identifier == nil) {
      return nil;
   }
   return [ScreenSaverDefaults defaultsForModuleWithName:identifier];
}

// Build the preset / color / drift panel along the top of the window, once
- (void)rpBuildPanelIn:(NSWindow *)w
{
   rpContent = [w contentView];
   CGFloat H = [rpContent frame].size.height;
   CGFloat W = [rpContent frame].size.width;
   [w setContentSize:NSMakeSize(W, H + 180.0)];

   // Preset menu: 16 built-in, then three user slots
   [rpContent addSubview:RPLabel(@"Preset:", NSMakeRect(17, H + 152, 62, 17), NSTextAlignmentLeft)];
   NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(82, H + 147, 230, 26) pullsDown:NO];
   for (int i = 0; i < NUM_PRESETS; i++) {
      [popup addItemWithTitle:@(kPresets[i].name)];
      [[popup lastItem] setTag:i];
   }
   [[popup menu] addItem:[NSMenuItem separatorItem]];
   for (int n = 1; n <= 3; n++) {
      [popup addItemWithTitle:[NSString stringWithFormat:@"Custom %d", n]];
      [[popup lastItem] setTag:TAG_CUSTOM_BASE + n];
   }
   [popup setTag:TAG_PRESET_POPUP];
   [popup setTarget:self];
   [popup setAction:@selector(presetChanged:)];
   [rpContent addSubview:popup];

   // Column headings over the RGB sliders
   NSArray *channelNames = @[@"Red", @"Green", @"Blue"];
   for (int k = 0; k < 3; k++) {
      [rpContent addSubview:RPLabel(channelNames[k], NSMakeRect(172 + 88 * k, H + 128, 84, 14), NSTextAlignmentCenter)];
   }

   // Two color rows: glyph color and tip color, each with hex box, swatch and R/G/B sliders
   NSArray *rowNames = @[@"Glyph", @"Tip"];
   for (int row = 0; row < 2; row++) {
      CGFloat y = H + 104 - 28 * row;
      [rpContent addSubview:RPLabel(rowNames[row], NSMakeRect(17, y + 4, 62, 17), NSTextAlignmentLeft)];
      NSTextField *hex = [[NSTextField alloc] initWithFrame:NSMakeRect(82, y, 64, 22)];
      [hex setTag:TAG_GLYPH_HEX + row];
      [hex setTarget:self];
      [hex setAction:@selector(hexEdited:)];
      [hex setPlaceholderString:@"RRGGBB"];
      [rpContent addSubview:hex];
      NSTextField *swatch = [[NSTextField alloc] initWithFrame:NSMakeRect(150, y + 2, 18, 18)];
      [swatch setTag:TAG_SWATCH_BASE + row];
      [swatch setEditable:NO];
      [swatch setSelectable:NO];
      [swatch setBezeled:NO];
      [swatch setBordered:NO];
      [swatch setDrawsBackground:YES];
      [rpContent addSubview:swatch];
      for (int k = 0; k < 3; k++) {
         NSSlider *slider = [[NSSlider alloc] initWithFrame:NSMakeRect(172 + 88 * k, y + 1, 84, 21)];
         [slider setMinValue:0];
         [slider setMaxValue:255];
         [slider setContinuous:YES];
         [slider setTag:TAG_RGB_BASE + 10 * row + k];
         [slider setToolTip:channelNames[k]];
         [slider setTarget:self];
         [slider setAction:@selector(rgbSlid:)];
         [rpContent addSubview:slider];
      }
   }

   // Store the current glyph + tip colors into one of three custom slots
   [rpContent addSubview:RPLabel(@"Store as:", NSMakeRect(17, H + 45, 62, 17), NSTextAlignmentLeft)];
   for (int n = 1; n <= 3; n++) {
      NSButton *button = [[NSButton alloc] initWithFrame:NSMakeRect(82 + 94 * (n - 1), H + 40, 90, 26)];
      [button setTitle:[NSString stringWithFormat:@"Custom %d", n]];
      [button setBezelStyle:NSBezelStyleRounded];
      [button setTag:TAG_SAVE_BASE + n];
      [button setTarget:self];
      [button setAction:@selector(saveCustom:)];
      [rpContent addSubview:button];
   }

   // Hue drift: how far (in degrees) each strip's hue may wander from the chosen color
   [rpContent addSubview:RPLabel(@"Hue drift:", NSMakeRect(17, H + 12, 62, 17), NSTextAlignmentLeft)];
   NSSlider *drift = [[NSSlider alloc] initWithFrame:NSMakeRect(82, H + 9, 200, 21)];
   [drift setMinValue:0];
   [drift setMaxValue:30];
   [drift setContinuous:YES];
   [drift setTag:TAG_DRIFT_SLIDER];
   [drift setToolTip:@"0 = every strip exactly the chosen color; higher = more variety"];
   [drift setTarget:self];
   [drift setAction:@selector(driftSlid:)];
   [rpContent addSubview:drift];
   NSTextField *driftLabel = RPLabel(@"", NSMakeRect(290, H + 12, 60, 17), NSTextAlignmentLeft);
   [driftLabel setTag:TAG_DRIFT_LABEL];
   [rpContent addSubview:driftLabel];
}

// Fill the color panel from the saved settings
- (void)rpLoadPanelFromDefaults:(ScreenSaverDefaults *)defaults
{
   NSString *glyph = [defaults stringForKey:GLYPHCOLOR_KEY];
   NSString *tip = [defaults stringForKey:TIPCOLOR_KEY];
   [self rpSetRow:0 hex:(glyph != nil ? glyph : GLYPHCOLOR_DEFAULT)];
   [self rpSetRow:1 hex:(tip != nil ? tip : TIPCOLOR_DEFAULT)];
   NSSlider *drift = [rpContent viewWithTag:TAG_DRIFT_SLIDER];
   [drift setFloatValue:[defaults floatForKey:DRIFT_KEY]];
   [self driftSlid:drift];
   [self rpSyncPopup];
}

// Show a hex color in a row's text box, swatch and sliders
- (void)rpSetRow:(int)row hex:(NSString *)hex
{
   float r, g, b;
   if (!RPParseHexColor(hex, &r, &g, &b)) {
      return;
   }
   NSTextField *field = [rpContent viewWithTag:TAG_GLYPH_HEX + row];
   [field setStringValue:[NSString stringWithFormat:@"%02X%02X%02X",
      (int)lroundf(r * 255.0f), (int)lroundf(g * 255.0f), (int)lroundf(b * 255.0f)]];
   NSTextField *swatch = [rpContent viewWithTag:TAG_SWATCH_BASE + row];
   [swatch setBackgroundColor:[NSColor colorWithCalibratedRed:r green:g blue:b alpha:1.0]];
   float values[3] = {r, g, b};
   for (int k = 0; k < 3; k++) {
      NSSlider *slider = [rpContent viewWithTag:TAG_RGB_BASE + 10 * row + k];
      [slider setFloatValue:values[k] * 255.0f];
   }
}

// The hex color currently set by a row's sliders, e.g. "FF9900"
- (NSString *)rpHexForRow:(int)row
{
   int v[3];
   for (int k = 0; k < 3; k++) {
      NSSlider *slider = [rpContent viewWithTag:TAG_RGB_BASE + 10 * row + k];
      v[k] = (int)lround([slider doubleValue]);
   }
   return [NSString stringWithFormat:@"%02X%02X%02X", v[0], v[1], v[2]];
}

// Make the preset menu show whichever preset matches the current colors, or nothing if none does
- (void)rpSyncPopup
{
   NSPopUpButton *popup = [rpContent viewWithTag:TAG_PRESET_POPUP];
   NSString *glyph = [self rpHexForRow:0];
   NSString *tip = [self rpHexForRow:1];
   for (int i = 0; i < NUM_PRESETS; i++) {
      if ([glyph caseInsensitiveCompare:@(kPresets[i].glyph)] == NSOrderedSame &&
          [tip caseInsensitiveCompare:@(kPresets[i].tip)] == NSOrderedSame) {
         [popup selectItemWithTag:i];
         return;
      }
   }
   ScreenSaverDefaults *defaults = [self rpDefaults];
   for (int n = 0; n < 3; n++) {
      NSString *cg = [defaults stringForKey:kCustomGlyphKeys[n]];
      NSString *ct = [defaults stringForKey:kCustomTipKeys[n]];
      if (cg != nil && ct != nil &&
          [glyph caseInsensitiveCompare:cg] == NSOrderedSame && [tip caseInsensitiveCompare:ct] == NSOrderedSame) {
         [popup selectItemWithTag:TAG_CUSTOM_BASE + n + 1];
         return;
      }
   }
   [popup selectItem:nil];
}

// A preset (built-in or custom) was chosen from the menu
- (void)presetChanged:(id)sender
{
   NSInteger t = [[(NSPopUpButton *)sender selectedItem] tag];
   NSString *glyph = nil, *tip = nil;
   if (t >= 0 && t < NUM_PRESETS) {
      glyph = @(kPresets[t].glyph);
      tip = @(kPresets[t].tip);
   } else if (t > TAG_CUSTOM_BASE && t <= TAG_CUSTOM_BASE + 3) {
      int n = (int)(t - TAG_CUSTOM_BASE - 1);
      ScreenSaverDefaults *defaults = [self rpDefaults];
      glyph = [defaults stringForKey:kCustomGlyphKeys[n]];
      tip = [defaults stringForKey:kCustomTipKeys[n]];
      if (glyph == nil) glyph = kCustomGlyphDefaults[n];
      if (tip == nil) tip = kCustomTipDefaults[n];
   }
   if (glyph != nil && tip != nil) {
      [self rpSetRow:0 hex:glyph];
      [self rpSetRow:1 hex:tip];
   }
}

// A hex box was edited: accept it if valid, otherwise put back what the sliders say
- (void)hexEdited:(id)sender
{
   int row = (int)([sender tag] - TAG_GLYPH_HEX);
   NSString *text = [[sender stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
   float r, g, b;
   if (RPParseHexColor(text, &r, &g, &b)) {
      [self rpSetRow:row hex:text];
   } else {
      NSBeep();
      [self rpSetRow:row hex:[self rpHexForRow:row]];
   }
   [self rpSyncPopup];
}

// An RGB slider moved: update that row's hex box and swatch
- (void)rgbSlid:(id)sender
{
   int row = (int)(([sender tag] - TAG_RGB_BASE) / 10);
   [self rpSetRow:row hex:[self rpHexForRow:row]];
   [self rpSyncPopup];
}

- (void)driftSlid:(id)sender
{
   NSTextField *label = [rpContent viewWithTag:TAG_DRIFT_LABEL];
   [label setStringValue:[NSString stringWithFormat:@"%d\u00B0", (int)lround([sender doubleValue])]];
}

// Store the current glyph + tip colors in Custom 1, 2 or 3
- (void)saveCustom:(id)sender
{
   int n = (int)([sender tag] - TAG_SAVE_BASE) - 1;
   if (n < 0 || n > 2) {
      return;
   }
   ScreenSaverDefaults *defaults = [self rpDefaults];
   if (defaults == nil) {
      return;
   }
   [defaults setObject:[self rpHexForRow:0] forKey:kCustomGlyphKeys[n]];
   [defaults setObject:[self rpHexForRow:1] forKey:kCustomTipKeys[n]];
   [defaults synchronize];
   NSPopUpButton *popup = [rpContent viewWithTag:TAG_PRESET_POPUP];
   [popup selectItemWithTag:TAG_CUSTOM_BASE + n + 1];
}

- (NSWindow *)window
{
   // Initialize parent
   NSWindow *w = [super window];
   // Work out what our defaults are called
   NSString *identifier = [[NSBundle bundleForClass:[self class]] bundleIdentifier];
   if(identifier == nil) {
      LogError("window", "Trying to load preferences but identifier is nil.");
      return w;
   }  
   // Load defaults
   ScreenSaverDefaults *defaults = [ScreenSaverDefaults defaultsForModuleWithName:identifier];
   // Initialize the UI elements
   [strips setFloatValue:[defaults floatForKey:STRIPS_KEY]];
   [velocity setFloatValue:[defaults floatForKey:VELOCITY_KEY]];
   [depth setFloatValue:[defaults floatForKey:DEPTH_KEY]];
   [cycling setFloatValue:[defaults floatForKey:CYCLING_KEY]];
   [falling setFloatValue:[defaults floatForKey:FALLING_KEY]];
   [cursor setFloatValue:[defaults floatForKey:CURSOR_KEY]];
   [fog setFloatValue:[defaults floatForKey:FOG_KEY]];
   [topstart setState:[defaults boolForKey:TOPSTART_KEY]];
   [mainonly setState:[defaults boolForKey:MAINONLY_KEY]];
   // Build the color panel (once), then fill it from the saved settings
   if (rpContent == nil) {
      [self rpBuildPanelIn:w];
   }
   [self rpLoadPanelFromDefaults:defaults];
   // Find out version from bundle
   NSBundle *bundle = [NSBundle bundleForClass:[self class]];
   NSMutableString *versionString = [[NSMutableString alloc]
      initWithString:[bundle infoDictionary][@"CFBundleShortVersionString"]];
   [version setStringValue:versionString];
   [spoon setState:FALSE];
   // Hide spoon mode most of the time
   if ((random() % 5) != 3) {
      [spoon setTransparent:TRUE];
   } else {
      [spoon setTransparent:FALSE];
   }
   return w;
}

// Reset the values of the sliders to their defaults
- (IBAction)reset:(id)sender
{
   [strips setFloatValue:[STRIPS_DEFAULT floatValue]];
   [velocity setFloatValue:[VELOCITY_DEFAULT floatValue]];
   [depth setFloatValue:[DEPTH_DEFAULT floatValue]];
   [cycling setFloatValue:[CYCLING_DEFAULT floatValue]];
   [falling setFloatValue:[FALLING_DEFAULT floatValue]];
   [cursor setFloatValue:[CURSOR_DEFAULT floatValue]];
   [fog setFloatValue:[FOG_DEFAULT floatValue]];
   [topstart setState:TOPSTART_DEFAULT_BOOLEAN];
   [mainonly setState:MAINONLY_DEFAULT_BOOLEAN];
   [self rpSetRow:0 hex:GLYPHCOLOR_DEFAULT];
   [self rpSetRow:1 hex:TIPCOLOR_DEFAULT];
   NSSlider *drift = [rpContent viewWithTag:TAG_DRIFT_SLIDER];
   [drift setFloatValue:[DRIFT_DEFAULT floatValue]];
   [self driftSlid:drift];
   [self rpSyncPopup];
}

// The About button takes them to a web site
- (IBAction)about:(id)sender
{
   [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://wwm4u.de/redpill"]];
}

- (IBAction)cancel:(id)sender
{
   [NSApp endSheet:[self window]];
}

- (IBAction)spoonclick:(id)sender
{
   [spoon setTransparent:FALSE];
}
   
- (IBAction)ok:(id)sender
{
   // Work out what our defaults are called
   NSString *identifier = [[NSBundle bundleForClass:[self class]] bundleIdentifier];
   if(identifier == nil) {
      LogError("ok", "Trying to save preferences but identifier is nil.");
      [NSApp endSheet:[self window]];
      return;
   }
   // Check both colors first; if either isn't valid hex, tell the user and leave the sheet open
   float hr, hg, hb;
   NSString *glyphText = [[(NSTextField *)[rpContent viewWithTag:TAG_GLYPH_HEX] stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
   NSString *tipText = [[(NSTextField *)[rpContent viewWithTag:TAG_TIP_HEX] stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
   if (!RPParseHexColor(glyphText, &hr, &hg, &hb) || !RPParseHexColor(tipText, &hr, &hg, &hb)) {
      NSAlert *badHex = [[NSAlert alloc] init];
      badHex.messageText = @"Invalid color";
      badHex.informativeText = @"Enter hex colors such as 00FF00 (green) or FF9900 (orange).";
      [badHex runModal];
      return;
   }
   if ([glyphText hasPrefix:@"#"]) {
      glyphText = [glyphText substringFromIndex:1];
   }
   if ([tipText hasPrefix:@"#"]) {
      tipText = [tipText substringFromIndex:1];
   }
   // Load defaults
   ScreenSaverDefaults *defaults = [ScreenSaverDefaults defaultsForModuleWithName:identifier];
   [defaults setObject:[glyphText uppercaseString] forKey:GLYPHCOLOR_KEY];
   [defaults setObject:[tipText uppercaseString] forKey:TIPCOLOR_KEY];
   [defaults setFloat:(float)[(NSSlider *)[rpContent viewWithTag:TAG_DRIFT_SLIDER] doubleValue] forKey:DRIFT_KEY];
   // Set values based on new positions and states of UI elements
   [defaults setFloat:[strips floatValue] forKey:STRIPS_KEY];
   [defaults setFloat:[velocity floatValue] forKey:VELOCITY_KEY];
   [defaults setFloat:[depth floatValue] forKey:DEPTH_KEY];
   [defaults setFloat:[cycling floatValue] forKey:CYCLING_KEY];
   [defaults setFloat:[falling floatValue] forKey:FALLING_KEY];
   [defaults setFloat:[cursor floatValue] forKey:CURSOR_KEY];
   [defaults setFloat:[fog floatValue] forKey:FOG_KEY];
   [defaults setBool:[topstart state] forKey:TOPSTART_KEY];
   [defaults setBool:[mainonly state] forKey:MAINONLY_KEY];
   // Plug web site if user selects spoon mode
   if ([spoon state] == TRUE) {
      NSAlert *alert = [[NSAlert alloc] init];
      alert.messageText = @"Realize";
      alert.informativeText = @"There is no spoon.";
      [alert runModal];
      [self about:sender];
   }
   // Update to disk
   [defaults synchronize];

   // Tell the main scrensaver loop to reload the preferences from us
   [[NSNotificationCenter defaultCenter] postNotificationName:PREFS_NOTIFICATION object:nil];
   
   [NSApp endSheet:[self window]];
}
@end
