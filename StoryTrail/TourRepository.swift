import Foundation

protocol TourRepository: Sendable {
    func fetchTours() async throws -> [Tour]
}

struct BundledTourRepository: TourRepository {
    let resourceName: String

    init(resourceName: String = "tours") {
        self.resourceName = resourceName
    }

    func fetchTours() async throws -> [Tour] {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "json") else {
            throw TourRepositoryError.missingResource("\(resourceName).json")
        }
        return try TourDecoder.decode(data: Data(contentsOf: url))
    }
}

/// Drop-in production data source. Initialize `TourLibrary` with this repository
/// when the API is ready; views and navigation do not need to change.
struct NetworkTourRepository: TourRepository {
    let endpoint: URL
    var session: URLSession = .shared

    func fetchTours() async throws -> [Tour] {
        let (data, response) = try await session.data(from: endpoint)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw TourRepositoryError.invalidResponse
        }
        return try TourDecoder.decode(data: data)
    }
}

private enum TourDecoder {
    static func decode(data: Data) throws -> [Tour] {
        try JSONDecoder().decode(TourPayload.self, from: data).tours
    }
}

private struct TourPayload: Decodable {
    let tours: [Tour]
}

enum TourRepositoryError: LocalizedError {
    case missingResource(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingResource(let name): return "The bundled tour catalogue \(name) could not be found."
        case .invalidResponse: return "The tour service returned an invalid response."
        }
    }
}
