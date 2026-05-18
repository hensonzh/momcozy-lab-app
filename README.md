# Mai MomCozy APP

## 环境搭建

从git远程仓库clone到本地后，打开终端，进入到工程的根目录，按照下述指令依次执行，搭建编译环境。
1.执行以下命令，初始化npm的编译环境

```
npm init -y
```

2.执行以下命令，安装Capacitor 核心库和 CLI（如有使用了其他插件，请一起安装）

```
npm install @capacitor/core @capacitor/cli
```

3.执行以下命令，编译web工程

```
npm run build
```

4.执行以下命令，将编译后的web资源同步到Android工程中

```
npx cap sync android
```

## Android Studio配置

1.执行完以上命令后，打开Android Studio，配置好JDK等环境，点击编译，运行；  
2.当修改了web工程后，请再次执行 npm run build && npx cap sync android 命令，同步好web资源后再执行上述步骤。