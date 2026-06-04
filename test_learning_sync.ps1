$base = 'http://localhost:3000/api'
$phone = '13800138000'
$deviceId = 'demo-device-001'
$deviceToken = 'dev-device-token'

# 1. Login to get user token and ID
$loginBody = @{ 
    phone = $phone; 
    smsCode = '123456'; 
    loginDevice = @{ platform = 'android'; appVersion = '0.1.0'; deviceModel = 'emulator'; osVersion = 'android' } 
} | ConvertTo-Json -Depth 5
$loginResp = Invoke-RestMethod -Method Post -Uri "$base/app/v1/auth/login" -ContentType 'application/json' -Body $loginBody
$token = $loginResp.data.accessToken
$userId = $loginResp.data.user.id
"Logged in as userId: $userId"

# 2. Ensure device is bound (if not already)
$bindBody = @{
    deviceId = $deviceId
    modelCode = 'PRO'
    bluetoothMac = 'AA:BB:CC:DD:EE:FF'
    deviceName = '星星AI英语眼镜'
} | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "$base/app/v1/devices/bind" -ContentType 'application/json' -Headers @{ Authorization = "Bearer $token" } -Body $bindBody | Out-Null
"Device $deviceId bound to user $userId"

# 3. Simulate Device Status Report (to mark it active)
$statusBody = @{
    deviceId = $deviceId
    modelCode = 'PRO'
    firmwareVersion = '1.0.0'
    onlineStatus = 'online'
    batteryLevel = 88
    bluetoothConnected = $true
    wifiConnected = $true
    mode = 'normal'
} | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "$base/device/v1/status-reports" -ContentType 'application/json' -Headers @{ 'x-device-token' = $deviceToken } -Body $statusBody | Out-Null
"Device status reported"

# 4. Simulate Learning Data Sync (Words & Practices)
$batchId = [guid]::NewGuid().ToString()
$learningBody = @{
    deviceId = $deviceId
    batchId = $batchId
    stats = @{
        studyMinutes = 15
        recognizedWordCount = 2
        followReadCount = 1
    }
    words = @(
        @{
            word = 'Apple'
            phonetic = '/ˈæp.əl/'
            meaningCn = '苹果'
            recognizedAt = (Get-Date).AddMinutes(-10).ToString("yyyy-MM-ddTHH:mm:ssZ")
        },
        @{
            word = 'Banana'
            phonetic = '/bəˈnɑː.nə/'
            meaningCn = '香蕉'
            recognizedAt = (Get-Date).AddMinutes(-5).ToString("yyyy-MM-ddTHH:mm:ssZ")
        }
    )
    practices = @(
        @{
            sentenceText = 'I like eating apples.'
            score = 85
            issueTags = @('intonation')
            practicedAt = (Get-Date).AddMinutes(-2).ToString("yyyy-MM-ddTHH:mm:ssZ")
        }
    )
} | ConvertTo-Json -Depth 10
$syncResp = Invoke-RestMethod -Method Post -Uri "$base/device/v1/learning-sync" -ContentType 'application/json' -Headers @{ 'x-device-token' = $deviceToken } -Body $learningBody
"Learning data synced: $($syncResp.accepted)"

# 5. Verify App-side APIs
$summaryResp = Invoke-RestMethod -Method Get -Uri "$base/app/v1/learning/summary?deviceId=$deviceId" -Headers @{ Authorization = "Bearer $token" }
"Summary learnMinutes: $($summaryResp.data.learnMinutes)"

$wordsResp = Invoke-RestMethod -Method Get -Uri "$base/app/v1/learning/words?deviceId=$deviceId" -Headers @{ Authorization = "Bearer $token" }
"Words count: $($wordsResp.data.length)"
foreach ($w in $wordsResp.data) { "  - $($w.word)" }

$practicesResp = Invoke-RestMethod -Method Get -Uri "$base/app/v1/learning/practices?deviceId=$deviceId" -Headers @{ Authorization = "Bearer $token" }
"Practices count: $($practicesResp.data.length)"
foreach ($p in $practicesResp.data) { "  - $($p.sentenceText) (score: $($p.score))" }
