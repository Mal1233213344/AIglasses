$base = 'http://localhost:3000/api'
$phone = '13800138000'
$deviceId = 'demo-device-001'
$deviceToken = 'dev-device-token'

# 1. Login
$loginBody = @{ 
    phone = $phone; 
    smsCode = '123456'; 
    loginDevice = @{ platform = 'android'; appVersion = '0.1.0'; deviceModel = 'emulator'; osVersion = 'android' } 
} | ConvertTo-Json -Depth 5
$loginResp = Invoke-RestMethod -Method Post -Uri "$base/app/v1/auth/login" -ContentType 'application/json' -Body $loginBody
$token = $loginResp.data.accessToken

# 2. Login as Admin
$adminLoginBody = @{ username = 'admin'; password = 'admin123' } | ConvertTo-Json
$adminLoginResp = Invoke-RestMethod -Method Post -Uri "$base/admin/auth/login" -ContentType 'application/json' -Body $adminLoginBody
$adminToken = $adminLoginResp.data.token
"Admin Logged in"

# Ensure a firmware package exists
$pkgBody = @{
    modelCode = 'PRO'
    version = '2.0.0'
    objectKey = 'firmware/v2.0.0.bin'
    fileSizeBytes = '12582912'
    checksumSha256 = 'sha256hash'
    releaseNotes = 'Critical security update'
} | ConvertTo-Json
try {
    $pkgResp = Invoke-RestMethod -Method Post -Uri "$base/admin/v1/content/firmware" -ContentType 'application/json' -Headers @{ Authorization = "Bearer $adminToken" } -Body $pkgBody
    $pkgId = $pkgResp.data.id
    Invoke-RestMethod -Method Patch -Uri "$base/admin/v1/content/firmware/$pkgId/status" -ContentType 'application/json' -Headers @{ Authorization = "Bearer $adminToken" } -Body (@{ status = 'published' } | ConvertTo-Json) | Out-Null
    "Created and published firmware package 2.0.0"
} catch {
    "Firmware package might already exist"
}

# 3. Check OTA Update from App
$checkResp = Invoke-RestMethod -Method Get -Uri "$base/app/v1/devices/$deviceId/ota/check" -Headers @{ Authorization = "Bearer $token" }
"OTA Check hasUpdate: $($checkResp.data.hasUpdate)"

# 4. Start OTA Upgrade from App
$pkgId = $checkResp.data.package.id
if ($pkgId) {
    $upgradeResp = Invoke-RestMethod -Method Post -Uri "$base/app/v1/devices/$deviceId/ota/tasks" -ContentType 'application/json' -Headers @{ Authorization = "Bearer $token" } -Body (@{ packageId = $pkgId } | ConvertTo-Json)
    $taskId = $upgradeResp.data.otaTask.id
    "OTA Task created: $taskId"

    # 5. Device side: report progress
    $progressBody = @{
        status = 'downloading'
        progressPercent = 45
    } | ConvertTo-Json
    Invoke-RestMethod -Method Post -Uri "$base/device/v1/ota/tasks/$taskId/progress" -ContentType 'application/json' -Headers @{ 'x-device-token' = $deviceToken } -Body $progressBody | Out-Null
    "Device reported progress: 45%"
} else {
    "No update available to test upgrade flow"
}

# 6. App side: check progress again
$checkResp2 = Invoke-RestMethod -Method Get -Uri "$base/app/v1/devices/$deviceId/ota/check" -Headers @{ Authorization = "Bearer $token" }
"App sees OTA status: $($checkResp2.data.status) ($($checkResp2.data.progress)%)"
