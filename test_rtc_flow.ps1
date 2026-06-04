$base = 'http://localhost:3000/api'
$phone = '13800138000'
$deviceId = 'demo-device-001'

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

# 3. Start RTC Session
$rtcStartBody = @{ deviceId = $deviceId; type = 'video' } | ConvertTo-Json
$startResp = Invoke-RestMethod -Method Post -Uri "$base/app/v1/rtc/session/start" -ContentType 'application/json' -Headers @{ Authorization = "Bearer $token" } -Body $rtcStartBody
"RTC Session started: $($startResp.sessionId)"

# 4. Check Dashboard
$statsResp = Invoke-RestMethod -Method Get -Uri "$base/admin/v1/dashboard/stats" -Headers @{ Authorization = "Bearer $adminToken" }
"Dashboard RTC sessions: $($statsResp.data.rtc.activeSessions)"

# 5. Stop RTC Session
$rtcStopBody = @{ deviceId = $deviceId; type = 'video' } | ConvertTo-Json
$stopResp = Invoke-RestMethod -Method Post -Uri "$base/app/v1/rtc/session/stop" -ContentType 'application/json' -Headers @{ Authorization = "Bearer $token" } -Body $rtcStopBody
"RTC Session stopped: $($stopResp.success)"

# 6. Check Dashboard again
$statsResp2 = Invoke-RestMethod -Method Get -Uri "$base/admin/v1/dashboard/stats" -Headers @{ Authorization = "Bearer $adminToken" }
"Dashboard RTC sessions after stop: $($statsResp2.data.rtc.activeSessions)"
