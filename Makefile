.PHONY: test
test:
	swift test -c release -Xswiftc -enable-testing --filter MusicWasmObjCTests

.PHONY: xcode
xcode:
	@which xcodegen >/dev/null || brew install xcodegen
	@killall xcode 2>/dev/null || true 
	@xcodegen generate && open app.xcodeproj

