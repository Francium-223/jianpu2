# tunnel_up.ps1 —— 薄壳：把活交给 tools\tunnel_up.py
#
# 逻辑**只有一份**，在 Python 里（`tools/tunnel_up.py`）。原因: 有台目标机器**没有 PowerShell**，
# 所以主入口是 `tunnel_up.cmd`（纯 cmd）；这份 .ps1 只是给"手边正好有 PowerShell"的人留的同名入口，
# 免得两套实现各写一遍、日子久了对不上（本项目已经吃过"两份实现漂移"的亏）。
#
# 用法:  pwsh -File tools\tunnel_up.ps1                （参数原样转给 .py，如 --port 8790）
$HERE = Split-Path -Parent $MyInvocation.MyCommand.Path
$py = if (Get-Command py -ErrorAction SilentlyContinue) { 'py' } else { 'python' }
if ($py -eq 'py') { & py -3 "$HERE\tunnel_up.py" @args } else { & python "$HERE\tunnel_up.py" @args }
exit $LASTEXITCODE
