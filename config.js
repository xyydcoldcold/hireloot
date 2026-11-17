/* Hireloot 云存档配置
 * 两项都留空 = 纯本地模式（和以前一样，数据只在这台浏览器里）。
 * 填上 Supabase 项目的 URL 和 anon key 就会开启邮箱登录 + 云存档。
 * anon key 本来就是给前端用的公开 key，可以提交到仓库；
 * 千万不要把 service_role key 填在这里。
 */
window.HIRELOOT_CONFIG = {
  supabaseUrl: '',      // 例如 'https://abcdefgh.supabase.co'
  supabaseAnonKey: ''   // Project Settings → API → anon public
};
