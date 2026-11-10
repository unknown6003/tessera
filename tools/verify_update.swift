import Foundation
import CryptoKit

// Sparkle signs the archive bytes with Ed25519. Only public data enters here.
guard CommandLine.arguments.count == 4,
      let publicData = Data(base64Encoded: CommandLine.arguments[2]), publicData.count == 32,
      let signature = Data(base64Encoded: CommandLine.arguments[3]), signature.count == 64 else {
    fputs("Invalid public update verification arguments\n", stderr)
    exit(2)
}
do {
    let key = try Curve25519.Signing.PublicKey(rawRepresentation: publicData)
    let archive = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]), options: .mappedIfSafe)
    guard key.isValidSignature(signature, for: archive) else {
        fputs("Update Ed25519 signature does not match source public key\n", stderr)
        exit(1)
    }
    print("Update Ed25519 signature verified against source public key")
} catch {
    fputs("Update public signature verification failed\n", stderr)
    exit(1)
}
