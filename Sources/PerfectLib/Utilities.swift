//
//  Utilities.swift
//  PerfectLib
//
//  Created by Kyle Jessup on 7/17/15.
//	Copyright (C) 2015 PerfectlySoft, Inc.
//
//===----------------------------------------------------------------------===//
//
// This source file is part of the Perfect.org open source project
//
// Copyright (c) 2015 - 2016 PerfectlySoft Inc. and the Perfect project authors
// Licensed under Apache License v2.0
//
// See http://perfect.org/licensing.html for license information
//
//===----------------------------------------------------------------------===//
//

#if os(Linux)
	import LinuxBridge
#else
	import Darwin
#endif
import Foundation

/// This class permits an UnsafeMutablePointer to be used as a GeneratorType
public struct GenerateFromPointer<T> : IteratorProtocol {
	
	public typealias Element = T
	
	var count = 0
	var pos = 0
	var from: UnsafeMutablePointer<T>
	
	/// Initialize given an UnsafeMutablePointer and the number of elements pointed to.
	public init(from: UnsafeMutablePointer<T>, count: Int) {
		self.from = from
		self.count = count
	}
	
	/// Return the next element or nil if the sequence has been exhausted.
	mutating public func next() -> Element? {
		guard count > 0 else {
			return nil
		}
		count -= 1
		let result = from[pos]
		pos += 1
		return result
	}
}

/// A generalized wrapper around the Unicode codec operations.
public struct Encoding {
	
	/// Return a String given a character generator.
	public static func encode<D : UnicodeCodec, G : IteratorProtocol>(codec inCodec: D, generator: G) -> String where G.Element == D.CodeUnit {
		var encodedString = ""
		var finished: Bool = false
		var mutableDecoder = inCodec
		var mutableGenerator = generator
		repeat {
			let decodingResult = mutableDecoder.decode(&mutableGenerator)
			switch decodingResult {
			case .scalarValue(let char):
				encodedString.append(String(char))
			case .emptyInput:
				finished = true
				/* ignore errors and unexpected values */
			case .error:
				finished = true
			}
		} while !finished
		return encodedString
	}
}

/// Utility wrapper permitting a UTF-8 character generator to encode a String. Also permits a String to be converted into a UTF-8 byte array.
public struct UTF8Encoding {
	
	/// Use a character generator to create a String.
	public static func encode<G : IteratorProtocol>(generator gen: G) -> String where G.Element == UTF8.CodeUnit {
		return Encoding.encode(codec: UTF8(), generator: gen)
	}
	
	/// Use a character sequence to create a String.
	public static func encode<S : Sequence>(bytes byts: S) -> String where S.Iterator.Element == UTF8.CodeUnit {
		return encode(generator: byts.makeIterator())
	}
	
	/// Use a character sequence to create a String.
	public static func encode(bytes byts: [UTF8.CodeUnit]) -> String {
		return encode(generator: byts.makeIterator())
	}
	
	/// Decode a String into an array of UInt8.
	public static func decode(string str: String) -> Array<UInt8> {
		return [UInt8](str.utf8)
	}
}

extension UInt8 {
	var shouldURLEncode: Bool {
		let cc = self
		return ( ( cc >= 128 )
			|| ( cc < 33 )
			|| ( cc >= 34  && cc < 38 )
			|| ( ( cc > 59  && cc < 61) || cc == 62 || cc == 58)
			|| ( ( cc >= 91  && cc < 95 ) || cc == 96 )
			|| ( cc >= 123 && cc <= 126 )
			|| self == 43 )
	}
	
	// same as String(self, radix: 16)
	// but outputs two characters. i.e. 0 padded
	var hexString: String {
		var s = ""
		let b = self >> 4
		s.append(String(Character(UnicodeScalar(b > 9 ? b - 10 + 65 : b + 48))))
		let b2 = self & 0x0F
		s.append(String(Character(UnicodeScalar(b2 > 9 ? b2 - 10 + 65 : b2 + 48))))
		return s
	}
}

