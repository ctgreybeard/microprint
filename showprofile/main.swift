//
//  main.swift
//  showprofile
//
//  Created by William Waggoner on 9/8/15.
//  Copyright © 2015 William Waggoner. All rights reserved.
//

import Foundation

var showAll = false

let curaPrefix = ";CURA_PROFILE_STRING:"

let interestingValues = [
    "bottom_layer_speed",
    "bottom_thickness",
    "filament_diameter",
    "fill_density",
    "layer0_width_factor",
    "layer_height",
    "nozzle_size",
    "platform_adhesion",
    "print_speed",
    "print_temperature",
    "retraction_amount",
    "retraction_enable",
    "retraction_min_travel",
    "retraction_speed",
    "solid_bottom",
    "solid_layer_thickness",
    "solid_top",
    "support",
    "travel_speed",
    "wall_thickness",
    "start.gcode",
    "end.gcode",
]

let args = Process.arguments[1..<Process.arguments.count]

for arg in args {
    switch arg {
    case "--all":
        showAll = true
    default:
        print("Unknown option: \(arg)")
    }
}

while let inline = readLine(stripNewline: true) {
    if inline.hasPrefix(curaPrefix) {
        let profileString = inline.stringByReplacingOccurrencesOfString(curaPrefix, withString: "")
        //        print("Profile: \(profileString)")
        let deflatedData = NSData(base64EncodedString: profileString, options: NSDataBase64DecodingOptions(rawValue: 0))
        let rawData = deflatedData!.tf_dataByDecodingDeflate()
        //        print("Decoded: \(decodedData)")

        if var realString = NSString(data:rawData, encoding:NSUTF8StringEncoding) as String? {
            realString = realString.stringByReplacingOccurrencesOfString("\u{c}", withString: "\u{8}")   // section split
            let pairs = realString.componentsSeparatedByString("\u{8}")
            var profile: [String:String] = [:];

            for pairString in pairs {
                if showAll {
                    print("pair: \(pairString)")
                }
                if let separator = pairString.rangeOfString("=") {
                    let cString = pairString.characters
                    let key = String(cString[Range(start: cString.startIndex, end: separator.endIndex.predecessor())]);
                    let value = String(cString[Range(start: separator.startIndex.successor(), end: cString.endIndex)]);
                    profile[key] = value;
                }
            }
            print("-+-+-+-+-")
            for k in interestingValues {
                if let v = profile[k] {
                    print("\(k): \(v)")
                } else {
                    print("\(k) is not set")
                }
            }
        } else {
            print("Unable to decode profile string")
        }


    }
}