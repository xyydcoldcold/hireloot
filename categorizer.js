/*
 * Hireloot 任务分类器（可替换）
 * ------------------------------------------------------------
 * 接口约定：
 *   window.HirelootCategorizer.suggest(text) -> Promise<分类 key | null>
 *   分类 key 只能是：project | resume | apply | network | prep
 *
 * 现在用的是关键词规则。以后想换成 LLM 自动分类，只需改写 suggest()，
 * 例如调用本地的 Ollama 或一个你自己的后端代理（不要把 API Key 直接写在网页里）：
 *
 *   async suggest(text) {
 *     const res = await fetch('http://localhost:8787/categorize', {
 *       method: 'POST',
 *       headers: { 'Content-Type': 'application/json' },
 *       body: JSON.stringify({ text, categories: window.Hireloot.CATEGORY_KEYS })
 *     });
 *     const { category } = await res.json();
 *     return window.Hireloot.CATEGORY_KEYS.includes(category) ? category : null;
 *   }
 *
 * 网页在输入框打字时调用它，把结果显示成一个「归到 XX？」的小按钮，点了才会设置分类。
 * 任务默认是「无分类」(none)，不会被自动改掉。
 */
(function () {
  'use strict';

  const RULES = {
    network: ['networking', 'coffee', '咖啡', '校友', 'alumni', '内推', 'referral', 'linkedin', '领英',
      '联系', '发消息', '私信', '聚会', 'meetup', '认识', '加微信', '约饭', '约聊', '人脉', 'mentor', '导师', '活动', 'career fair', '招聘会'],
    apply: ['投递', '投简历', '申请', 'apply', 'application', '网申', '海投', '投了', 'submit', '职位', 'jd', 'job'],
    resume: ['简历', 'resume', 'cv', 'cover letter', '求职信', '作品集', 'portfolio', '个人主页', '自我介绍信'],
    prep: ['面试准备', '准备面试', '刷题', 'leetcode', '力扣', '八股', '模拟面试', 'mock', '行为面', 'behavioral', 'bq',
      'system design', '系统设计', '复习', '背', '练习', '算法题', 'star', '面经', 'case'],
    project: ['项目', 'project', '代码', 'code', 'coding', 'github', '开发', '实现', '部署', 'deploy', 'demo', 'feature',
      'bug', '重构', 'kaggle', '论文', 'paper', '模型', '训练', 'side project', 'app', '网站', 'api']
  };

  function score(text) {
    const t = String(text || '').toLowerCase();
    let best = null, bestScore = 0;
    for (const [key, words] of Object.entries(RULES)) {
      let s = 0;
      for (const w of words) if (t.includes(w)) s += w.length >= 3 ? 2 : 1;
      if (s > bestScore) { best = key; bestScore = s; }
    }
    return best;
  }

  window.HirelootCategorizer = {
    name: '关键词规则',
    async suggest(text) {
      return score(text);
    }
  };
})();
