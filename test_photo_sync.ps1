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

# 2. Sync Photos
$photoSyncBody = @{
    deviceId = $deviceId
    photos = @(
        @{
            fileName = "IMG_$(Get-Date -Format 'yyyyMMdd_HHmmss')_1.jpg"
            captureTime = (Get-Date).AddMinutes(-30).ToString("yyyy-MM-ddTHH:mm:ssZ")
            fileSizeBytes = 102400
            width = 1280
            height = 720
            photoUrl = "https://picsum.photos/800/600?random=1"
            thumbnailUrl = "https://picsum.photos/200/150?random=1"
        },
        @{
            fileName = "IMG_$(Get-Date -Format 'yyyyMMdd_HHmmss')_2.jpg"
            captureTime = (Get-Date).AddMinutes(-25).ToString("yyyy-MM-ddTHH:mm:ssZ")
            fileSizeBytes = 112400
            width = 1280
            height = 720
            photoUrl = "https://picsum.photos/800/600?random=2"
            thumbnailUrl = "https://picsum.photos/200/150?random=2"
        }
    )
} | ConvertTo-Json -Depth 10
$syncResp = Invoke-RestMethod -Method Post -Uri "$base/device/v1/photos/sync" -ContentType 'application/json' -Headers @{ 'x-device-token' = $deviceToken } -Body $photoSyncBody
"Sync Result: $($syncResp | ConvertTo-Json -Depth 2)"

# 3. Verify App-side Album
$albumResp = Invoke-RestMethod -Method Get -Uri "$base/app/v1/album/photos?deviceId=$deviceId" -Headers @{ Authorization = "Bearer $token" }
"Album Result Count: $($albumResp.data.total)"
foreach ($p in $albumResp.data.items) { "  - $($p.fileName) ($($p.photoUrl))" }
