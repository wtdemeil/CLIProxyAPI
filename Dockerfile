# ===== 阶段一：编译前端管理面板 =====
FROM node:22-alpine AS frontend-builder

RUN apk add --no-cache git

WORKDIR /frontend

# 从 GitHub 克隆前端项目（使用你自己的 fork 仓库）
RUN git clone --depth 1 https://github.com/wtdemeil/Cli-Proxy-API-Management-Center.git .

RUN npm install --frozen-lockfile || npm install

RUN npm run build && mv dist/index.html dist/management.html

# ===== 阶段二：编译后端 =====
FROM golang:1.26-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./

RUN go mod download

COPY . .

ARG VERSION=dev
ARG COMMIT=none
ARG BUILD_DATE=unknown

RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w -X 'main.Version=${VERSION}' -X 'main.Commit=${COMMIT}' -X 'main.BuildDate=${BUILD_DATE}'" -o ./CLIProxyAPI ./cmd/server/

# ===== 阶段三：最终镜像 =====
FROM alpine:3.22.0

RUN apk add --no-cache tzdata

RUN mkdir -p /CLIProxyAPI/static

COPY --from=builder ./app/CLIProxyAPI /CLIProxyAPI/CLIProxyAPI
COPY --from=frontend-builder /frontend/dist/management.html /CLIProxyAPI/static/management.html

COPY config.example.yaml /CLIProxyAPI/config.example.yaml

WORKDIR /CLIProxyAPI

EXPOSE 8317

ENV TZ=Asia/Shanghai
# 指向本地编译的管理面板，防止被自动更新覆盖
ENV MANAGEMENT_STATIC_PATH=/CLIProxyAPI/static/management.html

RUN cp /usr/share/zoneinfo/${TZ} /etc/localtime && echo "${TZ}" > /etc/timezone

CMD ["./CLIProxyAPI"]