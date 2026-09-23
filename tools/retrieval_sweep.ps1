# -*- coding: utf-8 -*-
# 跑旋律片段检索评测的全表(L=7/9/11 × 错音 0/1/2), 结果写 train-work/retrieval_sweep.log
# 纯 CPU(numpy 滑窗), 不占 GPU。
$root = "D:\Documents_D\jianpu2"
Set-Location $root
$log = "train-work\retrieval_sweep.log"
"{0}  ================ 检索评测扫描开始 ================" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") |
    Tee-Object -FilePath $log -Append
py -3.13 tools/melody_retrieval_eval.py --sweep *>> $log
"{0}  退出码 $LASTEXITCODE" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") | Tee-Object -FilePath $log -Append
"{0}  ================ 结束 ================" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") |
    Tee-Object -FilePath $log -Append