extension String {
	/// Returns the String with all special HTML characters encoded.
	public var stringByEncodingHTML: String {
		var ret = ""
		var g = unicodeScalars.makeIterator()
		var lastWasCR = false
		while let c = g.next() {
			if c == UnicodeScalar(10) {
				if lastWasCR {
					lastWasCR = false
					ret.append("\n")
				} else {
					ret.append("<br>\n")
				}
				continue
			} else if c == UnicodeScalar(13) {
				lastWasCR = true
				ret.append("<br>\r")
				continue
			}
			lastWasCR = false
			if c < UnicodeScalar(0x0009) {
				if let scale = UnicodeScalar(0x0030 + UInt32(c)) {
					ret.append("&#x")
					ret.append(String(Character(scale)))
					ret.append(";")
				}
			} else if c == UnicodeScalar(0x0022) {
				ret.append("&quot;")
			} else if c == UnicodeScalar(0x0026) {
				ret.append("&amp;")
			} else if c == UnicodeScalar(0x0027) {
				ret.append("&#39;")
			} else if c == UnicodeScalar(0x003C) {
				ret.append("&lt;")
			} else if c == UnicodeScalar(0x003E) {
				ret.append("&gt;")
			} else if c > UnicodeScalar(126) {
				ret.append("&#\(UInt32(c));")
			} else {
				ret.append(String(Character(c)))
			}
		}
		return ret
	}
	
	/// Returns the String with all special URL characters encoded.
	public var stringByEncodingURL: String {
		var ret = ""
		var g = utf8.makeIterator()
		while let c = g.next() {
			if c.shouldURLEncode {
				ret.append(String(Character(UnicodeScalar(37))))
				ret.append(c.hexString)
			} else {
				ret.append(String(Character(UnicodeScalar(c))))
			}
		}
		return ret
	}
	
	// Utility - not sure if it makes the most sense to have here or outside or elsewhere
	static func byteFromHexDigits(one c1v: UInt8, two c2v: UInt8) -> UInt8? {
		
		let capA: UInt8 = 65
		let capF: UInt8 = 70
		let lowA: UInt8 = 97
		let lowF: UInt8 = 102
		let zero: UInt8 = 48
		let nine: UInt8 = 57
		
		var newChar = UInt8(0)
		
		if c1v >= capA && c1v <= capF {
			newChar = c1v - capA + 10
		} else if c1v >= lowA && c1v <= lowF {
			newChar = c1v - lowA + 10
		} else if c1v >= zero && c1v <= nine {
			newChar = c1v - zero
		} else {
			return nil
		}
		
		newChar *= 16
		
		if c2v >= capA && c2v <= capF {
			newChar += c2v - capA + 10
		} else if c2v >= lowA && c2v <= lowF {
			newChar += c2v - lowA + 10
		} else if c2v >= zero && c2v <= nine {
			newChar += c2v - zero
		} else {
			return nil
		}
		return newChar
	}
	
	/// Decode the % encoded characters in a URL and return result
	public var stringByDecodingURL: String? {
		let percent: UInt8 = 37
		let plus: UInt8 = 43
		let space: UInt8 = 32
		var bytesArray = [UInt8]()
		var g = utf8.makeIterator()
		while let c = g.next() {
			if c == percent {
				guard let c1v = g.next() else {
					return nil
				}
				guard let c2v = g.next() else {
					return nil
				}
				guard let newChar = String.byteFromHexDigits(one: c1v, two: c2v) else {
					return nil
				}
				bytesArray.append(newChar)
			} else if c == plus {
				bytesArray.append(space)
			} else {
				bytesArray.append(c)
			}
		}
		bytesArray.append(0)
		return UnsafePointer(bytesArray).withMemoryRebound(to: Int8.self, capacity: bytesArray.count) {
			return String(validatingUTF8: $0)
		}
	}
	
	/// Decode a hex string into resulting byte array
	public var decodeHex: [UInt8]? {
		
		var bytesArray = [UInt8]()
		var g = utf8.makeIterator()
		while let c1v = g.next() {
			
			guard let c2v = g.next() else {
				return nil
			}
			
			guard let newChar = String.byteFromHexDigits(one: c1v, two: c2v) else {
				return nil
			}
			
			bytesArray.append(newChar)
		}
		return bytesArray
	}
}

extension String {
	
