# 原生测试串行执行

先用 `xcodebuild build-for-testing` 编译，再运行已有的 `.xctestrun`。不要同时执行客户、法师和 Mac 的构建或测试；每次指定一台专用模拟器的 UUID，不使用 `booted` 操作其他设备。

编译使用 `-jobs 1 -parallel-testing-enabled NO SWIFT_NUM_THREADS=1`，模拟器添加 `ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO`。依赖使用仓库锁文件。验收应用的 API 指向隔离服务，OpenIM 指向本机关闭端口；生产包须重新使用生产配置构建。

```sh
python3 scripts/e2e/test_native_runner.py
python3 scripts/e2e/run-native-tests.py \
  --xctestrun /absolute/DerivedData/Build/Products/DongFangApp_iphonesimulator27.0-arm64.xctestrun \
  --destination 'platform=iOS Simulator,id=YOUR-DEDICATED-SIMULATOR-UUID' \
  --output /absolute/new-test-output \
  --only-testing DongFangAppTests
```

脚本锁定同机测试入口，禁止并行测试，关闭 Xcode 的额外诊断收集，但保留 XCTest 截图、结果流、日志和完整 `.xcresult`。Xcode 27 曾在测试断言全部通过后停留于 `Blocking finish to clean up test session`；拆开编译和测试并使用此配置已能正常收尾，这不是对 Xcode 内部根因的证明。

默认总时限 240 秒，超时向本次进程组发送中断，15 秒后仍未结束才强制终止该组；不结束全局模拟器服务或其他 Xcode。退出码 124 表示超时，不能记为测试通过。成功还要求结果包可读、有实际通过测试且没有跳过项。需要多项 UI 检查时按阶段单独执行，使用新的输出目录，不覆盖失败证据。

`TempleOperationsUITests` 使用隔离环境真实服务，并要求通过 `.xctestrun` 的 `EnvironmentVariables` 注入 `TEMPLE_OPS_MASTER_TOKEN`、`TEMPLE_OPS_CUSTOMER_TOKEN`、`TEMPLE_OPS_BOOKING`、`TEMPLE_OPS_DATE` 和回执阶段的 `TEMPLE_OPS_RECEIPT_TEXT`。这些私有配置不得提交或归入公开日志。按停约、跨端异常跟进、恢复排班、履约、补充回执、确认完成的状态顺序执行，不能对生产数据直接运行。

每阶段用 `--only-testing Target/Class/method` 选择对应方法，不要一次运行整个状态相关测试类。日期必须在当前可见月份，停约检查要求该日期尚无自定义排班；履约检查要求订单已支付、待接单。回执检查前，用 `xcrun simctl addmedia YOUR-DEDICATED-SIMULATOR-UUID /absolute/test-image.png` 导入无个人信息的测试图，测试会选择相册中的第一张图。信众在原生端确认第二版回执后，通过 H5 评价，再运行原生历史回读检查。
