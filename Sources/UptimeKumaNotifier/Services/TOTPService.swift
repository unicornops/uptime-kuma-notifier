import CryptoKit
import Foundation

enum TOTPService {
    /// Generate a 6-digit TOTP code from a base32-encoded secret.
    /// Uses SHA1, 30-second time step, 6-digit output per RFC 6238.
    static func generateCode(secret: String, time: Date = Date()) -> String? {
        guard let keyData = base32Decode(secret) else { return nil }

        let timeInterval = UInt64(time.timeIntervalSince1970) / 30
        var counter = timeInterval.bigEndian

        let counterData = withUnsafeBytes(of: &counter) { Data($0) }
        let key = SymmetricKey(data: keyData)
        let hmac = HMAC<Insecure.SHA1>.authenticationCode(for: counterData, using: key)
        let hmacBytes = Array(hmac)

        let offset = Int(hmacBytes[hmacBytes.count - 1] & 0x0F)
        let truncated =
            (UInt32(hmacBytes[offset]) & 0x7F) << 24
            | UInt32(hmacBytes[offset + 1]) << 16
            | UInt32(hmacBytes[offset + 2]) << 8
            | UInt32(hmacBytes[offset + 3])

        let code = truncated % 1_000_000
        return String(format: "%06d", code)
    }

    // MARK: - Base32 Decoding

    private static let base32Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"

    private static func base32Decode(_ input: String) -> Data? {
        let cleaned = input.uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "=", with: "")

        guard !cleaned.isEmpty else { return nil }

        var bits = 0
        var accumulator = 0
        var output = Data()

        for char in cleaned {
            guard let index = base32Alphabet.firstIndex(of: char) else { return nil }
            let value = base32Alphabet.distance(from: base32Alphabet.startIndex, to: index)
            accumulator = (accumulator << 5) | value
            bits += 5

            if bits >= 8 {
                bits -= 8
                output.append(UInt8((accumulator >> bits) & 0xFF))
            }
        }

        return output
    }
}