	/// Parse an HTTP Digest authentication header returning a Dictionary containing each part.
	public func parseAuthentication() -> [String:String] {
		var ret = [String:String]()
		if let _ = range(of: "Digest ") {
			ret["type"] = "Digest"
			let wantFields = ["username", "nonce", "nc", "cnonce", "response", "uri", "realm", "qop", "algorithm"]
			for field in wantFields {
				if let foundField = String.extractField(from: self, named: field) {
					ret[field] = foundField
				}
			}
		}
		return ret
	}
	
	private static func extractField(from frm: String, named: String) -> String? {
		guard let range = frm.range(of: named + "=") else {
			return nil
		}
		
		var currPos = range.upperBound
		var ret = ""
		let quoted = frm[currPos] == "\""
		if quoted {
			currPos = frm.index(after: currPos)
			let tooFar = frm.endIndex
			while currPos != tooFar {
				if frm[currPos] == "\"" {
					break
				}
				ret.append(frm[currPos])
				currPos = frm.index(after: currPos)
			}
		} else {
			let tooFar = frm.endIndex
			while currPos != tooFar {
				if frm[currPos] == "," {
					break
				}
				ret.append(frm[currPos])
				currPos = frm.index(after: currPos)
			}
		}
		return ret
	}
}

extension String {
	
	/// Replace all occurrences of `string` with `withString`.
	public func stringByReplacing(string strng: String, withString: String) -> String {
		
		guard !strng.isEmpty else {
			return self
		}
		guard !isEmpty else {
			return self
		}
		
		var ret = ""
		var idx = startIndex
		let endIdx = endIndex
		
		while idx != endIdx {
			if self[idx] == strng[strng.startIndex] {
				var newIdx = index(after: idx)
				var findIdx = strng.index(after: strng.startIndex)
				let findEndIdx = strng.endIndex
				
				while newIdx != endIndex && findIdx != findEndIdx && self[newIdx] == strng[findIdx] {
					newIdx = index(after: newIdx)
					findIdx = strng.index(after: findIdx)
				}
				
				if findIdx == findEndIdx { // match
					ret.append(withString)
					idx = newIdx
					continue
				}
			}
			ret.append(self[idx])
			idx = index(after: idx)
		}
		
		return ret
	}
	
	// For compatibility due to shifting swift
	public func contains(string: String) -> Bool {
		return nil != range(of: string)
	}
}

extension String {
	func begins(with str: String) -> Bool {
		return starts(with: str)
	}
	
	func ends(with str: String) -> Bool {
		guard count >= str.count else {
			return false
		}
		return str.begins(with: String(self[index(endIndex, offsetBy: -str.count)..<endIndex]))
	}
}

/// Returns the current time according to ICU
/// ICU dates are the number of milliseconds since the reference date of Thu, 01-Jan-1970 00:00:00 GMT
public func getNow() -> Double {
	
	var posixTime = timeval()
	gettimeofday(&posixTime, nil)
	return Double((posixTime.tv_sec * 1000) + (Int(posixTime.tv_usec)/1000))
}
/// Converts the milliseconds based ICU date to seconds since the epoch
public func icuDateToSeconds(_ icuDate: Double) -> Int {
	return Int(icuDate / 1000)
}
/// Converts the seconds since the epoch into the milliseconds based ICU date
public func secondsToICUDate(_ seconds: Int) -> Double {
	return Double(seconds * 1000)
}

/// Format a date value according to the indicated format string and return a date string.
/// - parameter date: The date value
/// - parameter format: The format by which the date will be formatted. Use a valid strftime style format string.
/// - parameter timezone: The optional timezone in which the date is expected to be based. Default is the local timezone.
/// - parameter locale: The optional locale which will be used when parsing the date. Default is the current global locale.
/// - returns: The resulting date string
/// - throws: `PerfectError.systemError`
public func formatDate(_ date: Double, format: String, timezone inTimezone: String? = nil, locale inLocale: String? = nil) throws -> String {
	
	var t = tm()
	var time = time_t(date / 1000.0)
	gmtime_r(&time, &t)
	let maxResults = 1024
	let results = UnsafeMutablePointer<Int8>.allocate(capacity:  maxResults)
	defer {
		results.deallocate()
	}
	let res = strftime(results, maxResults, format, &t)
	if res > 0 {
		let formatted = String(validatingUTF8: results)
		return formatted!
	}
	try ThrowSystemError()
}

extension UnicodeScalar {
	
