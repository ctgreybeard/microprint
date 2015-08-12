//
//  TFPPrinterHelpers.m
//  microprint
//
//  Created by Tomas Franzén on Sun 2015-08-02.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPPrinterHelpers.h"
#import "TFPPrinter+VirtualEEPROM.h"

#import "TFTimer.h"
#import "MAKVONotificationCenter.h"


@implementation TFPPrinter (CommandHelpers)


- (void)fetchBedOffsetsWithCompletionHandler:(void(^)(BOOL success, TFPBedLevelOffsets offsets))completionHandler {
	NSArray *indexes = @[@(VirtualEEPROMIndexBedOffsetBackLeft),
						 @(VirtualEEPROMIndexBedOffsetBackRight),
						 @(VirtualEEPROMIndexBedOffsetFrontRight),
						 @(VirtualEEPROMIndexBedOffsetFrontLeft),
						 @(VirtualEEPROMIndexBedOffsetCommon)];
	
	[self readVirtualEEPROMFloatValuesAtIndexes:indexes completionHandler:^(BOOL success, NSArray *values) {
		TFPBedLevelOffsets offsets = {0};
		
		if(!success) {
			completionHandler(NO, offsets);
		}
		
		offsets.backLeft = [values[0] floatValue];
		offsets.backRight = [values[1] floatValue];
		offsets.frontRight = [values[2] floatValue];
		offsets.frontLeft = [values[3] floatValue];
		offsets.common = [values[4] floatValue];
		
		completionHandler(YES, offsets);
	}];
}


- (void)setBedOffsets:(TFPBedLevelOffsets)offsets completionHandler:(void(^)(BOOL success))completionHandler {
	NSDictionary *EEPROMValues = @{
								   @(VirtualEEPROMIndexBedOffsetBackLeft): @(offsets.backLeft),
								   @(VirtualEEPROMIndexBedOffsetBackRight): @(offsets.backRight),
								   @(VirtualEEPROMIndexBedOffsetFrontRight): @(offsets.frontRight),
								   @(VirtualEEPROMIndexBedOffsetFrontLeft): @(offsets.frontLeft),
								   @(VirtualEEPROMIndexBedOffsetCommon): @(offsets.common),
								   };
	
	
	[self writeVirtualEEPROMFloatValues:EEPROMValues completionHandler:^(BOOL success) {
		if(completionHandler) {
			completionHandler(success);
		}
	}];
}

- (void)fetchMysterySValuesWithCompletionHandler:(void(^)(BOOL success, TFPMysterySValues values))completionHandler {
    NSArray *indexes = @[@(VirtualEEPROMIndexBedCompensationBackLeft),
                         @(VirtualEEPROMIndexBedCompensationBackRight),
                         @(VirtualEEPROMIndexBedCompensationFrontLeft),
                         @(VirtualEEPROMIndexBedCompensationFrontRight)
                         ];

    [self readVirtualEEPROMFloatValuesAtIndexes:indexes completionHandler:^(BOOL success, NSArray *values) {
        TFPMysterySValues mystery = {0};
        if(success) {
            mystery.bl = [values[0] floatValue];
            mystery.br = [values[1] floatValue];
            mystery.fl = [values[2] floatValue];
            mystery.fr = [values[3] floatValue];

            completionHandler(YES, mystery);
        }else{
            completionHandler(NO, mystery);
        }
    }];
}


- (void)fetchBacklashValuesWithCompletionHandler:(void(^)(BOOL success, TFPBacklashValues values))completionHandler {
	NSArray *indexes = @[@(VirtualEEPROMIndexBacklashCompensationX),
						 @(VirtualEEPROMIndexBacklashCompensationY),
						 @(VirtualEEPROMIndexBacklashCompensationSpeed)
						 ];
	
	[self readVirtualEEPROMFloatValuesAtIndexes:indexes completionHandler:^(BOOL success, NSArray *values) {
		TFPBacklashValues backlash = {0};
		if(success) {
			backlash.x = [values[0] floatValue];
			backlash.y = [values[1] floatValue];
			backlash.speed = [values[2] floatValue];
			
			completionHandler(YES, backlash);
		}else{
			completionHandler(NO, backlash);
		}
	}];
}


