/*
 This source file is part of the Swift.org open source project

 Copyright 2016 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Basic
import PackageGraph
import SourceControl

private class ResolverToolDelegate: DependencyResolverDelegate, CheckoutManagerDelegate {
    typealias Identifier = RepositoryPackageContainer.Identifier

    func added(container identifier: Identifier) {
        print("note: considering repository: \(identifier.url)")
    }

    func fetching(handle: CheckoutManager.RepositoryHandle, to path: AbsolutePath) {
        print("note: fetching \(handle.repository.url) to \(path.asString)")
    }
}

extension SwiftPackageTool {
    func executeResolve(_ opts: PackageToolOptions) throws {
        // Load the root manifest.
        let manifest = try loadRootManifest(opts)
        let delegate = ResolverToolDelegate()

        // Create the checkout manager.
        let repositoriesPath = buildPath.appending(component: "repositories")
        let checkoutManager = CheckoutManager(path: repositoriesPath, provider: GitRepositoryProvider(), delegate: delegate)

        // Create the container provider interface.
        let provider = RepositoryPackageContainerProvider(
            checkoutManager: checkoutManager, manifestLoader: manifestLoader)

        // Create the resolver.
        let resolver = DependencyResolver(provider, delegate)

        // Resolve the dependencies using the manifest constraints.
        let constraints = manifest.package.dependencies.map{
            RepositoryPackageConstraint(container: RepositorySpecifier(url: $0.url), versionRequirement: .range($0.versionRange)) }
        let result = try resolver.resolve(constraints: constraints)

        print("Resolved dependencies for: \(manifest.name)")
        for (container, version) in result {
            // FIXME: It would be nice to show the reference path, should we get
            // that back or do we need to re-derive it?

            // FIXME: It would be nice to show information on the resulting
            // constraints, e.g., how much latitude do we have on particular
            // dependencies.
            print("  \(container.url): \(version)")
        }
    }
}
