//
//  HttpClient.swift
//  InnerAI
//
//  Created by Bassam Fouad on 05/05/2024.
//

import Foundation

protocol HttpClient {
    func execute<T: Decodable>(request: Request, headers: [String: Any]?, completion: @escaping (Result<T, NetworkError>) -> Void)
}

enum HttpMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
}

enum NetworkError: Error {
    case unAuthorized
    case notFound
    case accountExpired
    case invalidData
}

struct HttpClientImplementation: HttpClient {

    func execute<T: Decodable>(request: Request, headers: [String: Any]?, completion: @escaping (Result<T, NetworkError>) -> Void) {

        guard let url = URL(string: request.endpoint) else {
            completion(.failure(.invalidData))
            return
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.httpMethod.rawValue
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        headers?.forEach({ key, value in
            urlRequest.addValue(value as? String ?? "", forHTTPHeaderField: key)
        })
        
        print(" --------- REQUEST --------- ")
        print("\(request)")

        // If params are provided, encode them as JSON and set the HTTP body
        if let params = request.params {
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: params, options: [])
                urlRequest.httpBody = jsonData
            } catch {
                completion(.failure(.invalidData))
                return
            }
        }

        let task = URLSession.shared.dataTask(with: urlRequest) { (data, response, error) in

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.notFound))
                return
            }
            
            print(" --------- RESPONSE --------- ")
            print("\(httpResponse)")

            if httpResponse.statusCode == 401 {
                completion(.failure(.unAuthorized))
            }

            if error != nil {
                completion(.failure(.notFound))
                return
            }

            guard let data = data else {
                completion(.failure(.notFound))
                return
            }
            
            print(" --------- YES! 😊 --------- ")
            
            do {
                let decodedData = try JSONDecoder().decode(T.self, from: data)
                completion(.success(decodedData))
            } catch {
                completion(.failure(.invalidData))
            }
        }
        task.resume()
    }
}
