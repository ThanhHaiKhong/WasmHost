//
//  auth.swift
//  WasmHost
//
//  Created by L7Studio on 1/4/25.
//
import Foundation
import CommonCrypto

class AES128CBC {
    static let key: [UInt8] = [
        191, 79, 102, 86, 31, 249, 179, 58, 15, 114, 206, 27, 5, 99, 128, 225
    ]
    
    static let iv: [UInt8] = [
        44, 228, 163, 206, 46, 29, 100, 63, 19, 84, 168, 196, 116, 0, 2, 61,
    ]
    
    /// Encrypts data using AES-128-CBC
    static func encrypt(_ plaintext: Data) -> Data? {
        return crypt(data: plaintext, key: key, iv: iv, operation: CCOperation(kCCEncrypt))
    }
    
    /// Decrypts AES-128-CBC encrypted data
    static func decrypt(_ ciphertext: Data) -> Data? {
        return crypt(data: ciphertext, key: key, iv: iv, operation: CCOperation(kCCDecrypt))
    }
    
    /// AES-128-CBC Encryption/Decryption Core Function
    private static func crypt(data: Data, key: [UInt8], iv: [UInt8], operation: CCOperation) -> Data? {
        var outLength = Int(0)
        let outData = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count + kCCBlockSizeAES128)
        defer { outData.deallocate() }
        
        let status = CCCrypt(
            operation,
            CCAlgorithm(kCCAlgorithmAES),
            CCOptions(kCCOptionPKCS7Padding), // Ensure CBC mode with padding
            key, kCCKeySizeAES128,
            iv,
            (data as NSData).bytes, data.count,
            outData, data.count + kCCBlockSizeAES128,
            &outLength
        )
        
        return status == kCCSuccess ? Data(bytes: outData, count: outLength) : nil
    }
}
extension Data {
    init?(hex: String) {
        let len = hex.count / 2
        var data = Data(capacity: len)
        var byteChars: [CChar] = [0, 0, 0]
        var wholeByte: UInt8 = 0
        
        for i in 0..<len {
            byteChars[0] = hex.utf8CString[i * 2]
            byteChars[1] = hex.utf8CString[i * 2 + 1]
            wholeByte = UInt8(strtoul(byteChars, nil, 16))
            data.append(wholeByte)
        }
        self = data
    }
}

func auth_decipher_from_hex(value: Data) -> Data {
    guard let hex = String(data: value, encoding: .utf8), let data = Data(hex: hex) else { fatalError() }
    return AES128CBC.decrypt(data) ?? Data()
}
func auth_cipher_to_hex(value: Data) -> Data {
    guard let encrypted = AES128CBC.encrypt(value) else { return Data() }
    return encrypted.map { String(format: "%02X", $0) }.joined().data(using: .utf8) ?? Data()
}
