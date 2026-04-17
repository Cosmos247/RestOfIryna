//
//  HummingbirdTGClient.swift
//  RestOfIryna
//
//  Created by Maxim Lanskoy on 13.06.2025.
//  Maintained by Dmytro Ihnatyuhin from 17.04.2026.
//

import Foundation
import AsyncHTTPClient
import NIOCore
import NIOFoundationCompat
import Logging
import SwiftTelegramBot

private struct TGEmptyParams: Encodable {}

/// AsyncHTTPClient-based TGClient for use with Hummingbird.
/// Lightweight HTTP client that integrates with Swift NIO.
public final class HummingbirdTGClient: TGClientPrtcl, Sendable {

    public typealias HTTPMediaType = SwiftTelegramBot.HTTPMediaType

    private let httpClient: HTTPClient
    private let logger: Logger

    public init(httpClient: HTTPClient, logger: Logger = .init(label: "HummingbirdTGClient")) {
        self.httpClient = httpClient
        self.logger = logger
    }

    @discardableResult
    public func post<Params: Encodable, Response: Decodable>(
        _ url: URL,
        params: Params? = nil,
        as mediaType: HTTPMediaType? = nil
    ) async throws -> Response {
        var request = HTTPClientRequest(url: url.absoluteString)
        request.method = .POST

        if mediaType == .formData || mediaType == nil {
            let rawMultipart: (body: NSMutableData, boundary: String)
            if let currentParams: Params = params {
                rawMultipart = try currentParams.toMultiPartFormData(log: logger)
            } else {
                rawMultipart = try TGEmptyParams().toMultiPartFormData(log: logger)
            }
            request.headers.add(name: "Content-Type", value: "multipart/form-data; boundary=\(rawMultipart.boundary)")
            request.body = .bytes(ByteBuffer(data: rawMultipart.body as Data))
        } else {
            // JSON encoding - SDK types have their own CodingKeys for snake_case
            let data = try JSONEncoder().encode(params ?? (TGEmptyParams() as! Params))
            request.headers.add(name: "Content-Type", value: "application/json")
            request.body = .bytes(ByteBuffer(data: data))
        }

        let response = try await httpClient.execute(request, timeout: .seconds(30))
        let body = try await response.body.collect(upTo: 10 * 1024 * 1024) // 10MB limit

        // Don't use convertFromSnakeCase - SwiftTelegramBot types have their own CodingKeys
        let telegramContainer = try JSONDecoder().decode(TGTelegramContainer<Response>.self, from: body)
        return try processContainer(telegramContainer)
    }

    @discardableResult
    public func post<Response: Decodable>(_ url: URL) async throws -> Response {
        try await post(url, params: TGEmptyParams(), as: nil)
    }

    private func processContainer<T: Decodable>(_ container: TGTelegramContainer<T>) throws -> T {
        guard container.ok else {
            let desc = """
            Response marked as `not Ok`, it seems something wrong with request
            Code: \(container.errorCode ?? -1)
            \(container.description ?? "Empty")
            """
            let error = BotError(type: .server, description: desc)
            logger.error("\(error)")
            throw error
        }

        guard let result = container.result else {
            let error = BotError(
                type: .server,
                reason: "Response marked as `Ok`, but doesn't contain `result` field."
            )
            logger.error("\(error)")
            throw error
        }

        logger.trace("""
        Response:
        Code: \(container.errorCode ?? 0)
        Status OK: \(container.ok)
        Description: \(container.description ?? "Empty")
        """)

        return result
    }
}
