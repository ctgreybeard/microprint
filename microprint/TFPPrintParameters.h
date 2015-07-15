//
//  TFPPrintParameters.h
//  MicroPrint
//
//  Created by Tomas Franzén on Mon 2015-06-22.
//

@import Foundation;
#import "TFPFilament.h"


typedef struct {
	double common;
	double backLeft;
	double backRight;
	double frontRight;
	double frontLeft;
} TFPBedLevelOffsets;


typedef struct {
	double x;
	double y;
} TFPBacklashValues;


extern NSString *TFPBedLevelOffsetsDescription(TFPBedLevelOffsets offsets);
extern NSString *TFPBacklashValuesDescription(TFPBacklashValues values);


@interface TFPPrintParameters : NSObject
@property (readwrite) NSUInteger bufferSize;
@property (readwrite) BOOL verbose;

@property (readwrite) TFPFilament *filament;
@property (readwrite, nonatomic) double idealTemperature;
@property (readwrite) double maxZ;

@property (readwrite) TFPBedLevelOffsets bedLevelOffsets;
@property (readwrite) TFPBacklashValues backlashValues;
@property (readwrite) double backlashCompensationSpeed;

@property (readwrite) BOOL useWaveBonding;
@property (readwrite) BOOL useBacklashCompensation;
@end