//  Copyright © 2019 The nef Authors.

import Foundation
import Common
import Swiftline
import Bow
import BowEffects

struct Playground {
    private let resolvePath: ResolvePath
    
    init(packagePath: String, projectName: String, outputPath: String) {
        self.resolvePath = ResolvePath(packagePath: packagePath, projectName: projectName, outputPath: outputPath)
    }
    
    func build(cached: Bool, console: iPadConsole) -> Result<Void, PlaygroundError> {
        do {
            return try build(cached: cached, resolvePath: self.resolvePath)
                .invoke(IPadApp(console: console, storage: Storage()))^
                .performIO()
                .toResult()
        } catch {
            return .failure(.ioError)
        }
    }
    
    private func build(cached: Bool, resolvePath: ResolvePath) -> EnvIO<IPadApp, PlaygroundError, Void> {
        let modulesRaw = EnvIOPartial<IPadApp, PlaygroundError>.var([String].self)
        let modules = EnvIOPartial<IPadApp, PlaygroundError>.var([Module].self)
       
        return binding(
                       |<-self.stepCleanUp(deintegrate: !cached, resolvePath: resolvePath),
                       |<-self.stepStructure(resolvePath: resolvePath),
            modulesRaw <- self.stepChekout(resolvePath: resolvePath),
            modules    <- self.stepGetModules(fromRepositories: modulesRaw.get).contramap(\IPadApp.console),
                       |<-self.stepPlayground(modules: modules.get, resolvePath: resolvePath),
                       |<-self.stepCleanUp(deintegrate: false, resolvePath: resolvePath),
            yield: ())^
    }
    
    private func stepStructure(resolvePath: ResolvePath) -> EnvIO<IPadApp, PlaygroundError, Void> {
        return binding(
            |<-EnvIO { app in app.console.printStep(information: "Creating swift playground structure (\(resolvePath.projectName))") },
            |<-self.makeStructureAndReport(resolvePath: resolvePath),
            yield: ())^
    }
    
    private func makeStructureAndReport(resolvePath: ResolvePath) -> EnvIO<IPadApp, PlaygroundError, Void> {
        return EnvIO { app in
            self.makeStructure(projectPath: resolvePath.projectPath, buildPath: resolvePath.buildPath)
                .invoke(app.storage)
                .flatMap { flag in
                    flag ? app.console.printStatus(success: true)
                         : app.console.printStatus(success: false).followedBy(IO.raiseError(.structure))
            }
        }
    }
    
    private func stepChekout(resolvePath: ResolvePath) -> EnvIO<IPadApp, PlaygroundError, [String]> {
        let repos = EnvIOPartial<IPadApp, PlaygroundError>.var([String].self)
        
        return binding(
                  |<-EnvIO { app in app.console.printStep(information: "Downloading dependencies...") },
                  |<-self.buildAndReport(resolvePath: resolvePath),
            repos <- self.repositories(checkoutPath: resolvePath.checkoutPath),
                  |<-self.report(repositories: repos.get),
            yield: repos.get)^
    }
    
    private func buildAndReport(resolvePath: ResolvePath) -> EnvIO<IPadApp, PlaygroundError, ()> {
        return buildPackage(resolvePath.packagePath, nefPath: resolvePath.nefPath, buildPath: resolvePath.buildPath)
            .contramap(\IPadApp.storage)
            .as(())
            .handleErrorWith { error in
                EnvIO { app in
                    app.console.printStatus(success: false)
                        .followedBy(IO<PlaygroundError, ()>.raiseError(.package(packagePath: resolvePath.packagePath)))^
                }
            }^
    }
    
    private func report(repositories: [String]) -> EnvIO<iPadConsole, PlaygroundError, [String]> {
        return EnvIO { console in
            if repositories.count > 0 {
                return console.printStatus(success: true).as(repositories)
            } else {
                return console.printStatus(success: false).followedBy(IO.raiseError(.checkout))
            }
        }
    }
    
    private func stepGetModules(fromRepositories repos: [String]) -> EnvIO<iPadConsole, PlaygroundError, [Module]> {
        let modules = IOPartial<PlaygroundError>.var([Module].self)
        
        return EnvIO { console in
            binding(
                |<-console.printStep(information: "Get modules from repositories"),
                modules <- self.getSwiftLibraryModules(inRepositories: repos),
                |<-self.report(modules: modules.get).invoke(console),
                yield: modules.get)^
        }
    }
    
    private func getSwiftLibraryModules(inRepositories repos: [String]) -> [Module] {
        return repos.flatMap { repo in
            modulesInRepository(repo).filter { module in
                module.type == .library && module.moduleType == .swift
            }
        }
    }
    
    private func report(modules: [Module]) -> EnvIO<iPadConsole, PlaygroundError, [Module]> {
        return EnvIO { console in
            if modules.count > 0 {
                return binding(
                    |<-console.printStatus(success: true),
                    |<-self.printAll(modules: modules).invoke(console),
                    yield: modules)^
            } else {
                return console.printStatus(success: false)
                    .followedBy(IO.raiseError(.checkout))^
            }
        }
    }
    
