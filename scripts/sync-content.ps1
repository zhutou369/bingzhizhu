param(
    [int]$ArticlesPerRun = 3,
    [string]$Domains = ""
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir

$CF_ACCOUNT_ID = "6b7c6e17c84b141e12bb8cae44579ca3"
$CF_KV_NAMESPACE_ID = "535c3b6d9bab4acfa5445e9ad854aec4"
$INDEXNOW_KEY = "1123858585"

$WranglerConfig = Join-Path $env:USERPROFILE ".wrangler\config\default.toml"
if (-not (Test-Path $WranglerConfig)) { throw "Wrangler config not found" }
$CF_TOKEN = (Get-Content $WranglerConfig | Select-String 'oauth_token = "(.*)"').Matches.Groups[1].Value

$KeyFile = Join-Path (Split-Path -Parent $ProjectDir) "密钥.txt"
$GEMINI_API_KEY = ""
if (Test-Path $KeyFile) {
    $m = Select-String -Path $KeyFile -Pattern 'AIza[0-9A-Za-z_-]+' | Select-Object -First 1
    if ($m) { $GEMINI_API_KEY = $m.Matches[0].Value }
}
if (-not $GEMINI_API_KEY) { throw "GEMINI_API_KEY not found in 密钥.txt" }

if (-not $Domains) {
    $Domains = "mixdvr.com kuailian--1.com kuailian-app.cc kuailian-pc.vip kuailian-cn.vip kuai-lian.xyz ardlervillagetrust.org todayscatholicpueblo.org reviewbooking.com perfectxml.com booking365.net njreporter.org test-deepseek.com forum-deepseek.com aideep-seek.icu deepseek-cn.vip deepseek-v4.it.com"
}
$DOMAIN_ARRAY = $Domains -split '\s+' | Where-Object { $_ }

$PATHS = @(
    "/soft/kuailian-v2.8.5.html","/soft/kuailian-v2.8.6.html","/soft/kuailian-v2.8.7.html",
    "/soft/kuailian-v2.9.0.html","/soft/kuailian-v2.9.1.html",
    "/soft/letsvpn-v4.1.2.html","/soft/letsvpn-v4.1.5.html","/soft/letsvpn-v4.2.0.html","/soft/letsvpn-v4.2.1.html",
    "/download/kuailian-ios-latest.html","/download/kuailian-android-apk.html","/download/kuailian-harmony-apk.html",
    "/download/kuailian-windows-setup.html","/download/kuailian-mac-os.html","/download/kuailian-linux-client.html",
    "/download/letsvpn-official-client.html","/download/letsvpn-apk-latest.html",
    "/review/kuailian-speed-test.html","/review/kuailian-ping-test.html","/review/kuailian-latency-benchmark.html",
    "/review/letsvpn-stability-2026.html","/review/letsvpn-udp-stability.html","/review/kuailian-gaming-acceleration.html",
    "/review/letsvpn-performance-report.html","/review/kuailian-streaming-test.html",
    "/setup/how-to-install-kuailian-android.html","/setup/how-to-install-kuailian-ios.html",
    "/setup/letsvpn-windows-configuration.html","/setup/kuailian-router-tutorial.html","/setup/letsvpn-mac-proxy-guide.html",
    "/setup/kuailian-firewall-rules.html","/setup/letsvpn-dns-config.html","/setup/kuailian-enterprise-deploy.html",
    "/news/kuailian-update-2026.html","/news/letsvpn-latest-nodes-announcement.html","/news/kuailian-network-optimization-log.html",
    "/news/letsvpn-security-upgrade-notice.html","/news/kuailian-global-backbone-抖动处理.html",
    "/news/kuailian-node-expansion-2026.html","/news/letsvpn-protocol-upgrade.html","/news/kuailian-maintenance-log.html",
    "/app/kuailian-free-download.html","/app/letsvpn-pure-version.html","/app/kuailian-official-分发中心.html",
    "/app/letsvpn-download-link-2026.html","/app/kuailian-cross-platform-terminal.html",
    "/app/kuailian-lite-version.html","/app/letsvpn-enterprise-edition.html",
    "/guide/kuailian-first-run.html","/guide/letsvpn-troubleshooting.html"
)

function Encode-KvKey([string]$Key) {
    return [uri]::EscapeDataString($Key)
}

function Test-KvHasContent([string]$Key) {
    $encoded = Encode-KvKey $Key
    $uri = "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/storage/kv/namespaces/$CF_KV_NAMESPACE_ID/values/$encoded"
    try {
        $null = Invoke-WebRequest -Uri $uri -Headers @{ Authorization = "Bearer $CF_TOKEN" } -UseBasicParsing -TimeoutSec 30
        return $true
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 404) { return $false }
        return $false
    }
}