- (void)setBacklashValues:(TFPBacklashValues)values completionHandler:(void(^)(BOOL success))completionHandler {
	NSDictionary *EEPROMValues = @{
								   @(VirtualEEPROMIndexBacklashCompensationX): @(values.x),
								   @(VirtualEEPROMIndexBacklashCompensationY): @(values.y),
								   @(VirtualEEPROMIndexBacklashCompensationSpeed): @(values.speed),
								   };
	
	[self writeVirtualEEPROMFloatValues:EEPROMValues completionHandler:^(BOOL success) {
		if(completionHandler) {
			completionHandler(success);
		}
	}];
}



- (void)fetchPositionWithCompletionHandler:(void(^)(BOOL success, TFP3DVector *position, NSNumber *E))completionHandler {
	[self sendGCode:[TFPGCode codeForGettingPosition] responseHandler:^(BOOL success, NSDictionary *params) {
		if(success) {
			NSNumber *x = params[@"X"] ? @([params[@"X"] doubleValue]) : nil;
			NSNumber *y = params[@"Y"] ? @([params[@"Y"] doubleValue]) : nil;
			NSNumber *z = params[@"Z"] ? @([params[@"Z"] doubleValue]) : nil;
			NSNumber *e = params[@"E"] ? @([params[@"E"] doubleValue]) : nil;
			
			TFP3DVector *position = [TFP3DVector vectorWithX:x Y:y Z:z];
			completionHandler(YES, position, e);
			
		}else{
			completionHandler(NO, nil, 0);
		}
	}];
}


- (void)fillInOffsetAndBacklashValuesInPrintParameters:(TFPPrintParameters*)params completionHandler:(void(^)(BOOL success))completionHandler {
    [self fetchBedOffsetsWithCompletionHandler:^(BOOL success, TFPBedLevelOffsets offsets) {
        if(!success) {
            completionHandler(NO);
            return;
        }

        params.bedLevelOffsets = offsets;
        [self fetchBacklashValuesWithCompletionHandler:^(BOOL success, TFPBacklashValues values) {
            if(!success) {
                completionHandler(NO);
                return;
            }
            params.backlashValues = values;
            [self fetchMysterySValuesWithCompletionHandler:^(BOOL success, TFPMysterySValues values) {
                if(!success) {
                    completionHandler(NO);
                    return;
                }
                params.mysterySValues = values;
                completionHandler(YES);
            }];
        }];
    }];
}


- (void)setRelativeMode:(BOOL)relative completionHandler:(void(^)(BOOL success))completionHandler {
	if(relative) {
		[self sendGCode:[TFPGCode relativeModeCode] responseHandler:^(BOOL success, NSDictionary *value) {
			if(completionHandler) {
				completionHandler(success);
			}
		}];
	}else{
		[self sendGCode:[TFPGCode absoluteModeCode] responseHandler:^(BOOL success, NSDictionary *value) {
			if(completionHandler) {
				completionHandler(success);
			}
		}];
	}
}


- (void)moveToPosition:(TFP3DVector*)position usingFeedRate:(double)F completionHandler:(void(^)(BOOL success))completionHandler {
	TFPGCode *code = [TFPGCode codeWithString:@"G0"];
	if(position.x) {
		code = [code codeBySettingField:'X' toValue:position.x.doubleValue];
	}
	if(position.y) {
		code = [code codeBySettingField:'Y' toValue:position.y.doubleValue];
	}
	if(position.z) {
		code = [code codeBySettingField:'Z' toValue:position.z.doubleValue];
	}
	if(F >= 0) {
		code = [code codeBySettingField:'F' toValue:F];
	}
	
	[self sendGCode:code responseHandler:^(BOOL success, NSDictionary *value) {
		if(completionHandler) {
			completionHandler(success);
		}
	}];
}


- (void)waitForMoveCompletionWithHandler:(void(^)())completionHandler {
	[self sendGCode:[TFPGCode waitForMoveCompletionCode] responseHandler:^(BOOL success, NSDictionary *value) {
		if(completionHandler) {
			completionHandler();
		}
	}];
}


