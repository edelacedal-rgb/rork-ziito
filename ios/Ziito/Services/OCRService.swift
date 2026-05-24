import Foundation
import Vision
import UIKit

enum OCRError: Error {
    case failedToCreateRequest
    case recognitionFailed
    case noTextFound
}

@MainActor
final class OCRService {
    static let shared = OCRService()

    private init() {}

    func recognizeText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.recognitionFailed
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["es", "en"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                    guard let observations = request.results else {
                        continuation.resume(throwing: OCRError.noTextFound)
                        return
                    }

                    let text = observations
                        .compactMap { $0.topCandidates(1).first?.string }
                        .joined(separator: "\n")

                    if text.isEmpty {
                        continuation.resume(throwing: OCRError.noTextFound)
                    } else {
                        continuation.resume(returning: text)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
