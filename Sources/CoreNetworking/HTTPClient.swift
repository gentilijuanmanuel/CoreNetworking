import Foundation

/// The HTTPClient class.
public class HTTPClient {
    /// The shared instance.
    public static let shared = HTTPClient()
    /// Replace the default JSONDecoder if necessary.
    public var jsonDecoder: JSONDecoder = JSONDecoder()
    /// The console logger object. Replace this logger if you need a different verbose level.
    /// By default, the object will log requests and responses information to the console.
    public var networkLogger = NetworkLogger(
        configuration: .verbose(
            logRequests: true,
            logResponses: true
        )
    )

    /// Executes a request asynchronously and returns a response, or throws an error.
    public func execute<Response: Decodable>(
        _ request: Request,
        responseType: Response.Type
    ) async throws -> Response {
        networkLogger.logRequest(request)
        let (data, response) = try await URLSession.shared.data(
            for: request.urlRequest,
            delegate: nil
        )

        guard let response = response as? HTTPURLResponse else {
            throw Request.RequestError.noResponse
        }
        networkLogger.logResponse(response, request: request)

        switch response.statusCode {
        case 200...299:
            do {
                let decodedResponse = try jsonDecoder.decode(
                    responseType,
                    from: data
                )

                networkLogger.logDecodingSuccessResponse(
                    model: decodedResponse,
                    for: responseType,
                    data: data
                )
                return decodedResponse
            } catch {
                networkLogger.logDecodingErrorResponse(
                    with: error,
                    for: responseType,
                    data: data
                )

                guard let decodingError = error as? DecodingError else {
                    throw Request.RequestError.decode()
                }

                throw Request.RequestError.decode(decodingError)
            }
        case 401:
            throw Request.RequestError.unauthorized
        default:
            throw Request.RequestError.unexpectedStatusCode
        }
    }

    /// Executes a request asynchronously and returns a result or throws an error.
    public func execute<SuccessResponse: Decodable, ErrorResponse: Decodable>(
        _ request: Request,
        successResponseType: SuccessResponse.Type,
        errorResponseType: ErrorResponse.Type
    ) async throws -> Result<SuccessResponse, ErrorResponse> {
        networkLogger.logRequest(request)
        let (data, response) = try await URLSession.shared.data(
            for: request.urlRequest,
            delegate: nil
        )

        guard let response = response as? HTTPURLResponse else {
            throw Request.RequestError.noResponse
        }
        networkLogger.logResponse(response, request: request)

        switch response.statusCode {
        case 200...299:
            do {
                let decodedResponse = try jsonDecoder.decode(
                    successResponseType,
                    from: data
                )

                networkLogger.logDecodingSuccessResponse(
                    model: decodedResponse,
                    for: successResponseType,
                    data: data
                )
                return .success(decodedResponse)
            } catch {
                networkLogger.logDecodingErrorResponse(
                    with: error,
                    for: successResponseType,
                    data: data
                )

                guard let decodingError = error as? DecodingError else {
                    throw Request.RequestError.decode()
                }

                throw Request.RequestError.decode(decodingError)
            }
        case 401:
            do {
                let decodedResponse = try jsonDecoder.decode(
                    errorResponseType,
                    from: data
                )

                return .failure(decodedResponse)
            } catch {
                throw Request.RequestError.unexpectedStatusCode
            }
        default:
            do {
                let decodedResponse = try jsonDecoder.decode(
                    errorResponseType,
                    from: data
                )

                return .failure(decodedResponse)
            } catch {
                throw Request.RequestError.unexpectedStatusCode
            }
        }
    }
}
