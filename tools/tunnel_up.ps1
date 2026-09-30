# 起一条 Cloudflare 快速隧道, 把本机 8770 发给公网, 并自动把地址写进 Worker 的 API_UPSTREAM
#
# 为什么需要它: 本机没有可用的入向公网地址（家用宽带 + 出口 IP 会变），站点要能"投稿/补标签"就得
# 让边缘的 Worker 知道"本机在哪儿"。快速隧道不需要登录、不需要公网 IP、不需要端口映射 —— 代价是
# **每次重启换地址**，所以地址变了要重新写一次 secret；这个脚本就是把"起隧道 + 读地址 + 写 secret"
# 串成一条命令（这三步 2026-09-30 都手工跑通并验过）。
#
# 用法（在 jianpu2 仓库根或任意处）:
#   pwsh -File tools\tunnel_up.ps1
#   pwsh -File tools\tunnel_up.ps1 -Port 8770 -SiteRepo D:\Documents_D\jianpu-db.github.io
#
# ⚠ 两条纪律:
#   ① 本机服务**必须**设 `JPSUBMIT_TOKEN`（它与 Worker 的 `API_TOKEN` 同值）—— 否则谁拿到隧道地址
#      都能往语料仓库里写东西。脚本会检查服务是否要求 token，不要求就**拒绝继续**。
#   ② secret 名 `API_UPSTREAM` **不能**同时出现在 `wrangler.jsonc` 的 `vars` 里（会报 code 10053）。
param(
  [int]$Port = 8770,
  [string]$SiteRepo = 'D:\Documents_D\jianpu-db.github.io',
  [string]$Log = 'D:\Documents_D\_analysis\tunnel.log'
)
$ErrorActionPreference = 'Stop'
$CF = 'C:\Program Files (x86)\cloudflared\cloudflared.exe'
if (-not (Test-Path $CF)) { throw "没装 cloudflared: $CF" }
if (-not (Test-Path $SiteRepo)) { throw "站点仓库不在: $SiteRepo" }

# ① 本机服务在不在、要不要 token
try { $h = Invoke-RestMethod "http://127.0.0.1:$Port/api/health" -TimeoutSec 8 }
catch { throw "本机服务没在跑（http://127.0.0.1:$Port/api/health 取不到）。先起 app/server.py。" }
if (-not $h.token_required) {
  throw ("本机服务**没有**要求 X-Token —— 隧道一开等于把写接口挂公网。`n" +
         "  先带 JPSUBMIT_TOKEN 重启服务，并把同一个值 `npx wrangler secret put API_TOKEN` 写进 Worker。")
}
"✓ 本机服务在跑, 且要求 X-Token（repo=$($h.repo)）"

# ② 起隧道, 从日志里读出地址(等到出现为止, 最多 60 秒)
$before = if (Test-Path $Log) { Get-Content $Log -Raw } else { '' }
Start-Process -FilePath $CF -ArgumentList 'tunnel', '--url', "http://127.0.0.1:$Port", '--no-autoupdate', '--logfile', $Log -WindowStyle Hidden
$url = ''
for ($i = 0; $i -lt 30; $i++) {
  Start-Sleep -Seconds 2
  $txt = if (Test-Path $Log) { Get-Content $Log -Raw } else { '' }
  $m = [regex]::Match($txt, 'https://[a-z0-9-]+\.trycloudflare\.com')
  if ($m.Success) { $url = $m.Value; break }
}
if (-not $url) { throw "60 秒内没等到隧道地址, 看日志: $Log" }
"✓ 隧道: $url"

# ③ 把地址写进 Worker（这一步会新建一个 Worker 版本, 不用重新 deploy）
Push-Location $SiteRepo
try {
  $url | & npx wrangler secret put API_UPSTREAM 2>&1 | Select-String -Pattern 'Success|ERROR' | ForEach-Object { "  $_" }
} finally { Pop-Location }

# ④ 验证: 域名 health 里 api 应为 true、upstream 应是这条地址
Start-Sleep -Seconds 8
try {
  $j = Invoke-RestMethod 'https://jianpu-db.org/api/health' -TimeoutSec 20
  "✓ 域名 health: api=$($j.api)  upstream=$($j.upstream)  og=$($j.og)"
  if (-not $j.api) { "  ! api 还是 false —— secret 可能没生效, 稍等或重跑本脚本" }
} catch { "  ! 域名 health 取不到: $_" }

"`n把地址与本机 token 记在这儿（该目录 gitignore）: D:\Documents_D\jianpu2\train-work\tunnel_secret.txt"
"想固定地址: 跑一次 `cloudflared tunnel login` 授权, 再用命名隧道绑 api.jianpu-db.org。"
