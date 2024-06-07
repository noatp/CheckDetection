/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 Contains the object recognition view controller for the Breakfast Finder.
 */

import UIKit
import AVFoundation
import Vision

class VisionObjectRecognitionViewController: ViewController {
    
    private var detectionOverlay: CALayer! = nil
    private var goodFrameCount: Int = 0
    private let goodFrameCountThreshold: Int = 50
    
    private var requests = [VNRequest]()
    
    func setupVision() {
        let error: NSError! = nil
        
        let objectRecognition = VNDetectRectanglesRequest { (request, error) in
            if let error = error {
                return
            }
            
            DispatchQueue.main.async {
                if let results = request.results {
                    self.drawVisionRequestResults(results)
                }
            }
        }
        objectRecognition.maximumObservations = 1
        objectRecognition.quadratureTolerance = 15
        objectRecognition.minimumAspectRatio = 0.4
        objectRecognition.maximumAspectRatio = 0.48
        objectRecognition.minimumSize = 0.45
        self.requests = [objectRecognition]
    }
    
    func drawVisionRequestResults(_ results: [Any]) {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        detectionOverlay.sublayers = nil
        guard results.count <= 1 else {
            return
        }
        
        if results.isEmpty {
            goodFrameCount = 0
        }
        else {
            guard let rectangleObservation = results[0] as? VNRectangleObservation else {
                return
            }
            goodFrameCount += 1
            print(goodFrameCount)
            let objectBounds = VNImageRectForNormalizedRect(rectangleObservation.boundingBox, Int(bufferSize.width), Int(bufferSize.height))
            let shapeLayer = self.createRoundedRectLayerWithBounds(objectBounds)
            let textLayer = self.createTextSubLayerInBounds(objectBounds,
                                                            identifier: "rectangle",
                                                            confidence: rectangleObservation.confidence)
            shapeLayer.addSublayer(textLayer)
            detectionOverlay.addSublayer(shapeLayer)
        }
        
        self.updateLayerGeometry()
        CATransaction.commit()
    }
    
    override func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let exifOrientation = exifOrientationFromDeviceOrientation()
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: [:])
        do {
            try imageRequestHandler.perform(self.requests)
            
            // Capture image when goodFrameCount reaches the threshold
            if goodFrameCount >= goodFrameCountThreshold {
                saveCurrentFrame(sampleBuffer: sampleBuffer)
                goodFrameCount = 0 // Reset the count after saving the image
            }
        } catch {
            print(error)
        }
    }
    
    override func setupAVCapture() {
        super.setupAVCapture()
        
        // setup Vision parts
        setupLayers()
        updateLayerGeometry()
        setupVision()
        
        // start the capture
        startCaptureSession()
    }
    
    func setupLayers() {
        detectionOverlay = CALayer() // container layer that has all the renderings of the observations
        detectionOverlay.name = "DetectionOverlay"
        detectionOverlay.bounds = CGRect(x: 0.0,
                                         y: 0.0,
                                         width: bufferSize.width,
                                         height: bufferSize.height)
        detectionOverlay.position = CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.midY)
        rootLayer.addSublayer(detectionOverlay)
    }
    
    func updateLayerGeometry() {
        let bounds = rootLayer.bounds
        var scale: CGFloat
        
        let xScale: CGFloat = bounds.size.width / bufferSize.height
        let yScale: CGFloat = bounds.size.height / bufferSize.width
        
        scale = fmax(xScale, yScale)
        if scale.isInfinite {
            scale = 1.0
        }
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        
        // rotate the layer into screen orientation and scale and mirror
        detectionOverlay.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: scale, y: -scale))
        // center the layer
        detectionOverlay.position = CGPoint(x: bounds.midX, y: bounds.midY)
        
        CATransaction.commit()
        
    }
    
    func createTextSubLayerInBounds(_ bounds: CGRect, identifier: String, confidence: VNConfidence) -> CATextLayer {
        let textLayer = CATextLayer()
        textLayer.name = "Object Label"
        let formattedString = NSMutableAttributedString(string: String(format: "\(identifier)\nConfidence:  %.2f", confidence))
        let largeFont = UIFont(name: "Helvetica", size: 24.0)!
        formattedString.addAttributes([NSAttributedString.Key.font: largeFont], range: NSRange(location: 0, length: identifier.count))
        textLayer.string = formattedString
        textLayer.bounds = CGRect(x: 0, y: 0, width: bounds.size.height - 10, height: bounds.size.width - 10)
        textLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        textLayer.shadowOpacity = 0.7
        textLayer.shadowOffset = CGSize(width: 2, height: 2)
        textLayer.foregroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.0, 0.0, 0.0, 1.0])
        textLayer.contentsScale = 2.0 // retina rendering
        // rotate the layer into screen orientation and scale and mirror
        textLayer.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: 1.0, y: -1.0))
        return textLayer
    }
    
    func createRoundedRectLayerWithBounds(_ bounds: CGRect) -> CALayer {
        let shapeLayer = CALayer()
        shapeLayer.bounds = bounds
        shapeLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        shapeLayer.name = "Found Object"
        shapeLayer.backgroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [1.0, 1.0, 0.2, 0.4])
        shapeLayer.cornerRadius = 7
        return shapeLayer
    }
    
    func saveCurrentFrame(sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        // Create CIImage from CVPixelBuffer
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Create a CIContext
        let context = CIContext()
        
        // Create CGImage from CIImage
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return
        }
        
        // Create UIImage from CGImage
        let uiImage = UIImage(cgImage: cgImage)
        
        
    }
}
