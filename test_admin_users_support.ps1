$base = 'http://localhost:3000/api'
$phone = '13800138000'

# 1. Login as App User
$loginBody = @{ 
    phone = $phone; 
    smsCode = '123456'; 
    loginDevice = @{ platform = 'android'; appVersion = '0.1.0'; deviceModel = 'emulator'; osVersion = 'android' } 
} | ConvertTo-Json -Depth 5
$loginResp = Invoke-RestMethod -Method Post -Uri "$base/app/v1/auth/login" -ContentType 'application/json' -Body $loginBody
$token = $loginResp.data.accessToken
"App User Logged in"

# 2. Submit Feedback
$feedbackBody = @{
    category = '功能问题'
    title = '测试反馈'
    description = '这是一个通过脚本提交的测试反馈'
} | ConvertTo-Json
$feedbackResp = Invoke-RestMethod -Method Post -Uri "$base/app/v1/support/feedback" -ContentType 'application/json' -Headers @{ Authorization = "Bearer $token" } -Body $feedbackBody
"Feedback submitted, ID: $($feedbackResp.id)"

# 3. Login as Admin
$adminLoginBody = @{ username = 'admin'; password = 'admin123' } | ConvertTo-Json
$adminLoginResp = Invoke-RestMethod -Method Post -Uri "$base/admin/auth/login" -ContentType 'application/json' -Body $adminLoginBody
$adminToken = $adminLoginResp.data.token
"Admin Logged in"

# 4. List Users
$usersResp = Invoke-RestMethod -Method Get -Uri "$base/admin/v1/users" -Headers @{ Authorization = "Bearer $adminToken" }
"Admin found $($usersResp.total) users"

# 5. List Support Tickets
$ticketsResp = Invoke-RestMethod -Method Get -Uri "$base/admin/v1/support/tickets" -Headers @{ Authorization = "Bearer $adminToken" }
"Admin found $($ticketsResp.total) tickets"
foreach ($t in $ticketsResp.items) { "  - [$($t.status)] $($t.title)" }

# 6. Close Ticket
$ticketId = $ticketsResp.items[0].id
$updateResp = Invoke-RestMethod -Method Patch -Uri "$base/admin/v1/support/tickets/$ticketId/status" -ContentType 'application/json' -Headers @{ Authorization = "Bearer $adminToken" } -Body (@{ status = 'closed' } | ConvertTo-Json)
"Ticket $ticketId status updated to $($updateResp.status)"
