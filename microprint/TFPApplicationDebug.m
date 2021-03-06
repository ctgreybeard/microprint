//
//  TFPApplicationDelegate+TFPApplicationDebug.m
//  microprint
//
//  Created by Tomas Franzén on Mon 2015-08-31.
//  Copyright © 2015 Tomas Franzén. All rights reserved.
//

#import "TFPApplicationDebug.h"
#import "TFPPrinter.h"
#import "TFPPrinterManager.h"
#import "TFPExtras.h"
#import "TFPDryRunPrinter.h"
#import "TFPBedLevelCompensator.h"
#import "TFP3DVector.h"


@interface TFPApplicationDelegate ()
@property TFPPrinterContext *debugContext;
@property (copy) void(^debugCancelBlock)();
@end


@implementation TFPApplicationDelegate (TFPApplicationDebug)


- (IBAction)addDryRunPrinter:(id)sender {
	[[TFPPrinterManager sharedManager] startDryRunMode];
}


- (IBAction)blockMainThreadTest:(id)sender {
	sleep(10);
}


- (IBAction)turnOnHeaterAsync:(id)sender {
	__weak __typeof__(self) weakSelf = self;
	
	TFPPrinter *printer = [TFPPrinterManager sharedManager].printers.firstObject;
	self.debugContext = [printer acquireContextWithOptions:TFPPrinterContextOptionConcurrent queue:nil];
	self.debugCancelBlock = [self.debugContext setHeaterTemperatureAsynchronously:200 progressBlock:^(double currentTemperature) {
		TFLog(@"Temp: %.02f", currentTemperature);
	} completionBlock:^{
		TFLog(@"Heated!");
		weakSelf.debugCancelBlock = nil;
	}];
}


- (IBAction)cancelHeater:(id)sender {
	if(self.debugCancelBlock) {
		self.debugCancelBlock();
		TFLog(@"Cancelled heating");
		self.debugCancelBlock = nil;
	}
}


- (IBAction)turnOffHeater:(id)sender {
	TFPPrinter *printer = [TFPPrinterManager sharedManager].printers.firstObject;
	[printer sendGCode:[TFPGCode codeForTurningOffHeater] responseHandler:nil];
}


- (void)testMoveToPosition:(TFP3DVector*)target {
	TFPPrinter *printer = [TFPPrinterManager sharedManager].printers.firstObject;
	self.debugContext = [printer acquireContextWithOptions:TFPPrinterContextOptionConcurrent queue:nil];
	
	self.debugCancelBlock = [self.debugContext moveAsynchronouslyToPosition:target feedRate:3000 progressBlock:^(double fraction, TFP3DVector *position) {
		NSLog(@"Progress: %d, %@", (int)(fraction*100), position);
	} completionBlock:^{
		NSLog(@"Done!");
	}];
}


- (IBAction)testPosition1:(id)sender {
	TFP3DVector *target = [TFP3DVector vectorWithX:@10 Y:@10 Z:@30];
	[self testMoveToPosition:target];
}


- (IBAction)testPosition2:(id)sender {
	TFP3DVector *target = [TFP3DVector vectorWithX:@85 Y:@85 Z:@10];
	[self testMoveToPosition:target];
}



- (IBAction)cancelMove:(id)sender {
	if(self.debugCancelBlock) {
		self.debugCancelBlock();
		TFLog(@"Cancelled move");
		self.debugCancelBlock = nil;
	}
}


- (IBAction)setDryRunSpeedMultiplier:(id)sender {
	[TFPDryRunPrinter setSpeedMultiplier:[sender tag]];
}


- (IBAction)bedLevelTest:(id)sender {
	TFPPrinter *printer = [TFPPrinterManager sharedManager].printers.firstObject;
	TFPBedLevelCompensator *compensator = [[TFPBedLevelCompensator alloc] initWithBedLevel:printer.bedBaseOffsets];
	
	for(NSUInteger x=9; x<=99; x++) {
		for(NSUInteger y=5; y<=95; y++) {
			double z = [compensator zAdjustmentAtX:x Y:y];
			TFLog(@"SCNVector3Make(%.02f, %.02f, %.03f),", (double)x, (double)y, z);
		}
	}
}


- (IBAction)levelTest:(id)sender {
	TFPPrinter *printer = [TFPPrinterManager sharedManager].printers.firstObject;
	TFLog(@"Base level: %@", TFPBedLevelOffsetsDescription(printer.bedBaseOffsets));
	TFLog(@"Bed level offset: %@", TFPBedLevelOffsetsDescription(printer.bedLevelOffsets));
}


