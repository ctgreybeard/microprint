//
//  TFPBasicPreparationPreprocessor.m
//  MicroPrint
//
//  Created by Tomas Franzén on Mon 2015-06-22.
//

#import "TFPBasicPreparationPreprocessor.h"
#import "TFPGCode.h"
#import "Extras.h"
#import "TFPGCodeHelpers.h"


@implementation TFPBasicPreparationPreprocessor


- (TFPGCodeProgram*)processUsingParameters:(TFPPrintParameters*)parameters {
	NSArray *preamble =
	@[
	  [TFPGCode codeForSettingFanSpeed:parameters.filament.fanSpeed],
	  [TFPGCode codeForHeaterTemperature:parameters.idealTemperature waitUntilDone:NO],
	  
	  [TFPGCode absoluteModeCode],
	  //[TFPGCode turnOnMotorsCode],
	  [TFPGCode moveWithPosition:[TFP3DVector zVector:5] withRawFeedRate:2900],
	  [TFPGCode moveHomeCode],
	  //[TFPGCode turnOffMotorsCode],
	  [TFPGCode codeForHeaterTemperature:parameters.idealTemperature waitUntilDone:YES],
	  //[TFPGCode waitCodeWithDuration:10],
	  
	  //[TFPGCode turnOnMotorsCode],
	  [TFPGCode relativeModeCode],
	  [TFPGCode codeForExtrusion:7.5 withRawFeedRate:2000],
	  [TFPGCode resetExtrusionCode],
	  [TFPGCode absoluteModeCode],
	  [TFPGCode codeForSettingFeedRate:2400 raw:YES],
	];
	
	double raiseHeight;
	if(parameters.maxZ >= 110) {
		raiseHeight = 0;
	}else if(parameters.maxZ >= 25) {
		raiseHeight = 3;
	}else{
		raiseHeight = 25 + 3 - parameters.maxZ;
	}
	
	TFP3DVector *backPosition = (parameters.maxZ > 60) ? [TFP3DVector xyVectorWithX:90 y:84] : [TFP3DVector xyVectorWithX:95 y:95];
	
	NSArray *postamble =
	@[
	  [TFPGCode codeWithComment:@"POSTAMBLE"],
	  
	  [TFPGCode relativeModeCode],
	  [TFPGCode codeForExtrusion:-1 withRawFeedRate:2000],
	  [TFPGCode moveWithPosition:[TFP3DVector xyVectorWithX:5 y:5] withRawFeedRate:2000],
	  [TFPGCode codeForExtrusion:-8 withRawFeedRate:2000],
	  [TFPGCode codeForTurningOffHeater],

	  [TFPGCode moveWithPosition:[TFP3DVector zVector:raiseHeight] withRawFeedRate:2900],
	  [TFPGCode absoluteModeCode],
	  [TFPGCode moveWithPosition:backPosition withRawFeedRate:-1],
	  
	  [TFPGCode turnOffFanCode],
	  [TFPGCode turnOffMotorsCode],
	  [TFPGCode codeWithComment:@"END"],
	  ];
	
	
	BOOL(^setsTemperatureOrFanSpeed)(TFPGCode*) = ^BOOL(TFPGCode *line) {
		NSInteger M = [line valueForField:'M' fallback:-1];
		return (M == 104 || M == 106 || M == 107 || M == 109);
	};
	
	NSMutableArray *output = [NSMutableArray new];
	[output addObjectsFromArray:preamble];
	[output addObjectsFromArray:[self.program.lines tf_rejectWithBlock:setsTemperatureOrFanSpeed]];
	[output addObjectsFromArray:postamble];
	
	return [[TFPGCodeProgram alloc] initWithLines:output];
}


@end