struct Product {
    var type: String
    var displayName: String
    var family: String
    var appLineage: String
    var familyName: String
    var productIcons: [ProductIcon]
    var platforms: [Platform]
    var referencedProducts: [ReferencedProduct]
    var version: String
    var id: String
    var hidden: Bool

    struct ProductIcon {
        var value: String
        var size: String
    }

    struct Platform {
        var languageSet: [LanguageSet]
        var modules: [Module]
        var range: [Range]
        var id: String

        struct LanguageSet {
            var manifestURL: String
            var dependencies: [Dependency]
            var productCode: String
            var name: String
            var installSize: Int
            var buildGuid: String
            var baseVersion: String
            var productVersion: String

            struct Dependency {
                var sapCode: String
                var baseVersion: String
                var productVersion: String
                var buildGuid: String
            }
        }

        struct Module {
            var displayName: String
            var deploymentType: String
            var id: String
        }

        struct Range {
            var min: String
            var max: String
        }
    }

    struct ReferencedProduct {
        var sapCode: String
        var version: String
    }
}

struct NewParseResult {
    var products: [Product]
    var cdn: String
}
