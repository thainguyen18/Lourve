//
//  ViewController.swift
//  Lourve
//
//  Created by Thai Nguyen on 1/27/20.
//  Copyright © 2020 Thai Nguyen. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    var paintings = [String:Painting]()
    
    @IBAction func BuyPressed(_ sender: Any) {
        print("Bought this artwork")
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
       loadData()
        
        
        // Pre warm webview
        let preload = UIWebView()
        view.addSubview(preload)
        let request = URLRequest(url: URL(string: "https://en.wikipedia.org/wiki/Mona_Lisa")!)
        preload.loadRequest(request)
        preload.removeFromSuperview()
    }
    
    private func loadData() {
        guard let url = Bundle.main.url(forResource: "paintings", withExtension: "json") else {
            fatalError("Unable to find paintings.json in bundle.")
        }
        
        
        guard let data = try? Data(contentsOf: url) else {
            fatalError("Unable to load paintings.json")
        }
        
        let decoder = JSONDecoder()
        guard let loadedPaintings = try? decoder.decode([String:Painting].self, from: data) else {
            fatalError("Unable to parse paintings.json")
        }
        
        paintings = loadedPaintings
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARImageTrackingConfiguration()
        
        guard let trackingImages = ARReferenceImage.referenceImages(inGroupNamed: "Paintings", bundle: nil) else {
            fatalError("Couldn't load tracking images.")
        }
        
        configuration.trackingImages = trackingImages

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }

    // MARK: - ARSCNViewDelegate
    

    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        
        guard let imageAnchor = anchor as? ARImageAnchor else { return nil }
        
        guard let paintingImage = imageAnchor.referenceImage.name else { return nil }
        
        guard let painting = paintings[paintingImage] else { return nil }
        
        let plane = SCNPlane(width: imageAnchor.referenceImage.physicalSize.width, height: imageAnchor.referenceImage.physicalSize.height)
        
        plane.firstMaterial?.diffuse.contents = UIColor.clear
        
        let planeNode = SCNNode(geometry: plane)
        
        planeNode.eulerAngles.x = -.pi / 2
        
        let node = SCNNode()
        
        node.opacity = 0
        
        node.addChildNode(planeNode)
        
        // More to come
        
        let spacing: Float = 0.005
        
        let titleNode = textNode(painting.title, font: .boldSystemFont(ofSize: 10))
        
        titleNode.pivotOnTopLeft()
        
        // Move it to the right edge or our painting
        titleNode.position.x += Float(plane.width / 2) + spacing
        titleNode.position.y += Float(plane.height / 2)
        
        // add it to plane node
        planeNode.addChildNode(titleNode)
         
        
        let painterNode = textNode(painting.artist, font: .systemFont(ofSize: 8))
        painterNode.pivotTopCenter()
        painterNode.position.y -= Float(plane.height / 2) + spacing
        planeNode.addChildNode(painterNode)
        
        
        let yearNode = textNode(painting.year, font: .systemFont(ofSize: 6))
        yearNode.pivotTopCenter()
        yearNode.position.y = painterNode.position.y - spacing - painterNode.height
        planeNode.addChildNode(yearNode)
        
        // Webview
        let detailsWidth = max(titleNode.width, 0.25)
        
        let detailsHeight = (Float(plane.height) - titleNode.height) + painterNode.height + yearNode.height + (spacing * 2)
        
        let detailsPlane = SCNPlane(width: CGFloat(detailsWidth), height: CGFloat(detailsHeight))
        
        let detailsNode = SCNNode(geometry: detailsPlane)
        
        detailsNode.pivotOnTopLeft()
        
        detailsNode.position.x += Float(plane.width / 2) + spacing
        
        detailsNode.position.y = titleNode.position.y - titleNode.height - spacing
        
        planeNode.addChildNode(detailsNode)
        
        // add webview to plane node
        DispatchQueue.main.async {
            let width: CGFloat = 800
            let height = width / (detailsPlane.width / detailsPlane.height)
            let webView = UIWebView(frame: CGRect(x: 0, y: 0, width: width, height: height))
            let request = URLRequest(url: URL(string: painting.url)!)
            webView.loadRequest(request)
            detailsPlane.firstMaterial?.diffuse.contents = webView
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            SCNTransaction.animationDuration = 1
            node.opacity = 1
        }
     
        return node
    }
    
    
    func textNode(_ str: String, font: UIFont) -> SCNNode {
        let text = SCNText(string: str, extrusionDepth: 0.0)
        
        text.flatness = 0.1
        
        text.font = font
        
        let textNode = SCNNode(geometry: text)
        
        textNode.scale = SCNVector3(0.002, 0.002, 0.002)
        
        return textNode
    }

    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}


extension SCNNode {
    var width: Float {
        return (boundingBox.max.x - boundingBox.min.x) * scale.x
    }
    
    var height: Float {
        return (boundingBox.max.y - boundingBox.min.y) * scale.y
    }
    
    
    func pivotOnTopLeft() {
        let (min, max) = boundingBox
        
        pivot = SCNMatrix4MakeTranslation(min.x, (max.y - min.y) + min.y, 0)
    }
    
    
    func pivotTopCenter() {
        let (min, max) = boundingBox
        
        pivot = SCNMatrix4MakeTranslation((max.x - min.x) / 2 + min.x, (max.y - min.y) + min.y, 0)
    }
}
