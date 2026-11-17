/* Hireloot 云存档配置
 * 两项都留空 = 纯本地模式（和以前一样，数据只在这台浏览器里）。
 * 填上 Supabase 项目的 URL 和公开 key 就会开启邮箱登录 + 云存档。
 * 公开 key = Publishable key（sb_publishable_ 开头）或旧版的 anon key，可以提交到仓库；
 * 千万不要把 Secret key（sb_secret_ 开头）或 service_role key 填在这里。
 */
window.HIRELOOT_CONFIG = {
  supabaseUrl: '',      // 项目首页 Connect 按钮里，例如 'https://abcdefgh.supabase.co'
  supabaseAnonKey: ''   // Project Settings → API Keys → Publishable key
};
