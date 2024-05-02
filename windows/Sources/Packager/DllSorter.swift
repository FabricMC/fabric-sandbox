import WindowsUtils

/// Given a list of dlls, sorts them in the order they should be loaded

func sortDlls(inputs: [File]) throws -> [String] {
  var dependencies = [String: [String]]()

  for input in inputs {
    let dllDependencies = try VisualStudio.getDllDependencies(dll: input)
    dependencies[input.name()] = dllDependencies.filter { !isSystemDll($0) }
  }

  // The first dlls to load are the ones that have no dependencies
  var sorted = [String]()

  while !dependencies.isEmpty {
    // Find any dependencies that have no outstanding dependencies
    let noOutstandingDependencies = dependencies.filter { $0.value.isEmpty }

    guard !noOutstandingDependencies.isEmpty else {
      // We found no dlls with no outstanding dependencies, so we have a circular dependency
      throw PackagerError("Circular dependency detected: \(dependencies)")
    }

    for (dll, _) in noOutstandingDependencies {
      sorted.append(dll)
      dependencies.removeValue(forKey: dll)

      // Remove the dependency from all other dependencies
      for (key, value) in dependencies {
        dependencies[key] = value.filter { $0.lowercased() != dll.lowercased() }
      }
    }
  }

  return sorted
}

func isSystemDll(_ name: String) -> Bool {
  if name.hasPrefix("api-ms-win") {
    return true
  }

  let system32 = File("C:/Windows/System32")
  return system32.child(name).exists()
}
