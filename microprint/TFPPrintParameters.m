//
//  TFPPrintParameters.m
//  MicroPrint
//
//  Created by Tomas Franzén on Mon 2015-06-22.
//

#import "TFPPrintParameters.h"


@implementation TFPPrintParameters


- (instancetype)init {
	if(!(self = [super init])) return nil;
	
	self.filament = [TFPFilament defaultFilament];
	self.useWaveBonding = NO;
	self.useBacklashCompensation = YES;
	self.useBasicPreparation = YES;
	
	return self;
}


- (double)idealTemperature {
	if(_idealTemperature < DBL_EPSILON) {
		return self.filament.defaultTemperature;
	}else{
		return _idealTemperature;
	}
}


@end


NSString *TFPBedLevelOffsetsDescription(TFPBedLevelOffsets offsets) {
	return [NSString stringWithFormat:@"{ Z: %.02f, BL: %.02f, BR: %.02f, FR: %.02f, FL: %.02f }",
			offsets.common,
			offsets.backLeft,
			offsets.backRight,
			offsets.frontRight,
			offsets.frontLeft
			];
}


NSString *TFPBacklashValuesDescription(TFPBacklashValues values) {
	return [NSString stringWithFormat:@"{ X: %.02f, Y: %.02f, speed: %.0f }",
			values.x,
			values.y,
			values.speed
			];
}

NSString *TFPMysterySValuesDescription(TFPMysterySValues values) {
    return [NSString stringWithFormat:@"{ BR: %.03f, BL: %.03f, FL: %.03f, FR: %.03f }",
            values.br, values.bl, values.fl, values.fr
            ];
}