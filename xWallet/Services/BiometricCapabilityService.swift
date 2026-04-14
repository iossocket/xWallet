//
//  BiometricCapabilityService.swift
//  xWallet
//
//  Created by Xueliang Zhu on 10/4/26.
//

import LocalAuthentication

struct BiometricCapabilityService {
    
    enum Availability {
        case available(LABiometryType)
        case noPasscode
        case notEnrolled
        case notAvailable
        case lockedOut
        case unknown
    }

    func check() -> Availability {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            return .available(context.biometryType)
        }

        if let laError = error as? LAError {
            switch laError.code {
            case .passcodeNotSet: return .noPasscode
            case .biometryNotEnrolled: return .notEnrolled
            case .biometryLockout: return .lockedOut
            case .biometryNotAvailable: return .notAvailable
            default: break
            }
        }
        return .unknown
    }
    
}
