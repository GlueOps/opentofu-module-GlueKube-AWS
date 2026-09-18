# Changelog

## [0.5.0](https://github.com/GlueOps/opentofu-module-GlueKube-AWS/compare/v0.4.1...v0.5.0) (2026-09-18)


### Features

* add toggle for the bastion ([#57](https://github.com/GlueOps/opentofu-module-GlueKube-AWS/issues/57)) ([07cf616](https://github.com/GlueOps/opentofu-module-GlueKube-AWS/commit/07cf616c6488876c44db899e3a6693cd2283e9a1))


### Bug Fixes

* bump github-actions-gluekube-e2e to v1.1.1 to retry failed bastions ([#59](https://github.com/GlueOps/opentofu-module-GlueKube-AWS/issues/59)) ([e5a439e](https://github.com/GlueOps/opentofu-module-GlueKube-AWS/commit/e5a439e4cb07531e3b7fb2671cd039c3f37eb87e))
* giving aws cloud-init more time (2 extra minutes) in e2e tests ([#61](https://github.com/GlueOps/opentofu-module-GlueKube-AWS/issues/61)) ([a93e2fb](https://github.com/GlueOps/opentofu-module-GlueKube-AWS/commit/a93e2fb1b0efe61b5235508a2796f91f1cc522bc))
* wait for NAT routes and route table associations before creating EC2 instances ([#55](https://github.com/GlueOps/opentofu-module-GlueKube-AWS/issues/55)) ([ee71cb1](https://github.com/GlueOps/opentofu-module-GlueKube-AWS/commit/ee71cb10066d02bd5d2a456c9ac7af4d5bdb4bf2))


### Miscellaneous Chores

* bumped the default gluekube tag version ([#58](https://github.com/GlueOps/opentofu-module-GlueKube-AWS/issues/58)) ([3047e19](https://github.com/GlueOps/opentofu-module-GlueKube-AWS/commit/3047e19dcc6c874b0e513d19df3a604fca5bc4e9))

## [0.4.1](https://github.com/GlueOps/opentofu-module-GlueKube-AWS/compare/v0.4.0...v0.4.1) (2026-08-28)


### Bug Fixes

* Clarify NAT gateway configuration in README ([#50](https://github.com/GlueOps/opentofu-module-GlueKube-AWS/issues/50)) ([fd28965](https://github.com/GlueOps/opentofu-module-GlueKube-AWS/commit/fd28965e5968b50af99e18699e84e55e0a817f00))

## [0.4.0](https://github.com/GlueOps/opentofu-module-GlueKube-AWS/compare/v0.3.0...v0.4.0) (2026-08-28)


### Features

* trigger new release ([#46](https://github.com/GlueOps/opentofu-module-GlueKube-AWS/issues/46)) ([8e7e009](https://github.com/GlueOps/opentofu-module-GlueKube-AWS/commit/8e7e009c15094a00bf142ba5e80d2ae53c779d7e))


### Bug Fixes

* fix the tag version in release please ([f22f054](https://github.com/GlueOps/opentofu-module-GlueKube-AWS/commit/f22f054c4719ab24616e7440f8a13882cb62d178))


### Miscellaneous Chores

* add Apache-2.0 LICENSE ([#35](https://github.com/GlueOps/opentofu-module-GlueKube-AWS/issues/35)) ([8db929c](https://github.com/GlueOps/opentofu-module-GlueKube-AWS/commit/8db929c32ab5718cfef74a08c86832d48b67e9bf))
* update e2e to latest version ([c0c1bf4](https://github.com/GlueOps/opentofu-module-GlueKube-AWS/commit/c0c1bf4c0b97425d9f8d91f9fa5a72e12370c2a5))
* Update gluekube_docker_tag in README.md ([#47](https://github.com/GlueOps/opentofu-module-GlueKube-AWS/issues/47)) ([2f30470](https://github.com/GlueOps/opentofu-module-GlueKube-AWS/commit/2f3047030b561d99d3f299735ba4ee7aaaa210af))