	/// Returns true if the UnicodeScalar is a white space character
	public func isWhiteSpace() -> Bool {
		return isspace(Int32(value)) != 0
	}
	/// Returns true if the UnicodeScalar is a digit character
	public func isDigit() -> Bool {
		return isdigit(Int32(value)) != 0
	}
	/// Returns true if the UnicodeScalar is an alpha-numeric character
	public func isAlphaNum() -> Bool {
		return isalnum(Int32(value)) != 0
	}
	/// Returns true if the UnicodeScalar is a hexadecimal character
	public func isHexDigit() -> Bool {
		if isDigit() {
			return true
		}
		switch self {
		case "A", "B", "C", "D", "E", "F", "a", "b", "c", "d", "e", "f":
			return true
		default:
			return false
		}
	}
}

extension String {
	
	var filePathSeparator: UnicodeScalar {
		return UnicodeScalar(47)
	}
	
	var fileExtensionSeparator: UnicodeScalar {
		return UnicodeScalar(46)
	}
	
	public var beginsWithFilePathSeparator: Bool {
		guard count > 0 else {
			return false
		}
		return self[startIndex] == Character(filePathSeparator)
	}
	
	public var endsWithFilePathSeparator: Bool {
		guard count > 0 else {
			return false
		}
		return self[index(before: endIndex)] == Character(filePathSeparator)
	}
	
	private func filePathComponents(addFirstLast addfl: Bool) -> [String] {
		var r = [String]()
		guard count > 0 else {
			return r
		}
		let fsc = Character(filePathSeparator)
		let beginSlash = self[startIndex] == fsc
		if addfl && beginSlash {
			r.append(String(filePathSeparator))
		}
		
		r.append(contentsOf: split(separator: fsc).map { String($0) })
		
		if addfl && self[index(before: endIndex)] == fsc {
			if !beginSlash || r.count > 1 {
				r.append(String(filePathSeparator))
			}
		}
		return r
	}
	
	public var filePathComponents: [String] {
		return filePathComponents(addFirstLast: true)
	}
	
	public var lastFilePathComponent: String {
		let last = filePathComponents(addFirstLast: false).last ?? ""
		if last.isEmpty && first == Character(filePathSeparator) {
			return String(filePathSeparator)
		}
		return last
	}
	
	public var deletingLastFilePathComponent: String {
		var comps = filePathComponents(addFirstLast: false)
		guard comps.count > 1 else {
			if beginsWithFilePathSeparator {
				return String(filePathSeparator)
			}
			return ""
		}
		comps.removeLast()
		let joined = comps.joined(separator: String(filePathSeparator))
		if beginsWithFilePathSeparator {
			return String(filePathSeparator) + joined
		}
		return joined
	}
	
	private func lastPathSeparator(in unis: String) -> String.Index {
		let startIndex = unis.startIndex
		var endIndex = unis.endIndex
		while endIndex != startIndex {
			if unis[unis.index(before: endIndex)] != Character(filePathSeparator) {
				break
			}
			endIndex = unis.index(before: endIndex)
		}
		return endIndex
	}
	
	private func lastExtensionSeparator(in unis: String, endIndex: String.Index) -> String.Index {
		var endIndex = endIndex
		while endIndex != startIndex {
			endIndex = unis.index(before: endIndex)
			if unis[endIndex] == Character(fileExtensionSeparator) {
				break
			}
		}
		return endIndex
	}
	
	public var deletingFileExtension: String {
		var endIndex = lastPathSeparator(in: self)
		let noTrailsIndex = endIndex
		endIndex = lastExtensionSeparator(in: self, endIndex: endIndex)
		guard endIndex != startIndex else {
			if noTrailsIndex == startIndex {
				return self
			}
			return String(self[startIndex..<noTrailsIndex])
		}
		return String(self[startIndex..<endIndex])
	}
	
	public var filePathExtension: String {
		var endIndex = lastPathSeparator(in: self)
		let noTrailsIndex = endIndex
		endIndex = lastExtensionSeparator(in: self, endIndex: endIndex)
		guard endIndex != startIndex else {
			return ""
		}
		return String(self[index(after: endIndex)..<noTrailsIndex])
	}
	
	public var resolvingSymlinksInFilePath: String {
		return File(self).realPath
	}
}
