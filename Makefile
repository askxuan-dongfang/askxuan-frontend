.PHONY: help clients-up clients-down clients-restart clients-check clients-logs clients-ios-open clients-ios-smoke

help: ## 显示可用命令
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

clients-up: ## 一键启动五个客户端入口：3 个 Web 管理端 + 2 个 iOS workspace 提示
	@bash scripts/dev/clients-up.sh

clients-down: ## 停止本脚本启动的 Web 管理端 dev server
	@bash scripts/dev/clients-down.sh

clients-restart: clients-down clients-up ## 重启客户端 Web dev server

clients-check: ## 检查 3 个 Web 管理端 URL 与 2 个 iOS workspace
	@bash scripts/dev/clients-check.sh

clients-logs: ## 查看客户端启动日志路径
	@find logs/clients -type f -maxdepth 1 -print 2>/dev/null || true

clients-ios-open: ## 打开两个原生 iOS workspace
	@open apps/ios-customer/DongFangApp.xcworkspace
	@open apps/ios-master/MasterApp.xcworkspace

clients-ios-smoke: ## 构建并运行两个 iOS 模拟器冒烟截图脚本
	@bash scripts/e2e/ios-smoke.sh
