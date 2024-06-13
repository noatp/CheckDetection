//
//  TextRecognitionViewController.swift
//  BreakfastFinder
//
//  Created by Toan Pham on 6/6/24.
//  Copyright © 2024 Apple. All rights reserved.
//

import UIKit
import Vision

class TextRecognitionViewController: UIViewController {
    private var extractedText: [String] = []
    
    var capturedImage: UIImage
    
    init(capturedImage: UIImage) {
        self.capturedImage = capturedImage
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private let label: UILabel = {
        let label = UILabel()
        label.text = ""
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .black
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setUpViews()
        // Do any additional setup after loading the view.
        performTextRecognition(on: capturedImage)
    }
    
    private func setUpViews() {
        view.backgroundColor = .white.withAlphaComponent(0.5)
        view.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            label.topAnchor.constraint(equalTo: view.topAnchor),
            label.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    func performTextRecognition(on image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let textRecognitionRequest = VNRecognizeTextRequest { [weak self] (request, error) in
            if let error = error {
                print("Error recognizing text: \(error)")
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            
            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first else { continue }
                print("Recognized text: \(topCandidate.string)")
                DispatchQueue.main.async {
                    self?.label.text?.append("Recognized text: \(topCandidate.string)\n")
                }
            }
        }
        
        textRecognitionRequest.recognitionLevel = .accurate
        
        do {
            try requestHandler.perform([textRecognitionRequest])
        } catch {
            print("Failed to perform text recognition: \(error)")
        }
    }
    
    func findAmount(in text: String) -> String? {
            // Define a regular expression pattern to match amounts
            let pattern = "(?<=\\bAmount:?\\s?)\\d{1,3}(?:,\\d{3})*(?:\\.\\d{2})?|\\d{1,3}(?:,\\d{3})*(?:\\.\\d{2})?(?=\\s*Amount\\b)|\\d{1,3}(?:,\\d{3})*(?:\\.\\d{2})?"
            
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
                
                for match in matches {
                    if let range = Range(match.range, in: text) {
                        return String(text[range])
                    }
                }
            } catch {
                print("Failed to create regular expression: \(error)")
            }
            
            return nil
        }
}
