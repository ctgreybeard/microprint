//
//  TFPSlicerProfile.m
//  microprint
//
//  Created by William Waggoner on 9/13/15.
//  Copyright © 2015 Tomas Franzén. All rights reserved.
//

#import "TFPSlicerProfile.h"

static NSString *const CURA_COMMENT = @"CURA_PROFILE_STRING:";
static NSString *const SLIC3R_COMMENT = @" generated by Slic3r";
static NSString *const PROFILE_REGEX = @"^\\s*(\\S+[\\S ]*?)\\s*=\\s*(\\S.*)$";

typedef NSMutableDictionary<NSString*, NSString*> ProfileDict;

@interface TFPSlicerProfile ()
@property ProfileDict *values;
@end

@implementation TFPSlicerProfile

+ (NSSet *)keyPathsForValuesAffectingValueForKey: (NSString *)key {
    NSDictionary<NSString*,NSArray*> *keys =@{
        @"Layer Height":    @[@"layer_height"],
        @"Wall Thickness":  @[@"wall_thickness", @"perimeters", @"external perimeters extrusion width"],
        @"Fill Density":    @[@"fill_density"],
        @"Bed Adhesion":    @[@"platform_adhesion", @"raft_layers", @"brim_width"],
        @"Support":         @[@"support", @"support_material"],
        @"Print Speed":     @[@"print_speed", @"perimeter_speed"]
        };

    return keys[key].tf_set;
}

- (instancetype)initFromLines: (NSArray<TFPGCode *> *)lines {
    if (self = [super init]) {
        self.values = [NSMutableDictionary dictionaryWithCapacity:200];

        if([self hasCuraProfile: lines]) {
            self.profileType = CuraProfile;
            [self loadCuraProfile:lines];

        } else if ([self hasSlic3rProfile: lines]) {
            self.profileType = Slic3rProfile;
            [self loadSlic3rProfile:lines];

        } else { // No profile we know about ...
            self.values = nil;  // Release the empty dictionary, sorry for the trouble ...
            self = nil;
        }
    }

    return self;
}

// Defined in TFPPrintSettingViewController
// @[@"Layer Height", @"Wall Thickness", @"Fill Density", @"Bed Adhesion", @"Support", @"Print Speed"]
// The keys used here are defined in TFPPrintSettingViewController. Each proifle type needs to
// retrun appropriate values based on the supplied profile dictionary. Cura is a one-to-one
// definition. Others not so much, it depends on the slicer.

- (id)valueForUndefinedKey:(NSString *)key {
    NSString *retVal= [self.values valueForKey:key];
    if (!retVal) {
        switch (self.profileType) {
            case CuraProfile:
                if ([key isEqualToString:@"Layer Height"]) {
                    retVal = self.values[@"layer_height"];

                } else if ([key isEqualToString:@"Wall Thickness"]) {
                    retVal = self.values[@"wall_thickness"];

                } else if ([key isEqualToString:@"Fill Density"]) {
                    retVal = self.values[@"fill_density"];

                } else if ([key isEqualToString:@"Bed Adhesion"]) {
                    retVal = self.values[@"platform_adhesion"];

                } else if ([key isEqualToString:@"Support"]) {
                    retVal = self.values[@"support"];

                } else if ([key isEqualToString:@"Print Speed"]) {
                    retVal = self.values[@"print_speed"];

                }

                break;

            case Slic3rProfile:
                // Only check for the things we need to translate ...
                if ([key isEqualToString:@"Layer Height"]) {
                    retVal = self.values[@"layer_height"];

                } else if ([key isEqualToString: @"Wall Thickness"]) {
                    retVal = @(self.values[@"perimeters"].doubleValue *
                                self.values[@"external perimeters extrusion width"].doubleValue).stringValue;

                } else if ([key isEqualToString:@"Fill Density"]) {
                    retVal = self.values[@"fill_density"];

                } else if ([key isEqualToString: @"Bed Adhesion"]) {
                    int raftLayers = self.values[@"raft_layers"].intValue;
                    int brimWidth = self.values[@"brim_width"].intValue;

                    if (raftLayers) {
                        retVal = [NSString stringWithFormat:@"Raft(%d)", raftLayers];
                    }

                    if (brimWidth) {
                        NSString *brimString = [NSString stringWithFormat:@"Brim(%d)", brimWidth];

                        if (!retVal) {
                            retVal = brimString;

                        } else {
                            retVal = [retVal stringByAppendingString:[@"/" stringByAppendingString:brimString]];
                        }
                    }

                    if (!retVal) {retVal = @"None";}

                } else if ([key isEqualToString:@"Support"]) {
                    retVal = self.values[@"support_material"];

                } else if ([key isEqualToString: @"Print Speed"]) {
                    retVal = self.values[@"perimeter_speed"];

                }
                break;

        }
    }

    return retVal;
}

- (void)setValue:(NSString *)value forUndefinedKey:(NSString *)key {
    [self willChangeValueForKey:key];

    [self.values setValue:value forKey:key];

    [self didChangeValueForKey:key];
}

- (void)setObject:(NSString *)object forKeyedSubscript:(NSString *)key {
    return [self.values setValue:object forKey:key];
}

- (NSString *)objectForKeyedSubscript:(NSString *)key {
    return [self.values objectForKey:key];
}

- (BOOL)hasCuraProfile:(NSArray<TFPGCode *> *)lines {
    return [self curaProfileComment:lines] != NULL;
}

