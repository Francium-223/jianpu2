@echo off
rem 页面元数据抓完 -> 重新打标签 -> 验收。给计划任务用(见 mandopop_absorb3.ps1 的口径)。
cd /d D:\Documents_D\jianpu2
set PY=py -3.13
echo ===== %DATE% %TIME% harvest_page_meta =====
%PY% tools\harvest_page_meta.py
echo ===== %DATE% %TIME% tag_ocr_scores --apply =====
%PY% tools\tag_ocr_scores.py --apply
echo ===== %DATE% %TIME% verify =====
%PY% tools\verify_ocr_tags.py
echo ===== %DATE% %TIME% done =====
