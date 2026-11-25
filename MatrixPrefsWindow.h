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

#import <Cocoa/Cocoa.h>
#import <AppKit/AppKit.h>
#import <ScreenSaver/ScreenSaver.h>

#import "GLUtils.h"

// Strings to use when saving the preferences
#define STRIPS_KEY @"strips"
#define VELOCITY_KEY @"velocity"
#define DEPTH_KEY @"depth"
#define CYCLING_KEY @"cycling"
#define FALLING_KEY @"falling"
#define CURSOR_KEY @"cursor"
#define FOG_KEY @"fog"
#define TOPSTART_KEY @"topstart"
#define MAINONLY_KEY @"mainonly"
#define SPOON_KEY @"spoon"
#define GLYPHCOLOR_KEY @"glyphcolor"

// Default values for same
#define STRIPS_DEFAULT @"50"
#define VELOCITY_DEFAULT @"40"
#define DEPTH_DEFAULT @"200"
#define CYCLING_DEFAULT @"5"
#define FALLING_DEFAULT @"2"
#define CURSOR_DEFAULT @"10"
#define FOG_DEFAULT @"15"
#define TOPSTART_DEFAULT @"YES"
#define TOPSTART_DEFAULT_BOOLEAN TRUE
#define MAINONLY_DEFAULT @"NO"
#define MAINONLY_DEFAULT_BOOLEAN FALSE
#define GLYPHCOLOR_DEFAULT @"00FF00"
#define SPOON_DEFAULT @"NO"
#define SPOON_DEFAULT_BOOLEAN FALSE

// Notification to send the main object
#define PREFS_NOTIFICATION @"RedPillOrangePreferencesChanged"

// Parse a hex color like "FF9900", "#ff9900" or "f90" into 0.0-1.0 components. Returns NO if invalid.
static inline BOOL RPParseHexColor(NSString *s, float *r, float *g, float *b)
{
   if (s == nil) {
      return NO;
   }
   s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
   if ([s hasPrefix:@"#"]) {
      s = [s substringFromIndex:1];
   }
   NSCharacterSet *hexDigits = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];
   if ([[s stringByTrimmingCharactersInSet:hexDigits] length] != 0) {
      return NO;
   }
   if ([s length] == 3) {
      unichar c0 = [s characterAtIndex:0], c1 = [s characterAtIndex:1], c2 = [s characterAtIndex:2];
      s = [NSString stringWithFormat:@"%C%C%C%C%C%C", c0, c0, c1, c1, c2, c2];
   }
   if ([s length] != 6) {
      return NO;
   }
   unsigned int v = 0;
   if (![[NSScanner scannerWithString:s] scanHexInt:&v]) {
      return NO;
   }
   *r = ((v >> 16) & 0xFF) / 255.0f;
   *g = ((v >> 8) & 0xFF) / 255.0f;
   *b = (v & 0xFF) / 255.0f;
   return YES;
}

@interface MatrixPrefsWindow :  NSWindowController
{
   IBOutlet NSSlider *strips;
   IBOutlet NSSlider *velocity;
   IBOutlet NSSlider *depth;
   IBOutlet NSSlider *cycling;
   IBOutlet NSSlider *falling;
   IBOutlet NSSlider *cursor;
   IBOutlet NSSlider *fog;
   IBOutlet NSButton *topstart;
   IBOutlet NSButton *mainonly;
   IBOutlet NSButton *spoon;
   IBOutlet NSTextField *version;
   // Created in code (not in the nib)
   NSTextField *hexField;
}

- (IBAction)cancel:(id)sender;
- (IBAction)ok:(id)sender;
- (IBAction)about:(id)sender;
- (IBAction)reset:(id)sender;
- (IBAction)spoonclick:(id)sender;
@end
