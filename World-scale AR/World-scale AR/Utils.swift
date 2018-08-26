//
//  Utils.swift
//

import Foundation
import UIKit
import SceneKit

// MARK: - THREADING

//add code block to background thread, usage:
// BG {
//    code
// }
public func BG(_ block: @escaping ()->Void) {
    DispatchQueue.global(qos: .default).async(execute: block)
}
//add code block to main thread, usage:
// UI {
//    code
// }
public func UI(_ block: @escaping ()->Void) {
    DispatchQueue.main.async(execute: block)
}

//MARK: - CORE IMAGE
public typealias CIParameters = Dictionary<String, AnyObject>

public extension CIVector {
    convenience init(color: UIColor){
        var r :CGFloat = 0
        var g :CGFloat = 0
        var b :CGFloat = 0
        var a :CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.init(x: r, y: g, z: b, w: a)
    }
}

//MARK: - UIKIT
extension UIButton
{
    func addBlurEffect( style: UIBlurEffect.Style) -> UIVisualEffectView
    {
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: style))
        self.backgroundColor = .clear
        blur.frame = self.bounds
        blur.layer.cornerRadius = self.layer.cornerRadius
        blur.clipsToBounds = true
        blur.isUserInteractionEnabled = false
        self.insertSubview(blur, at: 0)
        if let imageView = self.imageView{
            self.bringSubviewToFront(imageView)
        }
        
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.widthAnchor.constraint(equalTo: self.widthAnchor).isActive = true
        blur.heightAnchor.constraint(equalTo: self.heightAnchor).isActive = true
        blur.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        blur.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        
        return blur
    }
}

extension UIImage {
    class func imageWithView(_ view: UIView) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, view.isOpaque, 0)
        defer { UIGraphicsEndImageContext() }
        view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
}

extension UINavigationBar {
    func createTransparentBlurEffect() {
        self.setBackgroundImage(UIImage(), for: .default)
        self.shadowImage = UIImage()
        self.backgroundColor = UIColor.init(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.1)
        
        // add blur effect behind navigation bar
        let visualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
        visualEffectView.frame = CGRect.init(x: 0, y: -UIApplication.shared.statusBarFrame.height, width: UIApplication.shared.statusBarFrame.width, height: self.bounds.height + UIApplication.shared.statusBarFrame.height)
        
        self.addSubview(visualEffectView)
        self.sendSubviewToBack(visualEffectView)
        
        // size the blur effect to the nav bar
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.topAnchor.constraint(equalTo: self.topAnchor, constant: -UIApplication.shared.statusBarFrame.height).isActive = true
        visualEffectView.leftAnchor.constraint(equalTo: self.leftAnchor).isActive = true
        visualEffectView.rightAnchor.constraint(equalTo: self.rightAnchor).isActive = true
        visualEffectView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
    }
}

//MARK: - SCENEKIT
extension SCNGeometry {
    func setFillMode(_ fillMode: SCNFillMode) -> Void {
        for mat in materials {
            mat.fillMode = fillMode
        }
    }
    
    func setTransparency(_ transparency: CGFloat) -> Void {
        for mat in materials {
            mat.transparency = transparency
        }
    }
    
    func setTransparencyMode(_ transparencyMode: SCNTransparencyMode) -> Void{
        for mat in materials {
            mat.transparencyMode = transparencyMode
        }
    }
    
    func setBlendMode(_ blendMode: SCNBlendMode) -> Void{
        for mat in materials {
            mat.blendMode = blendMode
        }
    }
    
    func setCullMode(_ cullMode: SCNCullMode) -> Void{
        for mat in materials {
            mat.isDoubleSided = false
            mat.cullMode = cullMode
        }
    }
}

extension SCNNode {
    func addConstraint(_ constraint: SCNConstraint){
        
        if self.constraints == nil {
            self.constraints = []
        }
        
        self.constraints?.append(constraint)
    }
}

//MARK: - CONSTRAINTS
extension UIView {
    func constraint(withIdentifier:String) -> NSLayoutConstraint? {
        return self.constraints.filter{ $0.identifier == withIdentifier }.first
    }
}

extension NSLayoutAnchor {
    @objc func constraintEqualToAnchor(anchor: NSLayoutAnchor!, constant:CGFloat, identifier:String) -> NSLayoutConstraint! {
        let constraint = self.constraint(equalTo: anchor, constant:constant)
        constraint.identifier = identifier
        return constraint
    }
}