- (void(^)())setHeaterTemperatureAsynchronously:(double)targetTemperature progressBlock:(void(^)(double currentTemperature))progressBlock completionBlock:(void(^)())completionBlock {
	__weak __typeof__(self) weakSelf = self;
	
	[self sendGCode:[TFPGCode codeForHeaterTemperature:targetTemperature waitUntilDone:NO] responseHandler:nil];
	
	TFTimer *timer = [TFTimer timerWithInterval:0.5 repeating:YES block:^{
		[weakSelf sendGCode:[TFPGCode codeForReadingHeaterTemperature] responseHandler:nil];
	}];
	__weak TFTimer *weakTimer = timer;
	
	void(^cancelBlock)() = [^{
		[timer invalidate];
		[weakSelf sendGCode:[TFPGCode codeForTurningOffHeater] responseHandler:nil];
	} copy];
	
	[self addObserver:timer keyPath:@"heaterTemperature" options:0 block:^(MAKVONotification *notification) {
		if(fabs(weakSelf.heaterTemperature - targetTemperature) < 3) {
			[weakTimer invalidate];
			completionBlock();
		}else{
			progressBlock(weakSelf.heaterTemperature);
		}
	}];
	
	return cancelBlock;
}


- (void)moveStepFromPosition:(TFP3DVector*)from toPosition:(TFP3DVector*)to steps:(NSUInteger)stepCount currentStep:(NSUInteger)step feedRate:(double)feedRate cancelBlock:(BOOL(^)())cancelBlock progressBlock:(void(^)(double fraction, TFP3DVector *position))progressBlock completionBlock:(void(^)())completionBlock {
	TFP3DVector *fullDelta = [to vectorBySubtracting:from];
	TFP3DVector *deltaPerStep = [fullDelta vectorByDividingByScalar:stepCount];
	TFP3DVector *currentDelta = [deltaPerStep vectorByMultiplyingByScalar:step];
	TFP3DVector *absolutePosition = [from vectorByAdding:currentDelta];
	
	[self moveToPosition:absolutePosition usingFeedRate:feedRate completionHandler:^(BOOL success) {
		if(cancelBlock()) {
			return;
		}
		
		progressBlock((double)step/stepCount, absolutePosition);
		
		if(step == stepCount) {
			completionBlock();
		}else{
			[self moveStepFromPosition:from toPosition:to steps:stepCount currentStep:step+1 feedRate:feedRate cancelBlock:cancelBlock progressBlock:progressBlock completionBlock:completionBlock];
		}
	}];

}


- (void(^)())moveAsynchronouslyToPosition:(TFP3DVector*)targetPosition feedRate:(double)feedRate progressBlock:(void(^)(double fraction, TFP3DVector *position))progressBlock completionBlock:(void(^)())completionBlock {
	
	__block BOOL cancelFlag = NO;
	
	[self setRelativeMode:NO completionHandler:nil];
	
	[self fetchPositionWithCompletionHandler:^(BOOL success, TFP3DVector *originPosition, NSNumber *E) {
		TFP3DVector *delta = [targetPosition vectorBySubtracting:originPosition];
		
		TFP3DVector *stepVector = [[delta vectorByDividingBy:[TFP3DVector vectorWithX:@2 Y:@2 Z:@0.1]] absoluteVector];
		NSUInteger numSteps = ceil(MAX(MAX(stepVector.x.integerValue, stepVector.y.integerValue), stepVector.z.integerValue));
		
		if(numSteps > 0) {
			[self moveStepFromPosition:originPosition toPosition:targetPosition steps:numSteps currentStep:0 feedRate:feedRate cancelBlock:^BOOL{
				return cancelFlag;
			} progressBlock:progressBlock completionBlock:^{
				completionBlock();
			}];
		}else{
			dispatch_async(dispatch_get_main_queue(), ^{
				completionBlock();
			});
		}
	}];
	
	return ^{
		cancelFlag = YES;
	};
}



@end