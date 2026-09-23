# -*- coding: utf-8 -*-
"""0/1 背包: 黑板上的状态转移 dp[i][j] = max(dp[i-1][j], dp[i-1][j-cost[i]] + value[i])
实现: 二维版 + 一维滚动数组版(空间 O(cap))。
返回 最大价值 与 具体选中的物品下标。"""

def knapsack_2d(cost, value, cap):
    """二维 O(n*cap) 空间版。返回 (max_value, dp表, choice选物品下标)"""
    n = len(cost)
    dp = [[0] * (cap + 1) for _ in range(n + 1)]
    for i in range(1, n + 1):
        c, v = cost[i - 1], value[i - 1]
        for j in range(cap + 1):
            if j < c:
                dp[i][j] = dp[i - 1][j]                 # 装不下, 不选
            else:
                dp[i][j] = max(dp[i - 1][j], dp[i - 1][j - c] + v)
    # 回溯选中的物品
    picked, j = [], cap
    for i in range(n, 0, -1):
        if dp[i][j] != dp[i - 1][j]:                    # 说明选了 i
            picked.append(i - 1)
            j -= cost[i - 1]
    picked.reverse()
    return dp[n][cap], dp, picked


def knapsack_1d(cost, value, cap):
    """一维滚动数组 O(cap) 空间版。关键: 容量 j 从大到小遍历, 保证每个物品只用一次。"""
    n = len(cost)
    dp = [0] * (cap + 1)
    for i in range(n):
        c, v = cost[i], value[i]
        for j in range(cap, c - 1, -1):     # 必须倒序!
            dp[j] = max(dp[j], dp[j - c] + v)
    return dp[cap]


if __name__ == "__main__":
    cost = [2, 3, 4, 5]
    value = [3, 4, 5, 6]
    cap = 8
    mv, _, picked = knapsack_2d(cost, value, cap)
    print("2D 最大价值:", mv, "选中的物品下标:", picked)
    print("1D 最大价值:", knapsack_1d(cost, value, cap))
