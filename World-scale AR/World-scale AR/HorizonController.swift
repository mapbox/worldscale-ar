//
//  HorizonController.swift
//
//  This demo uses location data to determine where specific
//  points of interest (POIs) are relative to a user, and displays
//  them in worldscale AR.
//

import ARKit
import CoreLocation
import CoreMotion
import Mapbox
import MapboxSceneKit
import SceneKit
import UIKit

class HorizonController: UIViewController, ARSCNViewDelegate, CLLocationManagerDelegate, MGLMapViewDelegate {
    
    // MARK: - UI button states
    
    enum ButtonState: Int {
        case calibrate,
        confirm,
        enableArMode,
        disableArMode
    }
    
    // MARK: - Variables
    
    // Scenes
    let sceneView: ARSCNView = ARSCNView()
    var scene: SCNScene!
    var loadingScene: UIView!
    var mapView: MGLMapView!
    
    // Location
    var locationManager: CLLocationManager!
    var deviceLocation: CLLocation!
    var checkForUpdates: Bool!
    
    // Mapbox terrain object
    var terrainNode: TerrainNode?
    var showHorizon: Bool!
    
    // UI
    var instructions: UIView!
    var instructionsText: UILabel!
    var visualEffectView: UIVisualEffectView!
    var buttons: UIView!
    var arButton: UIButton!
    var focusButton: UIButton!
    var arButtonState: ButtonState!
    var geometryNode: SCNNode!
    var focusTarget: SCNNode!
    var motionManager: CMMotionManager!
    
    // POIs
    var poiLocations: [CLLocation]!
    var poiLocationNames: [String]!
    var poiNodes: [SCNNode]!
    
    // Gestures
    var scenePanGesture: UIPanGestureRecognizer!
    
    // MARK: - Scene setup functions
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addSubview(sceneView)
        
        showLoadingScene()
        
        setupScene()
        setupGestures()
        setupInstructionLabel()
        setupButtons()
        
        addFocusTarget()
        add3dObject()
        