    private func printAll(modules: [Module]) -> EnvIO<iPadConsole, PlaygroundError, ()> {
        return EnvIO { console in
            modules.k().foldLeft(IO<PlaygroundError, ()>.lazy(), { partial, module in
                partial.forEffect(console.printSubstep(information: module.name))
            })
        }
    }
    
    private func stepPlayground(modules: [Module], resolvePath: ResolvePath) -> EnvIO<IPadApp, PlaygroundError, Void> {
        return binding(
            |<-EnvIO { app in app.console.printStep(information: "Building Swift Playground...") },
            |<-self.makePlaygroundBook(modules: modules, resolvePath: resolvePath).contramap(\IPadApp.storage)
                .handleErrorWith { e in EnvIO { app in app.console.printStatus(success: false) } }
                .forEffect(EnvIO { app in app.console.printStatus(success: true) }),
            yield: ()
        )^
    }
    
    private func stepCleanUp(deintegrate: Bool, resolvePath: ResolvePath) -> EnvIO<IPadApp, PlaygroundError, Void> {
        return EnvIO { app in
            binding(
                |<-app.console.printStep(information: "Clean up generated files for building"),
                |<-self.removePackageResolved(resolvePath: resolvePath).invoke(app.storage),
                |<-(deintegrate ? self.cleanBuildFolder(resolvePath: resolvePath).invoke(app.storage) : IO<PlaygroundError, Void>.lazy()),
                |<-app.console.printStatus(success: true),
                yield: ())
        }
    }
    
    // MARK: private methods <step helpers>
    private func makeStructure(projectPath: String, buildPath: String) -> EnvIO<Storage, PlaygroundError, Bool> {
        return EnvIO { storage in
            IO.invoke {
                storage.createFolder(path: projectPath)
                let result = storage.createFolder(path: buildPath)
                
                switch result {
                case .success: return true
                case .failure(.exist): return true
                default: return false
                }
            }
        }
    }
    
    private func makePlaygroundBook(modules: [Module], resolvePath: ResolvePath) -> EnvIO<Storage, PlaygroundError, Void> {
        return EnvIO<Storage, PlaygroundError, Void> { storage in
            IO.invoke { storage.remove(filePath: resolvePath.playgroundPath) }
        }.forEffect(
            PlaygroundBook(name: "nef", path: resolvePath.playgroundPath)
                .create(withModules: modules)
                .mapError(constant(.playgroundBook))
        )^
    }
    
    private func removePackageResolved(resolvePath: ResolvePath) -> EnvIO<Storage, PlaygroundError, Void> {
        return EnvIO { storage in
            IO.invoke {
                let packageResolvedPath = "\(resolvePath.packagePath.parentPath)/Package.resolved"
                storage.remove(filePath: packageResolvedPath)
            }
        }
    }
    
    private func cleanBuildFolder(resolvePath: ResolvePath) -> EnvIO<Storage, PlaygroundError, Void> {
        return EnvIO { storage in
            IO.invoke { storage.remove(filePath: resolvePath.nefPath) }
        }
    }
    
    // MARK: private methods <swift-package-manager>
    private func buildPackage(_ packagePath: String, nefPath: String, buildPath: String) -> EnvIO<Storage, PlaygroundError, Bool> {
        return EnvIO { storage in
            IO.invoke {
                guard case .success = storage.copy(packagePath, to: nefPath) else { return false }
                
                let result = run("swift package --package-path \(nefPath)/.. --build-path \(buildPath) resolve")
                return result.exitStatus == 0
            }
        }
    }
    
    private func repositories(checkoutPath: String) -> [String] {
        let result = run("ls \(checkoutPath)")
        guard result.exitStatus == 0 else { return [] }
        
        let repositoriesPath = result.stdout.components(separatedBy: "\n").map { "\(checkoutPath)/\($0)" }
        return repositoriesPath.filter { !$0.contains("swift-") }
    }

    private func modulesInRepository(_ repositoryPath: String) -> [Module] {
        let result = run("swift package --package-path \(repositoryPath) describe")
        guard result.exitStatus == 0 else { return [] }
        
        return Module.modules(from: result.stdout)
    }
}

enum PlaygroundError: Error {
    case structure
    case package(packagePath: String)
    case checkout
    case playgroundBook
    case ioError
    
    var information: String {
        switch self {
        case .structure:
            return "could not create project structure"
        case .package(let path):
            return "could not build project 'Package.swift' :: \(path)"
        case .checkout:
            return "command 'swift package describe' failed"
        case .playgroundBook:
            return "could not create Swift Playground"
        case .ioError:
            return "failure running IO"
        }
    }
}

fileprivate struct ResolvePath {
    let packagePath: String
    let projectName: String
    let outputPath: String
    
    private var nefFolder: String { "nef" }
    private var buildFolder: String { "\(nefFolder)/build"}
    
    var projectPath: String { "\(outputPath)/\(projectName)" }
    var nefPath: String { "\(projectPath)/\(nefFolder)"}
    var buildPath: String { "\(projectPath)/\(buildFolder)"}
    var checkoutPath: String { "\(projectPath)/nef/build/checkouts" }
    
    var playgroundPath: String { "\(projectPath)/\(projectName).playgroundbook" }
}