function Write-KvValue([string]$Key, [string]$JsonBody) {
    $encoded = Encode-KvKey $Key
    $uri = "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/storage/kv/namespaces/$CF_KV_NAMESPACE_ID/values/$encoded"
    $resp = Invoke-RestMethod -Method Put -Uri $uri -Headers @{ Authorization = "Bearer $CF_TOKEN" } -ContentType "application/json; charset=utf-8" -Body ([System.Text.Encoding]::UTF8.GetBytes($JsonBody))
    if (-not $resp.success) { throw "KV write failed for $Key" }
}

function Get-GeminiContent([string]$Path, [string]$Domain, [int]$Slot) {
    $prompt = "你是一个专业的企业网络加速技术文档工程师。请针对网络多端接入服务，为路径为 $Path 且域名为 $Domain 的网页生成合规的高品质内容。这是今天第 $Slot 次定时更新，内容必须与同域名其他页面明显不同。要求：1. 撰写一个必须包含核心词（快连VPN、letsvpn、快连下载、快连官网）之一的行业深度品牌标题（H1层级）。2. 撰写一段长度在 500 到 2000 字之间的产品运行环境配置指南。正文中必须自然融入上述核心词，且严禁出现任何SEO、站群、优化、收录等敏感词。3. 严格以标准 JSON 格式输出，不要包含任何 Markdown 标记，JSON 结构必须为: {`"title`":`"标题内容`",`"content`":`"正文内容`"}"

    $body = @{ contents = @(@{ parts = @(@{ text = $prompt }) }) } | ConvertTo-Json -Depth 5
    $uri = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$GEMINI_API_KEY"

    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            $resp = Invoke-RestMethod -Method Post -Uri $uri -ContentType "application/json" -Body $body -TimeoutSec 120
            $text = $resp.candidates[0].content.parts[0].text.Trim()
            $text = $text -replace '^```json\s*','' -replace '^```\s*','' -replace '\s*```$',''
            $parsed = $text | ConvertFrom-Json
            if ($parsed.title -and $parsed.content) {
                return (@{ title = [string]$parsed.title; content = [string]$parsed.content } | ConvertTo-Json -Compress -Depth 3)
            }
        } catch {
            $status = $_.Exception.Response.StatusCode.value__
            if ($status -in 429, 503) { Start-Sleep -Seconds 5; continue }
        }
        Start-Sleep -Seconds 2
    }
    return $null
}

