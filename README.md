# Mai MomCozy APP

## 环境搭建

从 Git 远程仓库 clone 到本地后，打开终端并进入工程根目录。

安装依赖：

```
npm install
```

本地开发：

```
npm run dev
```

构建 Web 工程：

```
npm run build
```

同步到 Android 工程：

```
npx cap sync android
```

## Android Studio配置

执行完 `npm run build && npx cap sync android` 后，打开 Android Studio，配置好 JDK 等环境即可编译运行。

当修改了 Web 工程后，请再次执行：

```
npm run build && npx cap sync android
```