- (BOOL)hasSlic3rProfile:(NSArray<TFPGCode *> *)lines {
    return lines.count > 0 && [lines[0].comment hasPrefix:SLIC3R_COMMENT];
}

// Look for the Cura profile comment and return the profile string if found. The string is a zipped and base64 encoded
// representation of the profile key-value pairs.
- (NSString *)curaProfileComment:(NSArray<TFPGCode *> *)lines {
    __block NSString *comment;

    [lines enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(TFPGCode *code, NSUInteger idx, BOOL * _Nonnull stop) {
        if([code.comment hasPrefix:CURA_COMMENT]) {
            comment = [code.comment substringFromIndex:CURA_COMMENT.length];
            *stop = YES;
        }
    }];

    return comment;
}

- (BOOL)loadCuraProfile:(NSArray<TFPGCode *> *)lines {
    NSString *base64 = [self curaProfileComment:lines];

    if(base64) {

        NSData *deflatedData = [[NSData alloc] initWithBase64EncodedString:base64 options:NSDataBase64DecodingIgnoreUnknownCharacters];
        NSData *rawData = [deflatedData tf_dataByDecodingDeflate];

        if(rawData) {
            /* 
             The profile is one string in two sections. The sections are separated by \x0C and each profile item "key=value" is
             terminated with \x08. We don't care about the sections so we first turn the \x0C into \x08 then split the result
             with \x08 ...
             */
            NSArray *pairs = [[[[NSString alloc] initWithData:rawData encoding:NSUTF8StringEncoding]
                               stringByReplacingOccurrencesOfString:@"\x0C" withString:@"\x08"]
                              componentsSeparatedByString:@"\x08"];

            for(NSString *pairString in pairs) {
                NSUInteger separator = [pairString rangeOfString:@"="].location;
                if(separator == NSNotFound) {
                    continue;
                }

                NSString *key = [pairString substringWithRange:NSMakeRange(0, separator)];
                NSString *value = [pairString substringWithRange:NSMakeRange(separator+1, pairString.length - separator - 1)];
                [self.values setValue:value forKey:key];
            }
        }
    }

    return self.values.count > 0;
}

/*
 The Slic3r profile is embedded within the gcode as comment lines. The general format is "; key = value"
 */
- (BOOL)loadSlic3rProfile:(NSArray<TFPGCode *> *)lines {
    if(lines.count > 0) {
        TFPGCode *firstLine = lines[0];

        if(![firstLine hasFields] &&
             firstLine.comment &&
            [firstLine.comment hasPrefix:SLIC3R_COMMENT]) {   // Check to be sure it's a Slic3r profile

            NSError *error = NULL;
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:PROFILE_REGEX options:0 error:&error];

            if(error) {
                NSLog(@"Regex error: %@:%@", error.localizedFailureReason, error.localizedDescription);
                abort();
            }

            for(TFPGCode *line in lines) {
                if(line.comment){
                    NSArray<NSTextCheckingResult *> *matches = [regex matchesInString:line.comment options:0 range:NSMakeRange(0, line.comment.length)];

                    if(matches.count>0) {
                        NSString *key = [line.comment substringWithRange:[matches[0] rangeAtIndex:1]];
                        NSString *val = [line.comment substringWithRange:[matches[0] rangeAtIndex:2]];

                        [self willChangeValueForKey:key];
                        [self.values setValue:val forKey:key];
                        [self didChangeValueForKey:key];
                    }
                }
            }
        }
    }

    return self.values.count > 0;
}

// Return the formatted value for the attribute key. Keys are translated from the TFPPrinterSettingsViewController
// titles to the appropriate slicer names (sometimes with calculations)

// @[@"Layer Height", @"Wall Thickness", @"Fill Density", @"Bed Adhesion", @"Support", @"Print Speed"]

- (NSString *)formattedValueForKey:(NSString *)key {
    NSNumberFormatter *mmFormatter = [NSNumberFormatter new];
    mmFormatter.minimumIntegerDigits = 1;
    mmFormatter.minimumFractionDigits = 2;
    mmFormatter.maximumFractionDigits = 2;
    mmFormatter.positiveSuffix = @" mm";
    mmFormatter.negativeSuffix = @" mm";

    NSNumberFormatter *mmpsFormatter = [mmFormatter copy];
    mmpsFormatter.positiveSuffix = @" mm/s";
    mmpsFormatter.negativeSuffix = @" mm/s";

    NSString *value = [self valueForUndefinedKey:key];

    double doubleValue = value.doubleValue;

    if([key isEqual:@"Layer Height"] || [key isEqual:@"Wall Thickness"]) {
        return [mmFormatter stringFromNumber:@(doubleValue)];

    }else if([key isEqual:@"Print Speed"]) {
        return [mmpsFormatter stringFromNumber:@(doubleValue)];

    }else if([key isEqual:@"Fill Density"]) {
        return [NSString stringWithFormat:@"%d%%", value.intValue]; // Handles values like 20 (Cura) or 20% (Slic3r)

    }else if([key isEqual:@"Support"]) {
        if([value isEqual:@"Touching buildplate"]) {
            return @"Buildplate";

        } else if ([value isEqualToString:@"1"]) {
            return @"Yes";

        } else if ([value isEqualToString:@"0"]) {
            return @"None";

        } else {
            return value;
        }
        
    }else if([key isEqual:@"Bed Adhesion"]) {
        return value;
        
    }else{
        return nil;
    }
}

@end