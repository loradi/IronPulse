import Foundation

struct WgerAPIService {
    private let baseURL = URL(string: "https://wger.de/api/v2/")!
    private let decoder: JSONDecoder
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }

    func fetchExercises(language: Int = 2, limit: Int = 150) async throws -> [WgerExercise] {
        let requestURL = try makeURL(
            path: "exercise/",
            queryItems: [
                URLQueryItem(name: "language", value: String(language)),
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "status", value: "2")
            ]
        )

        let response: WgerPaginatedResponse<WgerExercise> = try await fetch(requestURL)
        let images = try await fetchExerciseImages(limit: 300)
        let imagesByExercise = Dictionary(grouping: images, by: \WgerExerciseImage.exercise)

        return response.results.map { exercise in
            var enrichedExercise = exercise
            let image = imagesByExercise[exercise.id]?.first(where: { $0.isMain }) ?? imagesByExercise[exercise.id]?.first
            enrichedExercise.imageURL = image?.image
            return enrichedExercise
        }
        .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    func fetchExerciseImages(limit: Int = 300) async throws -> [WgerExerciseImage] {
        let requestURL = try makeURL(
            path: "exerciseimage/",
            queryItems: [URLQueryItem(name: "limit", value: String(limit))]
        )
        let response: WgerPaginatedResponse<WgerExerciseImage> = try await fetch(requestURL)
        return response.results
    }

    func fetchCategories() async throws -> [WgerExerciseCategory] {
        let requestURL = try makeURL(path: "exercisecategory/", queryItems: [])
        let response: WgerPaginatedResponse<WgerExerciseCategory> = try await fetch(requestURL)
        return response.results
    }

    func fetchMuscles() async throws -> [WgerMuscle] {
        let requestURL = try makeURL(path: "muscle/", queryItems: [])
        let response: WgerPaginatedResponse<WgerMuscle> = try await fetch(requestURL)
        return response.results
    }

    private func fetch<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw WgerAPIError.invalidResponse
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw WgerAPIError.decodingFailed(error)
        }
    }

    private func makeURL(path: String, queryItems: [URLQueryItem]) throws -> URL {
        let url = baseURL.appendingPathComponent(path)
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw WgerAPIError.invalidURL
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let finalURL = components.url else {
            throw WgerAPIError.invalidURL
        }
        return finalURL
    }
}

enum WgerAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "La URL de wger no es valida."
        case .invalidResponse:
            return "wger devolvio una respuesta invalida."
        case .decodingFailed(let error):
            return "No se pudo leer la respuesta de wger: \(error.localizedDescription)"
        }
    }
}