- (void)runSpeedTestFromPosition:(TFP3DVector*)pos1 toPosition:(TFP3DVector*)pos2 feedrate:(double)feedrate repeatCount:(NSUInteger)repeats completionHandler:(void(^)())completionHandler {
	TFPPrinter *printer = [TFPPrinterManager sharedManager].printers.firstObject;
	double distance = [pos2 distanceToPoint:pos1];
	if(feedrate > 0) {
		printer.feedrate = feedrate;
	}
	
	TFPPrinterContext *context = [printer acquireContextWithOptions:TFPPrinterContextOptionDisableLevelCompensation|TFPPrinterContextOptionDisableBacklashCompensation queue:nil];
	
	[context sendGCode:[TFPGCode moveWithPosition:pos1 feedRate:-1] responseHandler:^(BOOL success, TFPGCodeResponseDictionary value) {
		[context sendGCode:[TFPGCode waitForCompletionCode] responseHandler:^(BOOL success, TFPGCodeResponseDictionary value) {
			uint64_t start = TFNanosecondTime();
			
			for(NSUInteger i=0; i<repeats; i++) {
				[context sendGCode:[TFPGCode moveWithPosition:pos2 feedRate:-1] responseHandler:nil];
				[context sendGCode:[TFPGCode moveWithPosition:pos1 feedRate:-1] responseHandler:nil];
				
				if(i == repeats-1) {
					[printer sendGCode:[TFPGCode waitForCompletionCode] responseHandler:^(BOOL success, TFPGCodeResponseDictionary value) {
						NSTimeInterval duration = (double)(TFNanosecondTime() - start) / NSEC_PER_SEC;
						
						TFLog(@"%.02f mm move using feed rate %.0f (= %.02f mm/s), repeated %ld times: %.03f s, %.03f mm/s",
							  distance, feedrate, feedrate/60.0, (long)repeats, duration, (repeats*distance*2)/duration);
						
						completionHandler();
					}];
				}
			}
			
		}];
	}];
}


- (void)runSpeedTestFromPosition:(TFP3DVector*)pos1 toPosition:(TFP3DVector*)pos2 spec:(NSArray*)spec {
	[self runSpeedTestFromPosition:pos1 toPosition:pos2 feedrate:[spec.firstObject[0] doubleValue] repeatCount:[spec.firstObject[1] integerValue] completionHandler:^{
		if(spec.count > 1) {
			[self runSpeedTestFromPosition:pos1 toPosition:pos2 spec:[spec subarrayWithRange:NSMakeRange(1, spec.count-1)]];
		}
	}];
}


- (IBAction)speedTest:(id)sender {
	TFP3DVector *fromPoint = [TFP3DVector vectorWithX:@10 Y:@10 Z:@10];
	TFP3DVector *toPointX = [TFP3DVector vectorWithX:@90 Y:@10 Z:@10];
	
	NSArray *spec = @[@[@200, @3], @[@200, @10], @[@500, @10], @[@1500, @10], @[@2500, @10], @[@3000, @10]];
	[self runSpeedTestFromPosition:fromPoint toPosition:toPointX spec:spec];
}


- (IBAction)pathPrintTest:(id)sender {
	TFPPrinter *printer = [TFPPrinterManager sharedManager].printers.firstObject;

	double Z = 0.2;
	double ePerMM = 0.1;
	
	
	[printer sendGCode:[TFPGCode codeForHeaterTemperature:220 waitUntilDone:NO] responseHandler:nil];
	[printer sendGCode:[TFPGCode moveHomeCode] responseHandler:nil];
	[printer sendGCode:[TFPGCode codeForHeaterTemperature:220 waitUntilDone:YES] responseHandler:nil];
	
	[printer sendGCode:[TFPGCode resetExtrusionCode] responseHandler:nil];
	[printer sendGCode:[TFPGCode moveWithPosition:[TFP3DVector zVector:Z] feedRate:2900] responseHandler:nil];
	double EPosition = 0;
	
	EPosition = 5;
	
	
	
	
	NSBezierPath *path = [NSBezierPath bezierPath];
	NSFont *font = [NSFont fontWithName:@"Helvetica" size:30];
	
	NSTextStorage *storage = [[NSTextStorage alloc] initWithString:@"Hello"];
	NSLayoutManager *manager = [[NSLayoutManager alloc] init];
	NSTextContainer *container = [[NSTextContainer alloc] init];
	[storage addLayoutManager:manager];
	[manager addTextContainer:container];
	
	NSGlyph glyphs[manager.numberOfGlyphs];
	[manager getGlyphs:glyphs range:NSMakeRange(0, manager.numberOfGlyphs)];
	
	[path moveToPoint:CGPointMake(0, 0)];
	[path appendBezierPathWithGlyphs:glyphs count:manager.numberOfGlyphs inFont:font];
	
	NSAffineTransform *transform = [NSAffineTransform transform];
	[transform translateXBy:10 yBy:10];
	[path transformUsingAffineTransform:transform];

	path = [path bezierPathByFlatteningPath];
	
	CGPoint previousPoint;
	[path elementAtIndex:0 associatedPoints:&previousPoint];
	[printer sendGCode:[TFPGCode moveWithPosition:[TFP3DVector xyVectorWithX:previousPoint.x y:previousPoint.y] feedRate:2900] responseHandler:nil];
	[printer sendGCode:[TFPGCode codeForExtrusion:5 feedRate:-1] responseHandler:nil];

	
	for(NSUInteger i=0; i<path.elementCount; i++) {
		NSPoint p;
		NSBezierPathElement element = [path elementAtIndex:i associatedPoints:&p];
		
		if(element == NSClosePathBezierPathElement) {
			continue;
		}
		
		NSNumber *E = nil;
		if(element == NSLineToBezierPathElement) {
			double length = sqrt(pow(p.x - previousPoint.x, 2) + pow(p.y - previousPoint.y, 2));
			E = @(EPosition + length*ePerMM);
			EPosition = E.doubleValue;
		}
		
		[printer sendGCode:[TFPGCode moveWithPosition:[TFP3DVector xyVectorWithX:p.x y:p.y] extrusion:E feedRate:2000] responseHandler:nil];
		previousPoint = p;
	}
	
	[printer sendGCode:[TFPGCode moveWithPosition:[TFP3DVector zVector:20] feedRate:2900] responseHandler:nil];
}


@end