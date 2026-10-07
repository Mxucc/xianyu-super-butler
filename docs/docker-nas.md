# Docker Hub 发布与 NAS 部署

镜像名称默认为 `muzileee/xianyu-super-butler`。这是独立仓库，不会覆盖已有的 `muzileee/yunx-server`。

发布流程支持 `linux/amd64`（Intel / AMD）和 `linux/arm64`（64 位 ARM）。Docker 根据 NAS 架构自动选择镜像，无需手动指定平台。32 位 ARM 不在此范围内。

## 1. 配置 Docker Hub

1. 登录 [Docker Hub](https://hub.docker.com/)，确认用户名是 `muzileee`。
2. 新建一个公开的镜像仓库，名称填写 `xianyu-super-butler`。
3. 在账号设置的 **Personal access tokens** 中创建令牌，例如命名为 `github-xianyu`。
4. 权限选择 **Read & Write**，保存生成的令牌。

令牌填入 GitHub Secret 即可，不需要写入源码、Compose 文件或发送到聊天。

## 2. 配置 GitHub Actions

在 [GitHub 仓库的 Actions Secrets 页面](https://github.com/mu-zi-lee/xianyu-super-butler/settings/secrets/actions) 点击 **New repository secret**，新增：

| 名称 | 内容 |
| --- | --- |
| `DOCKERHUB_TOKEN` | 刚创建的 Docker Hub 访问令牌 |

默认用户名和镜像仓库已经配置好了。若要修改，在 [Actions Variables 页面](https://github.com/mu-zi-lee/xianyu-super-butler/settings/variables/actions) 新增以下变量：

| 名称 | 默认值 | 用途 |
| --- | --- | --- |
| `DOCKERHUB_USERNAME` | `muzileee` | Docker Hub 登录用户名和镜像命名空间 |
| `DOCKERHUB_REPOSITORY` | `xianyu-super-butler` | 镜像仓库名称，不含用户名 |

确保仓库的 **Settings → Actions → General** 允许 GitHub Actions 和所使用的 actions。工作流只需要 GitHub 仓库的读取权限；Docker Hub 推送使用单独的令牌。

将本次修改提交、推送到 GitHub 后，在 **Actions → Build and publish Docker images → Run workflow** 选择 `main` 分支运行。推送 `main` 和 `v*` 标签也会自动触发。

公开仓库使用 GitHub 托管的 `ubuntu-24.04` 和 `ubuntu-24.04-arm` 原生构建两个平台。若仓库转为私有，请确认账号支持 ARM 托管 runner，或将 ARM 作业配置为可用的自托管 runner。

每个平台会完成以下检查，再上传镜像：

- 构建 React 前端，安装 Python、Node.js、Chromium 和 Playwright 浏览器。
- 在不连接外网的容器中启动服务，验证健康检查、首次初始化、登录、退出和前端资源。
- 验证 Node.js 执行和 Playwright 有头浏览器启动，虚拟显示由容器提供。
- 使用同一数据卷重新创建容器，验证图片文件保留、原管理员密码保持有效。

两个平台全部通过后才合并发布镜像标签。拉取请求只执行构建与验证，不使用 Docker Hub 密钥，也不发布。

| 触发方式 | 发布标签示例 |
| --- | --- |
| 推送或手动运行 `main` | `latest`、`sha-abcdef0` |
| 推送 `v1.2.3` | `1.2.3`、`1.2`、`sha-abcdef0` |
| 手动运行其他分支 | `sha-abcdef0` |

版本标签不会更新 `latest`，`latest` 跟随 `main`。发布作业末尾会列出最终镜像名称；两种架构共享同一个标签。

## 3. 在 NAS 容器管理界面部署

镜像首次发布成功后，使用群晖 Container Manager、威联通 Container Station 或其他 NAS 容器管理界面创建容器。

| 配置项 | 内容 |
| --- | --- |
| 镜像 | `muzileee/xianyu-super-butler:latest` |
| 端口 | NAS `8080` → 容器 `8080`，TCP |
| 目录挂载 | NAS 上的专用数据文件夹 → 容器 `/app/data`，可读写 |
| 重启策略 | `unless-stopped` 或界面中的自动重启 |
| 共享内存 | 支持设置时填写 `512 MB` |
| 环境变量 `TZ` | `Asia/Shanghai` |
| 环境变量 `ADMIN_EMAIL` | 你的管理员邮箱 |
| 环境变量 `ADMIN_PASSWORD` | 你自己设置的管理员密码 |

例如，群晖的数据目录可用 `/volume1/docker/xianyu-super-butler/data`。根据实际 NAS 路径调整，并确保容器能够写入。建议至少为应用预留 2 GB 可用内存，多账号和并行浏览器会增加占用。

启动后访问 `http://NAS的IP:8080`，用户名为 `admin`，密码为设置的 `ADMIN_PASSWORD`。邮箱用于管理员账号资料，首次初始化不需要发送验证码。

没有填写初始化变量时，服务仍会启动，网页显示初始化说明。补齐邮箱和密码后重新创建容器，保留同一数据目录即可。只填写一个变量或填写空白密码会导致初始化失败，容器日志会给出原因。

首次创建管理员后，可以从容器配置中移除 `ADMIN_PASSWORD`，并使用相同的数据目录重新创建容器。密码已经存入数据库，后续环境变量不会重置它；修改密码使用网页中的密码设置功能。

## 4. 使用 Compose 部署

只需保存仓库中的 `docker-compose.yml` 和 `.env.example`，不需要下载其他源码或安装 Python / Node.js。将 `.env.example` 改名为 `.env`，例如：

```dotenv
DOCKER_IMAGE=muzileee/xianyu-super-butler
IMAGE_TAG=latest
WEB_PORT=8080
DATA_DIR=/volume1/docker/xianyu-super-butler/data
TZ=Asia/Shanghai
ADMIN_EMAIL=your-email@example.com
ADMIN_PASSWORD='替换为你自己的密码'
```

在这两个文件所在目录执行：

```bash
docker compose up -d
docker compose logs -f --tail=100
```

`.env` 中的密码建议使用单引号包裹，避免 `$` 等字符被 Compose 展开。NAS 的图形界面直接输入原密码，不加引号。如果 8080 已被占用，调整 `WEB_PORT`，容器内部仍使用 8080。

默认不需要额外的 Nginx、数据库服务或本地 `global_config.yml`。

## 5. 数据与更新

`/app/data` 保存：

| 文件 / 目录 | 内容 |
| --- | --- |
| `xianyu_data.db` | 管理员、闲鱼账号 Cookie、订单、规则及登录会话 |
| `global_config.yml` | 首次启动复制的全局配置，后续启动保留 |
| `uploads/` | 上传图片 |
| `browser_data/` | 浏览器登录缓存 |
| `slider_cookies/`、`trajectory_history/` | 浏览器 Cookie 文件和滑块记录 |
| `logs/`、`backups/` | 日志和备份目录；应用部分数据库备份直接存放在数据目录 |

升级前可停止容器并备份整个数据目录；然后拉取新镜像，用原端口和原数据目录重新创建容器。

Compose 更新命令：

```bash
docker compose pull
docker compose up -d
```

需要固定版本时，将 `IMAGE_TAG` 改成已发布的版本号或 `sha-...` 标签。

如果迁移旧 Compose 部署，先停止旧容器，把原 `static/uploads`、`browser_data`、日志及配置合并到新数据目录对应位置。仅复制数据库不会迁移图片和浏览器缓存。

## 6. 常见问题

- **Actions 登录 Docker Hub 失败**：检查 `DOCKERHUB_TOKEN` 是 Docker Hub 的令牌，具有写权限，且所属账号和用户名一致。
- **NAS 提示 manifest 不匹配**：检查发布作业是否成功，以及 NAS 是否为 x86-64 或 ARM64。单个平台失败时不会发布新的合并标签。
- **容器无法创建文件**：检查挂载路径和 NAS 文件夹的可写权限。
- **网页仍显示未初始化**：检查两个初始化变量、容器日志和数据挂载，更新环境变量后需要重新创建容器。
- **浏览器登录功能失败**：在 NAS 上查看应用日志，确认内存和共享内存充足；闲鱼登录、验证码和平台接口仍需要 NAS 访问相关外部服务。
