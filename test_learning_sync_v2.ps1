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
"Login success, token: $($token.Substring(0, 10))..."

# 2. Sync
$batchId = [guid]::NewGuid().ToString()
$learningBody = @{
    deviceId = $deviceId
    batchId = $batchId
    stats = @{
        studyMinutes = 30
        recognizedWordCount = 5
        followReadCount = 3
    }
    words = @(
        @{
            word = 'Hello'
            phonetic = '/həˈləʊ/'
            meaningCn = '你好'
            recognizedAt = (Get-Date).AddMinutes(-10).ToString("yyyy-MM-ddTHH:mm:ssZ")
        },
        @{
            word = 'World'
            phonetic = '/wɜːld/'
            meaningCn = '世界'
            recognizedAt = (Get-Date).AddMinutes(-5).ToString("yyyy-MM-ddTHH:mm:ssZ")
        }
    )
} | ConvertTo-Json -Depth 10
$syncResp = Invoke-RestMethod -Method Post -Uri "$base/device/v1/learning-sync" -ContentType 'application/json' -Headers @{ 'x-device-token' = $deviceToken } -Body $learningBody
"Sync Result: $($syncResp | ConvertTo-Json -Depth 2)"

# 3. Verify Summary
$summaryResp = Invoke-RestMethod -Method Get -Uri "$base/app/v1/learning/summary?deviceId=$deviceId" -Headers @{ Authorization = "Bearer $token" }
"Summary Result: $($summaryResp.data | ConvertTo-Json -Depth 2)"
