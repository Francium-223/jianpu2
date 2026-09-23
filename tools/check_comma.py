# -*- coding: utf-8 -*-
import sys; sys.path.insert(0,'tools')
from token_json import token_to_json
for t in ['q,6','q6,','q,7','q7,']:
    j=token_to_json(t)
    print(f"{t:6s} -> digit={j['digit']} low={j['low']} voice={j['voice']} beam={j['beam']}")
