//
//  Router+Helpers.swift
//  RestOfIryna
//
//  Created by Maxim Lanskoy on 13.06.2025.
//  Maintained by Dmytro Ihnatyuhin from 17.04.2026.
//

import Foundation

extension Router {
	// add() taking string
	public func add(_ commandString: String, _ options: Command.Options = [], _ handler: @Sendable @escaping (Context) async throws -> Bool) {
		add(Command(commandString, options: options), handler)
	}
		
	// Subscripts taking ContentType
	
	public subscript(_ contentType: ContentType) -> Handler {
		get { fatalError("Not implemented") }
		set { add(contentType, newValue) }
	}
	
	// Subscripts taking Command
	public subscript(_ command: Command) -> Handler {
		get { fatalError("Not implemented") }
		set { add(command, newValue) }
	}

    public subscript(_ commands: [Command]) -> Handler {
        get { fatalError("Not implemented") }
        set { add(commands, newValue) }
    }
    
    public subscript(_ commands: Command...) -> Handler {
        get { fatalError("Not implemented") }
        set { add(commands, newValue) }
    }
    
	// Subscripts taking String
	public subscript(_ commandString: String, _ options: Command.Options) -> Handler {
		get { fatalError("Not implemented") }
        set { add(Command(commandString, options: options), newValue) }
	}
    
    public subscript(_ commandString: String) -> Handler {
        get { fatalError("Not implemented") }
        set { add(Command(commandString), newValue) }
    }

    public subscript(_ commandStrings: [String], _ options: Command.Options) -> Handler {
        get { fatalError("Not implemented") }
        set {
            let commands = commandStrings.map { Command($0, options: options) }
            add(commands, newValue)
        }
    }
    
    public subscript(commandStrings: [String]) -> Handler {
        get { fatalError("Not implemented") }
        set {
            let commands = commandStrings.map { Command($0) }
            add(commands, newValue)
        }
    }

    // Segmentation fault
    //    public subscript(commandStrings: String..., _ options: Command.Options) -> (Context) throws -> Bool {
    //        get { fatalError("Not implemented") }
    //        set {
    //            let commands = commandStrings.map { Command($0, options: options) }
    //            add(commands, newValue)
    //        }
    //    }

    public subscript(commandStrings: String...) -> @Sendable (Context) async throws -> Bool {
        get { fatalError("Not implemented") }
        set {
            let commands = commandStrings.map { Command($0) }
            add(commands, newValue)
        }
    }
}
