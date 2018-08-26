//
//  UIColor+Extensions.swift
//  Portfolio
//
//  Created by Avi Cieplinski on 7/23/18.
//  Copyright © 2018 Avi Cieplinski. All rights reserved.
//

import UIKit

extension UIColor {
    
    convenience init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt32()
        Scanner(string: hex).scanHexInt32(&int)
        let a, r, g, b: UInt32
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
    
    static var mapboxBlue = UIColor(hexString: "#4264fb")
    static var mapboxBlueDark = UIColor(hexString: "#314ccd")
    static var mapboxBlueLight = UIColor(hexString: "#aab7ef")
    static var mapboxBlueFaint = UIColor(hexString: "#edf0fd")
    static var mapboxGray = UIColor(hexString: "#607d9c")
    static var mapboxGrayDark = UIColor(hexString: "#273D56")
    static var mapboxGrayLight = UIColor(hexString: "#c6d2e1")
    static var mapboxGrayFaint = UIColor(hexString: "#f4f7fb")
    static var mapboxPink = UIColor(hexString: "#ee4e8b")
    static var mapboxPinkDark = UIColor(hexString: "#b43b71")
    static var mapboxPinkLight = UIColor(hexString: "#f8c8da")
    static var mapboxPinkFaint = UIColor(hexString: "#fbe5ee")
    static var mapboxPurple = UIColor(hexString: "#7753eb")
    static var mapboxPurpleDark = UIColor(hexString: "#5a3fc0")
    static var mapboxPurpleLight = UIColor(hexString: "#c5b9eb")
    static var mapboxPurpleFaint = UIColor(hexString: "#f2effa")
    static var mapboxOrange = UIColor(hexString: "#f79640")
    static var mapboxOrangeDark = UIColor(hexString: "#ba7334")
    static var mapboxOrangeLight = UIColor(hexString: "#fbcea6")
    static var mapboxOrangeFaint = UIColor(hexString: "#feefe2")
    static var mapboxRed = UIColor(hexString: "#f74e4e")
    static var mapboxRedDark = UIColor(hexString: "#ba3b3f")
    static var mapboxRedLight = UIColor(hexString: "#f6b7b7")
    static var mapboxRedFaint = UIColor(hexString: "#fbe5e5")
    static var mapboxYellow = UIColor(hexString: "#d9d838")
    static var mapboxYellowDark = UIColor(hexString: "#a4a62d")
    static var mapboxYellowLight = UIColor(hexString: "#fff5a0")
    static var mapboxYellowFaint = UIColor(hexString: "#fcfcdf")
    static var mapboxGreen = UIColor(hexString: "#33c377")
    static var mapboxGreenDark = UIColor(hexString: "#269561")
    static var mapboxGreenLight = UIColor(hexString: "#afdec5")
    static var mapboxGreenFaint = UIColor(hexString: "#e8f5ee")
    static var mapboxTeal = UIColor(hexString: "#11b4da")
    static var mapboxTealDark = UIColor(hexString: "#136174")
    static var mapboxTealLight = UIColor(hexString: "#a4deeb")
    static var mapboxTealFaint = UIColor(hexString: "#d7f1f6")
}
