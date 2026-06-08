# 签名配置说明

## 问题原因
AGC上传包名解析错误是因为使用了调试签名，正式发布必须使用AGC提供的正式签名配置。

## 操作步骤

### 1. 从AGC下载签名文件
1. 登录 [AppGallery Connect](https://developer.huawei.com/consumer/cn/service/josp/agc/index.html)
2. 选择应用 `com.jihe.neu.mybookstore`
3. 进入 **项目设置 > 常规 > 签名配置**
4. 下载以下文件：
   - **发布证书** (.cer)
   - **Profile文件** (.p7b) 
   - **密钥库文件** (.p12)

### 2. 放置签名文件
将下载的文件重命名并放入此目录：
- `release.cer` - 发布证书
- `release.p7b` - Profile文件
- `release.p12` - 密钥库文件

### 3. 更新签名配置
修改 `build-profile.json5` 中的签名配置：
- `keyPassword`: 输入创建密钥时设置的密钥密码
- `storePassword`: 输入密钥库的存储密码

### 4. 重新构建
```bash
# 清理构建缓存
find . -name "build" -type d -exec rm -rf {} +

# 构建发布版本
hvigorw clean
hvigorw assembleHap --mode release
```

## 注意事项
- 签名文件必须与AGC上注册的包名 `com.jihe.neu.mybookstore` 匹配
- 密钥密码和存储密码在创建密钥时设置，请妥善保管
- 不要将签名文件和密码提交到代码仓库
