import CryptoKit
import Foundation

public struct UpdateKeyPair: Equatable, Sendable {
    public let privateKey: Data
    public let publicKey: Data
    public let keyID: String

    public init(privateKey: Data, publicKey: Data, keyID: String) {
        self.privateKey = privateKey
        self.publicKey = publicKey
        self.keyID = keyID
    }
}

public enum UpdateCrypto {
    public static func generateKeyPair() -> UpdateKeyPair {
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKey = privateKey.publicKey.rawRepresentation
        return UpdateKeyPair(
            privateKey: privateKey.rawRepresentation,
            publicKey: publicKey,
            keyID: keyID(for: publicKey)
        )
    }

    public static func keyPair(privateKey data: Data) throws -> UpdateKeyPair {
        do {
            let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: data)
            let publicKey = privateKey.publicKey.rawRepresentation
            return UpdateKeyPair(privateKey: data, publicKey: publicKey, keyID: keyID(for: publicKey))
        } catch {
            throw UpdateError.invalidKey(String(describing: error))
        }
    }

    public static func sign(_ manifest: UpdateManifest, privateKey data: Data) throws -> SignedUpdateManifest {
        let pair = try keyPair(privateKey: data)
        do {
            let key = try Curve25519.Signing.PrivateKey(rawRepresentation: pair.privateKey)
            let signature = try key.signature(for: ManifestCodec.canonicalData(manifest))
            return SignedUpdateManifest(manifest: manifest, keyID: pair.keyID, signature: signature.base64EncodedString())
        } catch let error as UpdateError {
            throw error
        } catch {
            throw UpdateError.invalidKey(String(describing: error))
        }
    }

    public static func verify(_ signed: SignedUpdateManifest, publicKey data: Data) throws {
        let expectedKeyID = keyID(for: data)
        guard signed.keyID == expectedKeyID else {
            throw UpdateError.keyIDMismatch(expected: expectedKeyID, actual: signed.keyID)
        }
        guard let signature = Data(base64Encoded: signed.signature) else {
            throw UpdateError.malformedManifest("signature is not base64")
        }
        do {
            let key = try Curve25519.Signing.PublicKey(rawRepresentation: data)
            guard key.isValidSignature(signature, for: try ManifestCodec.canonicalData(signed.manifest)) else {
                throw UpdateError.invalidSignature
            }
        } catch let error as UpdateError {
            throw error
        } catch {
            throw UpdateError.invalidKey(String(describing: error))
        }
    }

    public static func sha256(_ data: Data) -> String {
        "sha256:" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public static func keyID(for publicKey: Data) -> String {
        String(sha256(publicKey).dropFirst("sha256:".count).prefix(16))
    }
}
