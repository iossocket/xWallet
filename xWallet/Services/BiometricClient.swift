//
//  BiometricClient.swift
//  xWallet
//
//  Created by Xueliang Zhu on 13/4/26.
//

import Foundation
import LocalAuthentication
import ComposableArchitecture

// MARK: - Types

enum BiometricType: Equatable, Sendable {
    case faceID, touchID, opticID, none
}

enum BiometricUnavailableReason: Equatable, Sendable {
    case noPasscode
    case notEnrolled
    case notAvailable
    case lockedOut
}

enum BiometricStatus: Equatable, Sendable {
    case unknown
    case available(BiometricType)
    case unavailable(BiometricUnavailableReason)
}

// MARK: - Client

struct BiometricClient {
    var checkAvailability: @Sendable () -> BiometricStatus
    var authenticate: @Sendable (_ reason: String) async throws -> Void
}

extension BiometricClient: DependencyKey {
    static var liveValue: BiometricClient {
        BiometricClient(
            checkAvailability: {
                let context = LAContext()
                var error: NSError?

                if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                    let type: BiometricType = switch context.biometryType {
                    case .faceID: .faceID
                    case .touchID: .touchID
                    case .opticID: .opticID
                    default: .none
                    }
                    if type == .none {
                        return .unavailable(.notAvailable)
                    }
                    return .available(type)
                }

                if let laError = error as? LAError {
                    switch laError.code {
                    case .passcodeNotSet: return .unavailable(.noPasscode)
                    case .biometryNotEnrolled: return .unavailable(.notEnrolled)
                    case .biometryLockout: return .unavailable(.lockedOut)
                    case .biometryNotAvailable: return .unavailable(.notAvailable)
                    default: break
                    }
                }
                return .unavailable(.notAvailable)
            },
            authenticate: { reason in
                let context = LAContext()
                var error: NSError?

                guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
                    throw error ?? LAError(.notInteractive)
                }

                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    context.evaluatePolicy(
                        .deviceOwnerAuthentication,
                        localizedReason: reason
                    ) { success, error in
                        if success {
                            continuation.resume()
                        } else {
                            continuation.resume(throwing: error ?? LAError(.authenticationFailed))
                        }
                    }
                }
            }
        )
    }

    static var testValue: BiometricClient {
        BiometricClient(
            checkAvailability: { .available(.faceID) },
            authenticate: { _ in }
        )
    }
}

extension DependencyValues {
    var biometricClient: BiometricClient {
        get { self[BiometricClient.self] }
        set { self[BiometricClient.self] = newValue }
    }
}
