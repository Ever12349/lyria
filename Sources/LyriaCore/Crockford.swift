import Foundation

public enum CrockfordError: Error, Equatable {
    case invalidCharacter(Character)
}

/// Crockford Base32. 16 bytes are padded to 130 bits and the first 22 characters are kept.
public enum Crockford {
    public static let alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
    public static let encodedLength = 22

    public static func encode(_ data: Data, characters: Int = encodedLength) -> String {
        let bytes = [UInt8](data)
        var output = ""
        output.reserveCapacity(characters)
        var buffer: UInt64 = 0
        var bits = 0
        var offset = 0

        while output.count < characters {
            if bits < 5 {
                if offset < bytes.count {
                    buffer = (buffer << 8) | UInt64(bytes[offset])
                    offset += 1
                    bits += 8
                } else {
                    let need = 5 - bits
                    buffer <<= UInt64(need)
                    bits += need
                }
            }
            bits -= 5
            let index = Int((buffer >> UInt64(bits)) & 0x1F)
            buffer &= bits == 0 ? 0 : (1 << UInt64(bits)) - 1
            let character = alphabet[alphabet.index(alphabet.startIndex, offsetBy: index)]
            output.append(character)
        }
        return output
    }

    /// Decodes Crockford text. `I`/`L` map to 1, `O` maps to 0, `U` is rejected.
    public static func decode(_ text: String) throws -> Data {
        var buffer: UInt64 = 0
        var bits = 0
        var bytes: [UInt8] = []
        for character in text.uppercased() {
            let value = try symbolValue(character)
            buffer = (buffer << 5) | UInt64(value)
            bits += 5
            if bits >= 8 {
                bits -= 8
                bytes.append(UInt8((buffer >> UInt64(bits)) & 0xFF))
                buffer &= bits == 0 ? 0 : (1 << UInt64(bits)) - 1
            }
        }
        return Data(bytes)
    }

    private static func symbolValue(_ character: Character) throws -> UInt8 {
        switch character {
        case "0", "O":
            return 0
        case "1", "I", "L":
            return 1
        case "U":
            throw CrockfordError.invalidCharacter(character)
        case "2"..."9":
            return character.asciiValue! - Character("0").asciiValue!
        default:
            guard let index = alphabet.firstIndex(of: character) else {
                throw CrockfordError.invalidCharacter(character)
            }
            return UInt8(alphabet.distance(from: alphabet.startIndex, to: index))
        }
    }
}
