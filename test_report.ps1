$base = 'http://localhost:3000/api'
$loginBody = @{ 
    phone = '13800138000'; 
    smsCode = '123456'; 
    loginDevice = @{ 
        platform = 'android';
        appVersion = '1.0.0';
        deviceModel = 'MI 10';
        osVersion = 'Android 13'
    } 
} | ConvertTo-Json
$loginResp = Invoke-RestMethod -Method Post -Uri "$base/app/v1/auth/login" -ContentType 'application/json' -Body $loginBody
$token = $loginResp.data.accessToken

$reportDate = (Get-Date).ToString("yyyy-MM-dd")
$reportData = @{
    deviceId = 'demo-device-001'
    reportType = 'daily'
    reportDate = $reportDate
} | ConvertTo-Json

$report = Invoke-RestMethod -Method Post -Uri "$base/app/v1/learning/reports" -Headers @{ Authorization = "Bearer $token" } -ContentType 'application/json' -Body $reportData
$report.data | ConvertTo-Json -Depth 5
