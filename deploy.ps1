# 部署脚本
Write-Host "开始部署 AI Glasses 系统..." -ForegroundColor Green

# 切换到项目根目录
cd "d:\AI Glasses"

# 构建 API 服务器
Write-Host "构建 API 服务器..." -ForegroundColor Cyan
cd "services\api-server"
npm run build
if ($LASTEXITCODE -ne 0) {
    Write-Host "API 服务器构建失败！" -ForegroundColor Red
    exit 1
}
Write-Host "API 服务器构建成功！" -ForegroundColor Green

# 构建 Web 管理后台
Write-Host "构建 Web 管理后台..." -ForegroundColor Cyan
cd "..\admin-web"
npm run build
if ($LASTEXITCODE -ne 0) {
    Write-Host "Web 管理后台构建失败！" -ForegroundColor Red
    exit 1
}
Write-Host "Web 管理后台构建成功！" -ForegroundColor Green

# 启动 API 服务器
Write-Host "启动 API 服务器..." -ForegroundColor Cyan
cd "..\api-server"
Start-Process "npm" -ArgumentList "run start" -NoNewWindow
Write-Host "API 服务器已启动！" -ForegroundColor Green

# 启动 Web 管理后台
Write-Host "启动 Web 管理后台..." -ForegroundColor Cyan
cd "..\admin-web"
Start-Process "npm" -ArgumentList "run preview" -NoNewWindow
Write-Host "Web 管理后台已启动！" -ForegroundColor Green

# 显示部署完成信息
Write-Host "部署完成！" -ForegroundColor Green
Write-Host "API 服务器地址: http://localhost:3002/api" -ForegroundColor Yellow
Write-Host "Web 管理后台地址: http://localhost:4173" -ForegroundColor Yellow
Write-Host "Swagger 文档地址: http://localhost:3002/api/docs" -ForegroundColor Yellow
