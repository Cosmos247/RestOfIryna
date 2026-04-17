//
//  Arguments.swift
//  RestOfIryna
//
//  Created by Maxim Lanskoy on 13.06.2025.
//  Maintained by Dmytro Ihnatyuhin from 17.04.2026.
//

import Foundation

public class Arguments {
	typealias T = Arguments
	
	public let scanner: Scanner
	
	public var isAtEnd: Bool {
		return scanner.isAtEnd
	}

	static let whitespaceAndNewline = CharacterSet.whitespacesAndNewlines
	
	init(scanner: Scanner) {
		self.scanner = scanner
	}
	
	public func scanWord() -> String? {
        return scanner.scanUpToCharacters(from: T.whitespaceAndNewline)
	}
	
	public func scanWords() -> [String] {
		var words = [String]()
		while let word = scanWord() {
			words.append(word)
		}
		return words
	}
	
	public func scanInteger() -> Int? {
		guard let word = scanWord() else {
			return nil
		}
		let validator = Scanner(string: word)
		validator.charactersToBeSkipped = nil
		guard let value = validator.scanInt(), validator.isAtEnd else {
			return nil
		}
		return value
	}
	
    public func scanInt64() -> Int64? {
        guard let word = scanWord() else {
            return nil
        }
        let validator = Scanner(string: word)
        validator.charactersToBeSkipped = nil
        guard let value = validator.scanInt64(), validator.isAtEnd else {
            return nil
        }
        return value
    }
    
	public func scanDouble() -> Double? {
		guard let word = scanWord() else {
			return nil
		}
		let validator = Scanner(string: word)
		validator.charactersToBeSkipped = nil
		guard let value = validator.scanDouble(), validator.isAtEnd else {
			return nil
		}
		return value
	}
	
	public func scanRestOfString() -> String {
		guard let restOfString = scanner.scanUpToString("") else {
			return ""
		}
		return restOfString
	}
	
	public func skipRestOfString() {
		scanner.skipUpTo("")
	}
}

public extension Scanner {
    func skipping(_ characters: CharacterSet?, closure: () throws->()) rethrows {
        let previous = charactersToBeSkipped
        defer { charactersToBeSkipped = previous }
        charactersToBeSkipped = characters
        try closure()
    }
    
    @discardableResult
    func skipInt() -> Bool {
        return scanInt() != nil
    }

    @discardableResult
    func skipInt64() -> Bool {
        return scanInt64() != nil
    }
    
    @discardableResult
    func skipUInt64() -> Bool {
        return scanUInt64() != nil
    }
    
    @discardableResult
    func skipFloat() -> Bool {
        return scanFloat() != nil
    }
    
    @discardableResult
    func skipDouble() -> Bool {
        return scanDouble() != nil
    }
    
    // @discardableResult
    // func skipHexUInt64() -> Bool {
    //     return scanHexUInt64() != nil
    // }
    //
    // @discardableResult
    // func skipHexFloat() -> Bool {
    //     return scanHexFloat() != nil
    // }
    //
    // @discardableResult
    // func skipHexDouble() -> Bool {
    //     return scanHexDouble() != nil
    // }

    @discardableResult
    func skipString(_ string: String) -> Bool {
        #if true
        return scanString(string) != nil
        #else
        let utf16 = self.string.utf16
        let startOffset = skippingCharacters(startingAt: scanLocation, in: utf16)
        let toSkip = string.utf16
        let toSkipCount = toSkip.count
        let fromIndex = utf16.index(utf16.startIndex, offsetBy: startOffset)
        if let toIndex = utf16.index(fromIndex, offsetBy: toSkipCount, limitedBy: utf16.endIndex),
                utf16[fromIndex..<toIndex].elementsEqual(toSkip) {
            scanLocation = toIndex.encodedOffset
            return true
        }
        return false
        #endif
    }

    @discardableResult
    func skipCharacters(from: CharacterSet) -> Bool {
        return scanCharacters(from: from) != nil
    }
    
    @discardableResult
    func skipUpTo(_ string: String) -> Bool {
        return scanUpToString(string) != nil
    }

    @discardableResult
    func skipUpToCharacters(from set: CharacterSet) -> Bool {
        return scanUpToCharacters(from: set) != nil
    }

    func peekUtf16CodeUnit() -> UTF16.CodeUnit? {
        let originalScanLocation = currentIndex
        let scanLocation = string.distance(from: string.startIndex, to: originalScanLocation)
        defer { self.currentIndex = originalScanLocation }
        
        let originalCharactersToBeSkipped = charactersToBeSkipped
        defer { charactersToBeSkipped = originalCharactersToBeSkipped }
        
        if let characters = charactersToBeSkipped {
            charactersToBeSkipped = nil
            let _ = scanCharacters(from: characters)
        }
        
        guard scanLocation < string.utf16.count else { return nil }
        let index = string.utf16.index(string.utf16.startIndex, offsetBy: scanLocation)
        return string.utf16[index]
    }
    
    var scanLocationInCharacters: Int {
        let utf16 = string.utf16
        let scanLocation = string.distance(from: string.startIndex, to: currentIndex)
        guard let to16 = utf16.index(utf16.startIndex, offsetBy: scanLocation, limitedBy: utf16.endIndex),
            let to = String.Index(to16, within: string) else {
                return 0
        }
        return string.distance(from: string.startIndex, to: to)
    }
    
    private var currentCharacterIndex: String.Index? {
        let utf16 = string.utf16
        let scanLocation = string.distance(from: string.startIndex, to: currentIndex)
        guard let to16 = utf16.index(utf16.startIndex, offsetBy: scanLocation, limitedBy: utf16.endIndex),
            let to = String.Index(to16, within: string) else {
                return nil
        }
        // to is a String.CharacterView.Index
        return to
    }
    
    var parsedText: Substring {
        guard let index = currentCharacterIndex else { return "" }
        return string[..<index]
    }

    var textToParse: Substring {
        guard let index = currentCharacterIndex else { return "" }
        return string[index...]
    }
    
    var lineBeingParsed: String {
        let targetLine = self.line()
        var currentLine = 1
        var line = ""
        line.reserveCapacity(256)
        for character in string {
            if currentLine > targetLine {
                break
            }
            
            if character == "\n" || character == "\r\n" {
                currentLine += 1
                continue
            }
            
            if currentLine == targetLine {
                line.append(character)
            }
        }
        return line
    }

    /// Very slow, do not in use in loops
    func line() -> Int {
        var newLinesCount = 0
        parsedText.forEach {
            if $0 == "\n" || $0 == "\r\n" {
                newLinesCount += 1
            }
        }
        return 1 + newLinesCount
    }
    
    /// Very slow, do not in use in loops
    func column() -> Int {
        let text = parsedText
        if let range = text.range(of: "\n", options: .backwards) {
            return text.distance(from: range.upperBound, to: text.endIndex) + 1
        }
        return parsedText.count + 1
    }

    #if fålse
    private func skippingCharacters(startingAt: Int, in utf16: String.UTF16View) -> Int {
        guard let charactersToBeSkipped = charactersToBeSkipped else { return startingAt }
        let fromIndex = utf16.index(utf16.startIndex, offsetBy: startingAt)
        var newLocation = startingAt
        for c in utf16[fromIndex...] {
            guard let scalar = UnicodeScalar(c) else { break }
            guard charactersToBeSkipped.contains(scalar) else { break }
            newLocation += 1
        }
        return newLocation
    }
    #endif
}

