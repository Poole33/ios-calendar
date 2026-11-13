# 木历

木历是一个 SwiftUI 月历，包含 iPhone、iPad 和 Mac App，以及各平台的大号月历小组件。最低系统为 iOS / iPadOS 17 和 macOS 14。

## 本地运行

1. 使用完整的 Xcode 16 或更新版本打开 `Muli.xcodeproj`，选择 `Muli` scheme。
2. 选择 iPhone 模拟器或 My Mac，运行 App。真机和需要共享容器的测试请给 `Muli` 与 `MuliWidget` 两个目标选择同一个 Apple 开发团队。
3. 两个目标需要有同一个 App Group。工程默认使用 `group.com.muli.calendar`。如果该标识不可用，在 Project 的 Build Settings 修改 `MULI_APP_GROUP`，在两个目标的 Signing & Capabilities 确认对应 App Group，并按团队要求修改 App 与扩展的 Bundle ID。扩展的 Bundle ID 必须以 App 的 Bundle ID 加一个点开头。
4. 运行一次 App 后，在桌面小组件库添加「木历月历」。进入 App 点「连接系统日历」授权，再通过右上角「木历」进入设置，勾选工作日历。

## 交互与数据

- App 内点击年月跳转日期，左右滑动或点箭头切月，长按年月回到今天。选中其他日期时，右上角「今」回到当天。选中今天时，右上角「木历」打开设置。
- 小组件内点箭头切月，点某日打开对应日期。点年月打开 App 的日期选择器，选择「今天」可让小组件一起回到当天。
- 系统日历只在设备上读取。默认显示常规系统日历，可在设置中按日历筛选。小组件共享的数据只有日期和颜色，App 内显示日程时间和标题。
- 小组件使用系统安排的刷新时机。圆点缓存覆盖当前月前后三个月，以及 App 正在查看的额外月份。浏览较远的月份时，在 App 打开该月即可生成对应圆点。
- 公历、农历和节气可离线浏览 1901–2100 年。节气使用 UTC+8，日程和「今天」按设备时区显示。
- 中国大陆调休内置 2026、2027 年官方安排。木历打开时通过 [holiday-cn](https://github.com/NateScarlet/holiday-cn) 检查当年和下一年。成功获取的调休表保存到 App Group，供 App 和小组件离线使用。该数据源整理国务院办公厅公告，未公布的年份仅显示节日、节气和农历。

数据来源为[香港天文台公历与农历日期对照表](https://www.hko.gov.hk/tc/gts/time/conversion1_text.htm)、[2026 年放假调休通知](https://www.beijing.gov.cn/zhengce/zhengcefagui/202511/t20251104_4258873.html)和[2027 年放假调休通知](https://www.forestry.gov.cn/lyj/1/szxx/20261105/695102.html)。
