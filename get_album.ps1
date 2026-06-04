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

$album = Invoke-RestMethod -Method Get -Uri "$base/app/v1/album/photos?deviceId=demo-device-001" -Headers @{ Authorization = "Bearer $token" }
$album.data | ConvertTo-Json -Depth 5