        checkForUpdates = true
        showHorizon = true // toggle horizon on and off
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.headingOrientation = .portrait
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingHeading()
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        locationManager.stopUpdatingHeading()
        motionManager.stopGyroUpdates()
        sceneView.session.pause()
    }
    
    // MARK: - Scene setup helper functions
    
    func setupScene() {
        scene = SCNScene()
        sceneView.scene = scene
        
        sceneView.delegate = self
        sceneView.isPlaying = true
        sceneView.frame = self.view.bounds
        
        scene.rootNode.light?.type = SCNLight.LightType.ambient
    }
    
    func setupGestures() {
        scenePanGesture = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:)))
        sceneView.addGestureRecognizer(scenePanGesture)
    }
    
    func setupInstructionLabel() {
        instructions = UIView()
        
        // Create intructions label
        let instructionsTextString = "Does this look right?"
        instructionsText = UILabel()
        instructionsText.backgroundColor = UIColor.clear
        instructionsText.clipsToBounds = true
        instructionsText.layer.borderColor = UIColor.mapboxGrayDark.cgColor
        instructionsText.layer.borderWidth = 1.0
        instructionsText.layer.cornerRadius = 20.0
        instructionsText.textAlignment = .center
        instructionsText.textColor = UIColor.mapboxGrayDark
        
        // Blur background
        visualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
        visualEffectView.layer.cornerRadius = instructionsText.layer.cornerRadius
        visualEffectView.clipsToBounds = true
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        
        // Size label appropriately
        sizeLabelToText(label: instructionsText, textString: instructionsTextString)
        
        instructions.addSubview(visualEffectView)
        instructions.addSubview(instructionsText)
        
        self.view.addSubview(instructions)
    }
    
    func setupButtons() {
        buttons = UIView()
        let buttonsWidth = self.view.frame.width
        let buttonsHeight = CGFloat(100.0)
        let yPosition = self.view.frame.height - buttonsHeight
        buttons.frame = CGRect(x: 0, y: yPosition, width: buttonsWidth, height: buttonsHeight)
        
        let leftButton = createButton(buttonStyle: .calibrate)
        let rightButton = createButton(buttonStyle: .confirm)
        
        buttons.addSubview(leftButton)
        buttons.addSubview(rightButton)
        
        self.view.addSubview(buttons)
    }
    
    // MARK: - Loading and calibration scene functions
    
    func showLoadingScene() {
        loadingScene = UIView()
        loadingScene.backgroundColor = UIColor.init(red: (230.0/255.0), green: (228.0/255.0), blue: (224.0/255.0), alpha: 1.0)
        loadingScene.frame = self.view.bounds
        self.view.addSubview(loadingScene)
    }
    
    // Show 2D map for calibration and context
    func show2dMap() {
        let url = URL(string: "mapbox://styles/mapbox/streets-v10")
        mapView = MGLMapView(frame: view.bounds, styleURL: url)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.setCenter(CLLocationCoordinate2D(latitude: deviceLocation.coordinate.latitude, longitude: deviceLocation.coordinate.longitude), zoomLevel: 3, animated: false)
        mapView.showsUserLocation = true
        mapView.showsUserHeadingIndicator = true
        
        self.view.addSubview(mapView)
        
        self.view.bringSubviewToFront(instructions)
        self.view.bringSubviewToFront(buttons)
        
        setupPOIs()
    }
    
    // Refresh map view if location isn't correct
    func refresh2dMap() {
        mapView.removeFromSuperview()
        terrainNode?.removeFromParentNode()
        
        // Recreate mapView and terrainNode based on new device location
        checkForUpdates = true
    }
    
    // MARK: - POI helper functions
    
    // For this example, the POIs center around San Francisco. You can customize this list
    // with any number of different POIs.
    func setupPOIs() {
        let poiLocation1 = CLLocation(latitude: 44.4280, longitude: -110.5885) // Yellostone, Wyoming
        let poiLocation2 = CLLocation(latitude: 33.8734, longitude: -115.9010) // Joshua Tree, California
        let poiLocation3 = CLLocation(latitude: 45.3736, longitude: -121.6960) // Mt. Hood, Oregon
        
        poiLocations = [poiLocation1, poiLocation2, poiLocation3]
        poiLocationNames = ["🌲 Yellowstone", "🌵 Joshua Tree", "🗻 Mt. Hood"]
        poiNodes = []
        
        // Create label for each POI
        for (index, poi) in poiLocationNames.enumerated() {
            let poiGeometry = SCNPlane(width: 3, height: 1)
            
            createPoiLabel(labelText: poi, geometry: poiGeometry)
            
            let poiNode = SCNNode(geometry: poiGeometry)
            let billboardConstraint = SCNBillboardConstraint()
            poiNode.constraints = [billboardConstraint]
            
            poiNodes.append(poiNode)
            
            let poiAnnotation = MGLPointAnnotation()
            let poiCoordinates = poiLocations[index]
            poiAnnotation.coordinate = CLLocationCoordinate2D(latitude: poiCoordinates.coordinate.latitude, longitude: poiCoordinates.coordinate.longitude)
            poiAnnotation.title = poiLocationNames[index]
            mapView.addAnnotation(poiAnnotation)
            
            scene.rootNode.addChildNode(poiNode)
        }
    }
    
    func createPoiLabel(labelText: String, geometry: SCNGeometry) {
        // Create a SpriteKit scene
        let skScene = SKScene(size: CGSize(width: 300, height: 100))
        skScene.backgroundColor = UIColor.clear
        
        // Create a background
        let rectangle = SKShapeNode(rect: CGRect(x: 0, y: 0, width: 300, height: 100), cornerRadius: 10)
        rectangle.fillColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
        rectangle.alpha = 0.6
        
        // Add a text label
        let labelNode = SKLabelNode(text: labelText)
        labelNode.fontSize = 30
        labelNode.fontName = "San Fransisco"
        labelNode.position = CGPoint(x: 150, y: 60)
        labelNode.yScale = -1
        
        // Add background and text to SpriteKit scene
        skScene.addChild(rectangle)
        skScene.addChild(labelNode)
        
        // Use SpriteKit scene as material on POI geometry
        let material = SCNMaterial()
        material.isDoubleSided = true
        material.diffuse.contents = skScene
        geometry.materials = [material]
    }
    
    // MARK: - Location manager helper functions
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        if CLLocationManager.locationServicesEnabled() {
            UIView.animate(withDuration: 0.01) {
                var angle = Float(newHeading.trueHeading)
                angle = fmodf(angle, 360.0) // keep it within (-360, 360)
                angle = angle < 0 ? angle + 360.0 : angle // make it a positive value
                
                self.terrainNode?.eulerAngles.y = GLKMathDegreesToRadians(angle)
            }
            
            // Place POIs relative to device location
            if checkForUpdates { // We only need to do this once
                if manager.location != nil {
                    checkForUpdates = false
                    deviceLocation = manager.location!
                    show2dMap()
                    
                    if showHorizon {
                        createHorizon(currentDeviceLocation: deviceLocation)
                    }
                    
                    for (index, poi) in poiLocations.enumerated() {
                        let transform = transformMatrix(originLocation: deviceLocation, destinationLocation: poi)
                        
                        poiNodes[index].simdWorldTransform = transform
                    }
                }
            }
        }
    }
    
    // Create a transform matrix to properly position a POI node,
    // based on current device location.
    func transformMatrix(originLocation: CLLocation, destinationLocation: CLLocation) -> simd_float4x4 {
        let azimuth = azimuthBetween(origin: originLocation, destination: destinationLocation)
        
        // Place POIs "z" meters away from camera
        let position = vector_float4(0, 0, -10, 0)
        let translationMatrix = matrix_identity_float4x4.translationMatrix(position)
        
        // Rotate POI based on azimuth
        let rotationMatrix = matrix_identity_float4x4.rotationAroundY(radians: azimuth)
        
        // Combine rotation and translation to get final position of POI
        let transformMatrix = simd_mul(rotationMatrix, translationMatrix)
        
        return simd_mul(matrix_identity_float4x4, transformMatrix)
    }
    
    // The azimuth between the device location and the POI location
    // is the angle (starting from 0 = north) the device has to rotate
    // to face the POI. If a POI is directly east of you, the azimuth is 90.
    // South is 180, west is 270, etc.
    func azimuthBetween(origin: CLLocation, destination: CLLocation) -> Float {
        var azimuth: Float = 0
        
        let originLatitude = GLKMathDegreesToRadians(Float(origin.coordinate.latitude))
        let originLongitude = GLKMathDegreesToRadians(Float(origin.coordinate.longitude))
        let destinationLatitude = GLKMathDegreesToRadians(Float(destination.coordinate.latitude))
        let destinationLongitude = GLKMathDegreesToRadians(Float(destination.coordinate.longitude))
        
        let dLon = destinationLongitude - originLongitude
        
        let y = sin(dLon) * cos(destinationLatitude)
        let x = cos(originLatitude) * sin(destinationLatitude) - sin(originLatitude) * cos(destinationLatitude) * cos(dLon)
        
        azimuth = atan2(y, x)
        
        if(azimuth < 0) { azimuth += 2 * .pi } // We only use positive values for consistency
        
        return azimuth
    }
    
    // MARK: - Horizon placement helper functions
    
    // Based on device location (latitude, longitude, altitude),
    // figure out where the horizon is.
    // Note: All distances are measured in meters and kilometers.
    func calculateHorizonCoordinates(currentDeviceLocation: CLLocation) -> [Double] {
        // Where is the device, in 3D space?
        let deviceLatitude = currentDeviceLocation.coordinate.latitude
        let deviceLongitude = currentDeviceLocation.coordinate.longitude
        let deviceAltitudeInMeters = max(currentDeviceLocation.altitude, 2) // assume the device is at least 2 meters off the ground
        
        // Given the device altitude, how far away is the horizon?
        let distanceToHorizonInKilometers = 3.57 * deviceAltitudeInMeters.squareRoot() // horizon is further away the higher up the device
        
        // Establish starting points for figuring out the distance of 1º latitude/longitude
        let oneDegreeLatitudeInKilometers = 111.0 // on average, 1º latitude roughly equals 111.0 km
        let maxLongitudeLengthInKilometers = 111.321 // at the equater, 1º longitude roughly equals 111.321 km
        let oneDegreeLongitudeInKilometers = cos(deviceLatitude) * maxLongitudeLengthInKilometers // widest at equator, 0 at poles
        
        // How far away is the horizon, in lat/lon degrees?
        let latitudeDegreesToHorizon = distanceToHorizonInKilometers * (1 / oneDegreeLatitudeInKilometers)
        let longitudeDegreesToHorizon = distanceToHorizonInKilometers * (1 / oneDegreeLongitudeInKilometers)
        
        // Given all this, what's the bounding box of our terrain map?
        let maxLatitude = deviceLatitude + latitudeDegreesToHorizon
        let minLatitude = deviceLatitude - latitudeDegreesToHorizon
        let maxLongitude = deviceLongitude + longitudeDegreesToHorizon
        let minLongitude = deviceLongitude - longitudeDegreesToHorizon
        
        return [maxLatitude, minLatitude, maxLongitude, minLongitude]
    }
    
    // Create terrain node that showcases terrain at horizon level
    func createHorizon(currentDeviceLocation: CLLocation) {
        let coordinates = calculateHorizonCoordinates(currentDeviceLocation: currentDeviceLocation) // [maxLatitude, minLatitude, maxLongitude, minLongitude]
        let maxLatitude = coordinates[0]
        let minLatitude = coordinates[1]
        let maxLongitude = coordinates[2]
        let minLongitude = coordinates[3]
        
        terrainNode = TerrainNode(minLat: minLatitude, maxLat: maxLatitude,
                                  minLon: minLongitude, maxLon: maxLongitude)
        
        if let terrainNode = terrainNode {
            terrainNode.scale = SCNVector3(0.01, 0.01, 0.01)
            terrainNode.position = SCNVector3(0, -3, 0)
            terrainNode.geometry?.setFillMode(.lines)
            sceneView.pointOfView?.addChildNode(terrainNode)
            
            terrainNode.fetchTerrainHeights(minWallHeight: 0.1, enableDynamicShadows: true, progress: { progress, total in
            }, completion: {
                NSLog("Terrain load complete")
            })
        }
    }
    
    // MARK: - Gesture functions
    
    // Pan up or down to move horizon line
    @objc func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        if gestureRecognizer.state == .began || gestureRecognizer.state == .changed {
            let translation = gestureRecognizer.translation(in: self.view)
            let currentY = CGFloat((terrainNode?.position.y)!)
            var yTranslation = currentY - translation.y
            yTranslation = max(-50, min(0, yTranslation)) // -50 < yTranslation < 0
            terrainNode?.position = SCNVector3(0, yTranslation, 0)
        }
    }
    
    // MARK: - UI helper functions
    
    func sizeLabelToText(label: UILabel, textString: String) {
        label.text = textString
        label.sizeToFit()
        label.frame = CGRect(x: 0, y: 100, width: label.intrinsicContentSize.width + 36, height: label.intrinsicContentSize.height + 24)
        label.center.x = self.view.center.x
        
        visualEffectView.frame = label.frame
    }
    
    // An invisible target that the main 3D UI object
    // in the scene will always be "looking" at.
    func addFocusTarget() {
        focusTarget = SCNNode()
        sceneView.pointOfView?.addChildNode(focusTarget)
        focusTarget.position = SCNVector3(0, 0, -2)
    }
    
    // A 3D UI object that acts as a guide for the user, to
    // better indicate what movement/interaction is currently expected.
    func add3dObject() {
        // get all the models from a .dae file (there might be multiple)
        // and position them in front of the camera
        let geometryScene = SCNScene(named: "art.scnassets/scanGesture.dae")!
        geometryNode = SCNNode()
        for child: SCNNode in geometryScene.rootNode.childNodes {
            geometryNode.addChildNode(child)
        }
        geometryNode.position = SCNVector3Make(0, 0, -1)
        
        // constrain the geometryNode to always look at focusTarget
        let lookAtConstraint = SCNLookAtConstraint(target: focusTarget)
        lookAtConstraint.isGimbalLockEnabled = true
        lookAtConstraint.influenceFactor = 0.1
        geometryNode.constraints = [lookAtConstraint]
        
        // move the focusTarget based on changes in the gyroscope
        motionManager = CMMotionManager()
        motionManager.gyroUpdateInterval = 0.01
        motionManager.startGyroUpdates(to: OperationQueue.main) { (data: CMGyroData?, error: Error?) in
            if let info = data?.rotationRate {
                let xRotation = (-5.0...5.0).contains(info.x) ? Float(info.x) : 0.0
                let yRotation = (-5.0...5.0).contains(info.y) ? Float(info.y) : 0.0
                self.focusTarget.position = SCNVector3(x: yRotation, y: -xRotation, z: -2)
            }
        }
        
        sceneView.pointOfView?.addChildNode(geometryNode)
    }
    
    // MARK: - Button styles and interactions
    
    // Create general calibration and confirmation buttons
    func createButton(buttonStyle: ButtonState) -> UIButton {
        let button = UIButton(type: UIButton.ButtonType.system)
        var buttonColor: UIColor
        var buttonText: String
        
        let padding: CGFloat = 20
        var xPostion = padding
        let yPostion: CGFloat = 10
        let buttonWidth: CGFloat = (self.view.frame.maxX - (3 * padding)) / 2
        let buttonHeight: CGFloat = 45
        
        switch buttonStyle {
        case .calibrate:
            buttonColor = UIColor.mapboxGray
            button.tag = ButtonState.calibrate.rawValue
            buttonText = "No"
            button.addTarget(self, action: #selector(self.buttonDown(_:)), for: .touchDown)
        default:
            buttonColor = UIColor.mapboxBlue
            button.tag = ButtonState.confirm.rawValue
            buttonText = "Yes"
            xPostion = buttonWidth + (2 * padding)
            button.addTarget(self, action: #selector(self.buttonDown(_:)), for: .touchDown)
        }
        
        button.backgroundColor = buttonColor
        button.frame = CGRect(x: xPostion, y: yPostion, width: buttonWidth, height: buttonHeight)
        button.layer.cornerRadius = 20
        button.setTitle(buttonText, for: UIControl.State.normal)
        button.setTitleColor(UIColor.white, for: UIControl.State.normal)
        button.tintColor = UIColor.black
        
        return button
    }
    
    // Create button to enable AR mode
    func setupArButton() {
        if arButton == nil {
            arButton = UIButton(type: UIButton.ButtonType.system)
            arButton.frame = CGRect.zero
            arButton.backgroundColor = UIColor.mapboxBlue
            arButton.tintColor = UIColor.white
            arButton.layer.cornerRadius = 20
            arButton.tag = ButtonState.enableArMode.rawValue
            
            self.view.addSubview(arButton)
            arButton.translatesAutoresizingMaskIntoConstraints = false
            let w = arButton.widthAnchor.constraint(equalToConstant: self.view.bounds.height * 0.1)
            w.isActive = true
            w.identifier = "arButtonWidth"
            arButton.heightAnchor.constraint(equalToConstant: self.view.bounds.height * 0.1).isActive = true
            arButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
            arButton.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: self.view.bounds.height * -0.1).isActive = true
            arButton.addTarget(self, action: #selector(self.buttonDown(_:)), for: .touchDown)
        }
        
        let constraint = self.arButton.constraint(withIdentifier: "arButtonWidth")
        constraint?.constant = self.view.bounds.height * 0.1
        arButton.setTitle(nil, for: .normal)
        UIView.animate(withDuration: 0.1, animations: {
            self.arButton.layoutIfNeeded()
        }, completion: { (completed) in
            let arIcon = UIImage(named: "art.scnassets/ar-icon.png")
            self.arButton.setImage(arIcon, for: .normal)
        })
    }
    
    // Create button to disable AR mode
    func setupFocusButton() {
        focusButton = UIButton(type: UIButton.ButtonType.system)
        focusButton.frame = CGRect.zero
        focusButton.backgroundColor = UIColor.clear
        
        let focusIcon = UIImage(named: "art.scnassets/focus-icon.png")
        focusButton.setImage(focusIcon, for: .normal)
        focusButton.tintColor = UIColor.black
        focusButton.layer.cornerRadius = 20
        focusButton.tag = ButtonState.disableArMode.rawValue
        focusButton.alpha = 0.0
        
        self.view.addSubview(focusButton)
        focusButton.translatesAutoresizingMaskIntoConstraints = false
        focusButton.widthAnchor.constraint(equalToConstant: self.view.bounds.height * 0.1).isActive = true
        focusButton.heightAnchor.constraint(equalToConstant: self.view.bounds.height * 0.1).isActive = true
        focusButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        focusButton.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: self.view.bounds.height * -0.1).isActive = true
        
        focusButton.addBlurEffect(style: .regular).alpha = 0.7
        focusButton.addTarget(self, action: #selector(self.buttonDown(_:)), for: .touchDown)
    }
    
    // Toggle AR mode on and off
    @objc private func buttonDown(_ sender: UIButton!) {
        switch sender.tag {
            
        // Calibrate location
        case ButtonState.calibrate.rawValue:
            UIView.animate(withDuration: 0.3, animations: {
                self.instructions.alpha = 0.0
            })
            
            refresh2dMap()
            
            UIView.animate(withDuration: 0.3, animations: {
                self.instructions.alpha = 1.0
            })
            
        // Confirm location
        case ButtonState.confirm.rawValue:
            buttons.isHidden = true
            instructions.isHidden = true
            setupArButton()
            setupFocusButton()
            self.view.bringSubviewToFront(arButton)
            self.loadingScene.alpha = 0.0
            
        // Enter AR mode
        case ButtonState.enableArMode.rawValue:
            UIView.animate(withDuration: 0.3, animations: {
                self.arButton.alpha = 0.0
                self.focusButton.alpha = 1.0
                self.mapView.alpha = 0.0
            })
            
            let wait = SCNAction.wait(duration: 4.0)
            let fadeOut = SCNAction.fadeOut(duration: 0.5)
            self.geometryNode.runAction(wait, completionHandler: {
                self.geometryNode.runAction(fadeOut)
            })
            
        // Leave AR mode
        case ButtonState.disableArMode.rawValue:
            UIView.animate(withDuration: 0.3, animations: {
                self.arButton.alpha = 1.0
                self.focusButton.alpha = 0.0
                self.mapView.alpha = 1.0
            })
            
        // Unknown button state
        default:
            print("Unknown button state")
        }
    }
}

// MARK: - Extend matrix_float4x4 for worldscale placement

internal extension matrix_float4x4 {
    func rotationAroundY(radians: Float) -> matrix_float4x4 {
        var matrix: matrix_float4x4 = self
        
        matrix.columns.0.x = cos(radians)
        matrix.columns.0.z = -sin(radians)
        
        matrix.columns.2.x = sin(radians)
        matrix.columns.2.z = cos(radians)
        
        return matrix.inverse
    }
    
    func translationMatrix(_ translation : vector_float4) -> matrix_float4x4 {
        var matrix: matrix_float4x4 = self
        matrix.columns.3 = translation
        return matrix
    }
}
