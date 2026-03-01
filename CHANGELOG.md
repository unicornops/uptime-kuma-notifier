# Changelog
All notable changes to this project will be documented in this file. See [conventional commits](https://www.conventionalcommits.org/) for commit guidelines.

- - -
## [1.0.0](https://github.com/unicornops/uptime-kuma-notifier/compare/v0.10.3...v1.0.0) (2026-03-01)


### ⚠ BREAKING CHANGES

* Complete rewrite from Rust to Swift. All previous configuration files, build scripts, and Rust source are removed.

### Features

* Add 2FA support for server authentication ([a81c6c6](https://github.com/unicornops/uptime-kuma-notifier/commit/a81c6c6fd57f07de728df147ac762fa7a46c072f))
* Add 2FA support for server authentication ([729d750](https://github.com/unicornops/uptime-kuma-notifier/commit/729d750cffad88f37af7d9ec043d627cf0cedcb7))
* Add 2FA token support for server authentication ([fa2e1b0](https://github.com/unicornops/uptime-kuma-notifier/commit/fa2e1b00a90459655bd09fe329704e15fb508d07))
* Add 2FA token support for server authentication ([d330aa3](https://github.com/unicornops/uptime-kuma-notifier/commit/d330aa3c68897d13b79594203a26dd11938e93b4))
* Add refresh controls and loading indicators to UI ([7c0a59b](https://github.com/unicornops/uptime-kuma-notifier/commit/7c0a59ba5b44548022ea1a40448d2b43b209c76e))
* Add refresh controls and loading indicators to UI ([5cfe02a](https://github.com/unicornops/uptime-kuma-notifier/commit/5cfe02aee6bee5f60a4d8c01fec303638ff56e4d))
* Add refreshing state to server connection handling ([1677db1](https://github.com/unicornops/uptime-kuma-notifier/commit/1677db1ffa24439f764cc587089be5de94aebf5a))
* Add refreshing state to server connection handling ([6be3138](https://github.com/unicornops/uptime-kuma-notifier/commit/6be3138ba99863816b58cebdc4404f1ccaa01ce4))
* Add TOTP 2FA support with live code generation ([aaadcde](https://github.com/unicornops/uptime-kuma-notifier/commit/aaadcde72c84ee2dd3db210f5d8876a43e029c85))
* Add TOTP 2FA support with live code generation ([ee61457](https://github.com/unicornops/uptime-kuma-notifier/commit/ee6145722ee34576fa459a6259faf274e896bab6))
* Adding cocogitto config ([96b6e65](https://github.com/unicornops/uptime-kuma-notifier/commit/96b6e65e8baab7f77e5ff808bd6c228c65b534ca))
* Adding cocogitto config ([20b33fb](https://github.com/unicornops/uptime-kuma-notifier/commit/20b33fbb40137c6636728b5105a5da78a79ee147))
* **ci:** add custom app and DMG icon to release workflows ([d5d485f](https://github.com/unicornops/uptime-kuma-notifier/commit/d5d485f1cb8d6250e1f9257b9d037b8660dd1884))
* **ci:** add custom app and DMG icon to release workflows ([dbb9f15](https://github.com/unicornops/uptime-kuma-notifier/commit/dbb9f15800bce512613c21fc965d18eadb6f0e34))
* Ensure Settings window activates app when opened ([a36592b](https://github.com/unicornops/uptime-kuma-notifier/commit/a36592b8629ac1b1d74451d4e0d070678f789bef))
* Ensure Settings window activates app when opened ([d3a74cc](https://github.com/unicornops/uptime-kuma-notifier/commit/d3a74cc5f4eea0aa4c65ed6188edb97976336636))
* Improve the Makefile adding help ([88c1d43](https://github.com/unicornops/uptime-kuma-notifier/commit/88c1d4348c8ec35aaddbf548998d32bb8250808f))
* Improve the README, point to using make. ([2d841f5](https://github.com/unicornops/uptime-kuma-notifier/commit/2d841f54c0d96aa525cc5df8f261f45dc4c54f42))
* Initial commit ([0af7375](https://github.com/unicornops/uptime-kuma-notifier/commit/0af7375b94f31dfa4c93ffd96693b8ac3a475fac))
* **notification:** show app icon in native notifications ([d78ada9](https://github.com/unicornops/uptime-kuma-notifier/commit/d78ada95eb41e6f506f9a9b1364793cb35228654))
* **notification:** show app icon in native notifications ([b526b44](https://github.com/unicornops/uptime-kuma-notifier/commit/b526b443287f4961dc47d6688c0a6e80bbcea713))
* Preserve monitor data during reconnect and refresh ([3ca97a8](https://github.com/unicornops/uptime-kuma-notifier/commit/3ca97a801a3e8c2a67edace25184526cb59d4d81))
* Preserve monitor data during reconnect and refresh ([18e3d70](https://github.com/unicornops/uptime-kuma-notifier/commit/18e3d706aceb398a242d8605ae632b1caaa2ab6e))
* rewrite application in Swift as native macOS menu bar app ([43d7675](https://github.com/unicornops/uptime-kuma-notifier/commit/43d767583b47d4e78365b4e6c15a64b765637d45))
* Testing code signing in the build ([554e116](https://github.com/unicornops/uptime-kuma-notifier/commit/554e116c95231307fd8d25f83de056f41597d982))


### Bug Fixes

* Add ack handling for token login and clear stale tokens ([8b5a9bc](https://github.com/unicornops/uptime-kuma-notifier/commit/8b5a9bc647886b6afed9c0c86d0c991b08e95e3c))
* Add ack handling for token login and clear stale tokens ([c6d6cbc](https://github.com/unicornops/uptime-kuma-notifier/commit/c6d6cbc00d1664bbf1b0a61dffbe4a58fa15624d))
* add connection watchdog and sleep/wake reconnection ([9fde8d4](https://github.com/unicornops/uptime-kuma-notifier/commit/9fde8d4497d4031ff9fbf136442519a66381f6e2))
* add connection watchdog and sleep/wake reconnection ([3fe3bca](https://github.com/unicornops/uptime-kuma-notifier/commit/3fe3bca146f117d1f0faf736e9d90cc47dcfe263))
* Improve 2FA login flow for Socket.IO connections ([a92df16](https://github.com/unicornops/uptime-kuma-notifier/commit/a92df16e7de3f88d990cfa10a7da567d9afa7df8))
* Improve 2FA login flow for Socket.IO connections ([7007e07](https://github.com/unicornops/uptime-kuma-notifier/commit/7007e076b15af0ee84b8d23ebb1e944b9618bdfb))
* improve app icon resolution for notifications ([ba71f2e](https://github.com/unicornops/uptime-kuma-notifier/commit/ba71f2e65888a7d4c4176f58ae7d8b1189cb5db2))
* improve app icon resolution for notifications ([de1fc07](https://github.com/unicornops/uptime-kuma-notifier/commit/de1fc07a53dcf6f2011955fe7b3b94594efd05a3))
* Make app icon PNG conversion safe for notification attachments ([ac127cf](https://github.com/unicornops/uptime-kuma-notifier/commit/ac127cf0177c10acbdc965e9cf3bc8407dbd77fa))
* Make app icon PNG conversion safe for notification attachments ([034048f](https://github.com/unicornops/uptime-kuma-notifier/commit/034048f5aa5cb41501cdabd8f7b718431aaf0bef))
* Normalize server URLs to avoid WebSocket origin mismatch ([e560414](https://github.com/unicornops/uptime-kuma-notifier/commit/e560414a8bf8ced394418db5b7ddfd8d58703b16))
* Normalize server URLs to avoid WebSocket origin mismatch ([aa0256d](https://github.com/unicornops/uptime-kuma-notifier/commit/aa0256d9f6976ba55ffbd21122870cc4474ad899))
* Release ([58f04b6](https://github.com/unicornops/uptime-kuma-notifier/commit/58f04b63a5729907323e81088cb7ec4d671ef796))
* Release ([d74f1fa](https://github.com/unicornops/uptime-kuma-notifier/commit/d74f1fa4f718589130dca3b6ec694f62cb50ce5a))
* Revert "refactor: remove ServerConnectionState.refreshing and update refresh" ([0dfe9bf](https://github.com/unicornops/uptime-kuma-notifier/commit/0dfe9bf460510d779263d48113ad81b8e3966acb))
* Revert "refactor: remove ServerConnectionState.refreshing and update refresh" ([5f45128](https://github.com/unicornops/uptime-kuma-notifier/commit/5f4512855ef47c1dbee954d8f02f7d58b1e60a82))

## v0.10.2 - 2026-02-14
#### Bug Fixes
- Make app icon PNG conversion safe for notification attachments - (034048f) - Rob Lazzurs

- - -

## v0.10.1 - 2026-02-14
#### Bug Fixes
- improve app icon resolution for notifications - (de1fc07) - Rob Lazzurs

- - -

## v0.10.0 - 2026-02-14
#### Features
- (**notification**) show app icon in native notifications - (b526b44) - Rob Lazzurs

- - -

## v0.9.2 - 2026-02-13
#### Bug Fixes
- Revert "refactor: remove ServerConnectionState.refreshing and update refresh" - (5f45128) - Rob Lazzurs

- - -

## v0.9.1 - 2026-02-13
#### Bug Fixes
- Release - (d74f1fa) - Rob Lazzurs
#### Refactoring
- remove ServerConnectionState.refreshing and update refresh - (3028df4) - Rob Lazzurs

- - -

## v0.9.0 - 2026-02-13
#### Features
- Add refreshing state to server connection handling - (6be3138) - Rob Lazzurs

- - -

## v0.8.0 - 2026-02-13
#### Features
- Preserve monitor data during reconnect and refresh - (18e3d70) - Rob Lazzurs

- - -

## v0.7.0 - 2026-02-13
#### Features
- Add refresh controls and loading indicators to UI - (5cfe02a) - Rob Lazzurs

- - -

## v0.6.3 - 2026-02-13
#### Bug Fixes
- Add ack handling for token login and clear stale tokens - (c6d6cbc) - Rob Lazzurs

- - -

## v0.6.2 - 2026-02-13
#### Bug Fixes
- Normalize server URLs to avoid WebSocket origin mismatch - (aa0256d) - Rob Lazzurs

- - -

## v0.6.1 - 2026-02-13
#### Bug Fixes
- Improve 2FA login flow for Socket.IO connections - (7007e07) - Rob Lazzurs

- - -

## v0.6.0 - 2026-02-13
#### Features
- Add TOTP 2FA support with live code generation - (ee61457) - Rob Lazzurs

- - -

## v0.5.0 - 2026-02-13
#### Features
- (**ci**) add custom app and DMG icon to release workflows - (dbb9f15) - Rob Lazzurs

- - -

## v0.4.0 - 2026-02-13
#### Features
- Add 2FA token support for server authentication - (d330aa3) - Rob Lazzurs

- - -

## v0.3.0 - 2026-02-13
#### Features
- Add 2FA support for server authentication - (729d750) - Rob Lazzurs

- - -

## v0.2.0 - 2026-02-13
#### Features
- Ensure Settings window activates app when opened - (d3a74cc) - Rob Lazzurs

- - -

## v0.1.0 - 2026-02-13
#### Features
- Adding cocogitto config - (20b33fb) - Rob Lazzurs
- <span style="background-color: #d73a49; color: white; padding: 2px 6px; border-radius: 3px; font-weight: bold; font-size: 0.85em;">BREAKING</span>rewrite application in Swift as native macOS menu bar app - (43d7675) - Rob Lazzurs
- Testing code signing in the build - (554e116) - Rob Lazzurs
- Improve the Makefile adding help - (88c1d43) - Rob Lazzurs
- Improve the README, point to using make. - (2d841f5) - Rob Lazzurs
- Initial commit - (0af7375) - Rob Lazzurs
#### Documentation
- add comprehensive README with project overview, installation, usage, and development information - (01f17ba) - Rob Lazzurs
- add CLAUDE.md with project context and conventions - (f766fec) - Rob Lazzurs
#### Continuous Integration
- replace Rust build workflows with Swift SPM workflows - (841aac0) - Rob Lazzurs
#### Chores
- (**version**) v0.3.0 - (d4b3ae9) - GitHubActions
- (**version**) v0.2.0 - (b0fa868) - GitHubActions
- (**version**) v0.1.0 - (69049ce) - Rob Lazzurs
- update dependabot config from cargo to swift ecosystem - (7a8eef6) - Rob Lazzurs

- - -

Changelog generated by [cocogitto](https://github.com/cocogitto/cocogitto).
