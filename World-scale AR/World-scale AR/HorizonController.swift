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
    
    // UI
    var visualEffectView: UIVisualEffectView!
    var geometryNode: SCNNode!
    var focusTarget: SCNNode!
    var motionManager: CMMotionManager!
    
    // POIs
    var poiLocations: [CLLocation]!
    var poiLocationNames: [String]!
    var poiNodes: [SCNNode]!
    
    // Mapbox terrain object
    var terrainNode: TerrainNode?
    
    // Gestures
    var scenePanGesture: UIPanGestureRecognizer!
    
    // MARK: - Scene setup functions
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addSubview(sceneView)
        
        setupScene()
        
        addFocusTarget()
        add3dObject()
        
        checkForUpdates = true
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
    
    // Show 2D map for calibration and context
    func show2dMap() {
        let url = URL(string: "mapbox://styles/mapbox/streets-v10")
        mapView = MGLMapView(frame: CGRect(x: 0, y: view.bounds.height - 200.0, width: view.bounds.width, height: 200.0), styleURL: url)
        mapView.autoresizesSubviews = true
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.setCenter(CLLocationCoordinate2D(latitude: deviceLocation.coordinate.latitude, longitude: deviceLocation.coordinate.longitude), zoomLevel: 17, animated: false)
        mapView.showsUserLocation = true
        mapView.showsUserHeadingIndicator = true
        
        let camera = MGLMapCamera(lookingAtCenter: mapView.centerCoordinate, altitude: 200, pitch: 45, heading: 0)
        mapView.camera = camera
        
        self.view.addSubview(mapView)
        
        setupPOIs()
    }
    
    func createHorizon(currentDeviceLocation: CLLocation) {
        let coordinates = calculateHorizonCoordinates(currentDeviceLocation: currentDeviceLocation) // [maxLatitude, minLatitude, maxLongitude, minLongitude]
        let maxLatitude = coordinates[0]
        let minLatitude = coordinates[1]
        let maxLongitude = coordinates[2]
        let minLongitude = coordinates[3]
        
        terrainNode = TerrainNode(minLat: minLatitude, maxLat: maxLatitude,
                                  minLon: minLongitude, maxLon: maxLongitude)
        
        if let terrainNode = terrainNode {
            terrainNode.scale = SCNVector3(2, 2, 2)
            terrainNode.position = SCNVector3(0, -3, 0)
            terrainNode.geometry?.setTransparency(0.0)
            sceneView.pointOfView?.addChildNode(terrainNode)
//            scene.rootNode.addChildNode(terrainNode)
            
            terrainNode.fetchTerrainHeights(minWallHeight: 0.1, enableDynamicShadows: true, progress: { progress, total in
            }, completion: {_ in
                let poiLocation = CLLocation(latitude: 37.791123, longitude: -122.396598)
                let sphere = SCNSphere(radius: 1.0)
                let sphereNode = SCNNode(geometry: sphere)
                sphereNode.geometry?.materials.first?.diffuse.contents = UIColor.red
                sphereNode.position = terrainNode.positionForLocation(poiLocation)
                terrainNode.addChildNode(sphereNode)
                NSLog("Terrain load complete")
            })
        }
    }
    
    // MARK: - POI helper functions
    
    // For this example, the POIs center around San Francisco. You can customize this list
    // with any number of different POIs.
    func setupPOIs() {
        // 37.791123, -122.396598
        let poiLocation1 = CLLocation(latitude: 37.791123, longitude: -122.396598) // 50 Beale Street
        
        poiLocations = [poiLocation1]
        poiLocationNames = ["50 Beale"]
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
            
//            scene.rootNode.addChildNode(poiNode)
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
                    createHorizon(currentDeviceLocation: deviceLocation)
                    show2dMap()
                    
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
        let distanceToHorizonInKilometers = 1 * deviceAltitudeInMeters.squareRoot() // horizon is further away the higher up the device
        
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
        
        let wait = SCNAction.wait(duration: 4.0)
        let fadeOut = SCNAction.fadeOut(duration: 0.5)
        geometryNode.runAction(wait, completionHandler: {
            self.geometryNode.runAction(fadeOut)
        })
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
