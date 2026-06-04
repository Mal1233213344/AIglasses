$base = 'http://localhost:3000/api'
$loginBody = @{ 
    phone = '13800138000'; 
    smsCode = '123456'; 
    loginDevice = @{ platform = 'android'; appVersion = '0.1.0'; deviceModel = 'emulator'; osVersion = 'android' } 
} | ConvertTo-Json -Depth 5
$loginResp = Invoke-RestMethod -Method Post -Uri "$base/app/v1/auth/login" -ContentType 'application/json' -Body $loginBody
$token = $loginResp.data.accessToken

$devices = Invoke-RestMethod -Method Get -Uri "$base/app/v1/devices" -Headers @{ Authorization = "Bearer $token" }
$devices | ConvertTo-Json -Depth 5
