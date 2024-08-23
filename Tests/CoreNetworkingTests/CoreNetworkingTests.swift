import XCTest
@testable import CoreNetworking

final class CoreNetworkingTests: XCTestCase {
    func test_successfulSimpleRequest_shouldReturnResponse() async throws {
        let fetchFact = {
            try await HTTPClient.shared
                .execute(
                    .init(
                        urlString: "https://catfact.ninja/fact/",
                        method: .get([]),
                        headers: [:]
                    ),
                    responseType: CatFact.self
                )
        }
        let service = CatFactsService(dependencies: .init(fetchFact: fetchFact))
        let fact = try await service.fetchCatFact()
        XCTAssertNotNil(fact)
    }

    func test_successfulRequestWithCustomErrorHandling_shouldReturnResultWithResponse() async throws {
        let fetchFact = {
            try await HTTPClient.shared
                .execute(
                    .init(
                        urlString: "https://catfact.ninja/fact/",
                        method: .get([]),
                        headers: [:]
                    ),
                    successResponseType: CatFact.self,
                    errorResponseType: GenericError.self
                )
        }
        let service = CatFactsService(
            dependencies: .init(
                fetchFactWithErrorHandling: fetchFact
            )
        )
        let result = try await service.fetchCatFactWithErrorHandling()
        switch result {
        case let .success(response):
            XCTAssertNotNil(response)
        case .failure, .none:
            XCTFail()
        }
    }

    func test_wrongRequestWithCustomErrorHandling_shouldReturnResultWithError() async throws {
        let fetchFact = {
            try await HTTPClient.shared
                .execute(
                    .init(
                        urlString: "https://catfact.ninja/factsss/",
                        method: .get([]),
                        headers: [:]
                    ),
                    successResponseType: CatFact.self,
                    errorResponseType: GenericError.self
                )
        }
        let service = CatFactsService(
            dependencies: .init(
                fetchFactWithErrorHandling: fetchFact
            )
        )
        let result = try await service.fetchCatFactWithErrorHandling()
        switch result {
        case .success, .none:
            XCTFail()
        case let .failure(error):
            XCTAssertNotNil(error)
        }
    }

    func test_simpleRequest_withWrongRequestType_shouldReturnDecodingError() async throws {
        let fetchFact = {
            try await HTTPClient.shared
                .execute(
                    .init(
                        urlString: "https://catfact.ninja/facts/",
                        method: .get([]),
                        headers: [:]
                    ),
                    responseType: CatFact.self
                )
        }
        let service = CatFactsService(dependencies: .init(fetchFact: fetchFact))

        do {
            _ = try await service.fetchCatFact()
            XCTFail("Should have thrown")
        } catch let Request.RequestError.decode(DecodingError.keyNotFound(key, context)?) {
            XCTAssertEqual(key.intValue, nil)
            XCTAssertEqual(key.stringValue, "fact")
            XCTAssertEqual(context.codingPath.count, 0)
            XCTAssertEqual(
                context.debugDescription,
                "No value associated with key CodingKeys(stringValue: \"fact\", intValue: nil) (\"fact\")."
            )
            XCTAssertNil(context.underlyingError)
        } catch {
            XCTFail("Should have thrown RequestError.decode error")
        }
    }

    func test_requestWithCustomErrorHandling_withWrongRequestType_shouldReturnDecodingError() async throws {
        let fetchFact = {
            try await HTTPClient.shared
                .execute(
                    .init(
                        urlString: "https://catfact.ninja/facts/",
                        method: .get([]),
                        headers: [:]
                    ),
                    successResponseType: CatFact.self,
                    errorResponseType: GenericError.self
                )
        }
        let service = CatFactsService(
            dependencies: .init(
                fetchFactWithErrorHandling: fetchFact
            )
        )

        do {
            _ = try await service.fetchCatFactWithErrorHandling()
            XCTFail("Should have thrown")
        } catch let Request.RequestError.decode(DecodingError.keyNotFound(key, context)?) {
            XCTAssertEqual(key.intValue, nil)
            XCTAssertEqual(key.stringValue, "fact")
            XCTAssertEqual(context.codingPath.count, 0)
            XCTAssertEqual(
                context.debugDescription,
                "No value associated with key CodingKeys(stringValue: \"fact\", intValue: nil) (\"fact\")."
            )
            XCTAssertNil(context.underlyingError)
        } catch {
            XCTFail("Should have thrown RequestError.decode error")
        }
    }
}

final class CatFactsService {
    private let dependencies: Dependencies

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func fetchCatFact() async throws -> CatFact? {
        try await dependencies.fetchFact?()
    }

    func fetchCatFactWithErrorHandling() async throws -> Result<CatFact, GenericError>? {
        try await dependencies.fetchFactWithErrorHandling?()
    }
}

extension CatFactsService {
    struct Dependencies {
        var fetchFact: (() async throws -> CatFact)? = nil
        var fetchFactWithErrorHandling: (() async throws -> Result<CatFact, GenericError>)? = nil
    }
}

struct CatFact: Decodable {
    let fact: String
    let length: Int
}

struct GenericError: Error, Decodable {
    let code: Int
    let message: String
}