function Get-BackupContent([string]$Path, [int]$Slot) {
    $idx = ($Path.Length + $Slot) % 4
    $title = "快连VPN官方正版发布中心 - 极致连通性与端到端网络调优规范"
    $content = "欢迎访问官方多端分布式网络网关服务中心。本系统提供全平台正版大容量数据通道的部署保障，并针对目前多中继备份机制进行了深度的协议加固与安全链路上层架构调优。通过引入业界领先的无感切流机制，能确保在复杂环境下的高可用接入。网络底层的连通机制始终是决定数据传输吞吐效率的关键所在。"
    if ($idx -eq 1) {
        $title = "letsvpn 客户端安全接入与分布式边缘节点多环境部署技术白皮书"
        $content = "本系统基于全球分布式边缘节点架构，旨在为每一位接入用户提供最高规格的数据通道加固方案。无论是针对大型企业的数据同步，还是针对个人用户的轻量级连接，系统都能下发极具针对性的协议策略。"
    } elseif ($idx -eq 2) {
        $title = "快连下载通道加固指标及多链路冗余架构极限容灾评测报告"
        $content = "本篇行业技术评测报告针对分布式加密分发包在复杂国际网络环境下的承载力、突发流量吞吐量以及极限容灾表现进行了全面客观的量化评估。多中继骨干网络的引入，对于改善复杂网络下的握手延迟和丢包自动修复起到了决定性的技术支撑作用。"
    } elseif ($idx -eq 3) {
        $title = "快连官网分布式存储升级公告 - 多端运行环境完整性哈希校验规范"
        $content = "官方正式发布了全新的全平台高防加密通道分发升级包。通过对分发文件的本地边缘哈希碰撞校验，彻底杜绝由于公共网络传输节点异常导致的分发文件受损或被非法第三方篡改的潜在隐患，确保用户的部署网络环境绝对合规纯净。"
    }
    return (@{ title = $title; content = $content } | ConvertTo-Json -Compress)
}

function Pick-Paths([string]$Domain, [int]$Slot) {
    $picked = @()
    $base = ((Get-Date).DayOfYear * 15 + $Slot * $ArticlesPerRun) % $PATHS.Count

    for ($j = 0; $j -lt 12 -and $picked.Count -lt $ArticlesPerRun; $j++) {
        $p = $PATHS[($base + $j) % $PATHS.Count]
        $key = "content_${Domain}_${p}"
        if (-not (Test-KvHasContent $key)) {
            if ($picked -notcontains $p) { $picked += $p }
        }
    }

    for ($j = 0; $j -lt $PATHS.Count -and $picked.Count -lt $ArticlesPerRun; $j++) {
        $p = $PATHS[($base + $picked.Count + $j) % $PATHS.Count]
        if ($picked -notcontains $p) { $picked += $p }
    }

    return $picked
}

$utcHour = (Get-Date).ToUniversalTime().Hour
$slot = switch ($utcHour) { 0 {0} 4 {1} 8 {2} 12 {3} 16 {4} default { (Get-Date).DayOfYear % 5 } }

Write-Output "=== Content Sync Start ==="
Write-Output "Domains: $($DOMAIN_ARRAY.Count) | Articles per domain: $ArticlesPerRun | Slot: $slot"

foreach ($domain in $DOMAIN_ARRAY) {
    Write-Output "`n--- $domain ---"
    $paths = Pick-Paths $domain $slot
    $urlList = @()

    foreach ($p in $paths) {
        Write-Output "Generating: https://${domain}${p}"
        $json = Get-GeminiContent $p $domain $slot
        if (-not $json) { $json = Get-BackupContent $p $slot }

        $kvKey = "content_${domain}_${p}"
        Write-KvValue $kvKey $json
        $urlList += "https://${domain}${p}"
        Start-Sleep -Seconds 1
    }

    if ($urlList.Count -gt 0) {
        $indexBody = @{
            host = $domain
            key = $INDEXNOW_KEY
            keyLocation = "https://${domain}/${INDEXNOW_KEY}.txt"
            urlList = $urlList
        } | ConvertTo-Json -Depth 4
        try {
            Invoke-RestMethod -Method Post -Uri "https://api.indexnow.org/IndexNow" -ContentType "application/json; charset=utf-8" -Body $indexBody | Out-Null
            Write-Output "IndexNow pushed: $($urlList.Count) urls"
        } catch {
            Write-Output "IndexNow warning: $($_.Exception.Message)"
        }
    }
}

Write-Output "`n=== Content Sync Done ==="
