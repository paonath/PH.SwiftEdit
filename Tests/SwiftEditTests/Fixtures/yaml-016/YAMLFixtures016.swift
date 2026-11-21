import Foundation
@testable import SwiftEditCore

/// In-source YAML fixtures for change `016` (kept as Swift literals so SwiftPM needs no test resources).
enum YAMLFixtures016 {
    static let all: [String: String] = [
        "config.yml": "version: 2\nservices:\n  web:\n    image: nginx\n    ports:\n      - \"80:80\"\nvolumes: {}\n",
        "frontmatter.md": "---\n# note\ntitle: Hello\ntags: [a, b]\ndraft: false\n---\n# Body\n",
        "alias-bomb.yml": "l0: &l0 lol\nl1: &l1 [*l0, *l0, *l0, *l0, *l0, *l0, *l0, *l0, *l0, *l0]\nl2: &l2 [*l1, *l1, *l1, *l1, *l1, *l1, *l1, *l1, *l1, *l1]\nl3: &l3 [*l2, *l2, *l2, *l2, *l2, *l2, *l2, *l2, *l2, *l2]\nl4: &l4 [*l3, *l3, *l3, *l3, *l3, *l3, *l3, *l3, *l3, *l3]\nl5: &l5 [*l4, *l4, *l4, *l4, *l4, *l4, *l4, *l4, *l4, *l4]\nl6: &l6 [*l5, *l5, *l5, *l5, *l5, *l5, *l5, *l5, *l5, *l5]\nl7: &l7 [*l6, *l6, *l6, *l6, *l6, *l6, *l6, *l6, *l6, *l6]\nl8: &l8 [*l7, *l7, *l7, *l7, *l7, *l7, *l7, *l7, *l7, *l7]\nl9: &l9 [*l8, *l8, *l8, *l8, *l8, *l8, *l8, *l8, *l8, *l8]\n",
        "deep-nesting.yml": "k0:\n  k1:\n    k2:\n      k3:\n        k4:\n          k5:\n            k6:\n              k7:\n                k8:\n                  k9:\n                    k10:\n                      k11:\n                        k12:\n                          k13:\n                            k14:\n                              k15:\n                                k16:\n                                  k17:\n                                    k18:\n                                      k19:\n                                        k20:\n                                          k21:\n                                            k22:\n                                              k23:\n                                                k24:\n                                                  k25:\n                                                    k26:\n                                                      k27:\n                                                        k28:\n                                                          k29:\n                                                            k30:\n                                                              k31:\n                                                                k32:\n                                                                  k33:\n                                                                    k34:\n                                                                      k35:\n                                                                        k36:\n                                                                          k37:\n                                                                            k38:\n                                                                              k39:\n                                                                                token: s3cr3t\n",
    ]

    /// Seeds every fixture into an `InMemoryFileSystemFake` under `/fixtures/yaml-016/` (`TEST-004`).
    static func seededFileSystem() -> InMemoryFileSystemFake {
        let fs = InMemoryFileSystemFake()
        for (name, text) in all {
            fs.seed(url: url(name), data: Data(text.utf8))
        }
        return fs
    }

    static func url(_ name: String) -> URL { URL(fileURLWithPath: "/fixtures/yaml-016/\(name)") }
}
