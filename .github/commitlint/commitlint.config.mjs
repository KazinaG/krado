// Conventional Commits 1.0.0（https://www.conventionalcommits.org/ja/v1.0.0/）を
// commitlint の @commitlint/config-conventional で確かめる（4つのリポジトリで同じファイル）。
// 件名（1行目）は英語で書く。日本語などの名前はバッククォートの中だけ（例 feat: add `出勤簿` export）。
// PR タイトルと、PR の枝の中のすべてのコミットの件名に同じ決まりを当てる。本文は自由（日本語でよい）。

// バッククォートの外に ASCII 以外の文字があるか。閉じていないバッククォートは囲みとみなさず落とす。
function headerAsciiOutsideBackticks({ header }) {
  const text = header || '';
  const how = '件名は英語で書き、日本語の名前は `出勤簿` のようにバッククォートで囲む（例 feat: add `出勤簿` export）';
  if ((text.match(/`/g) || []).length % 2) {
    return [false, `件名のバッククォート（\`）が閉じていません。${how}`];
  }
  const outside = text.split('`').filter((_, i) => i % 2 === 0).join('');
  const bad = [...new Set([...outside].filter((c) => c.codePointAt(0) > 0x7f))];
  if (bad.length) {
    const shown = bad.slice(0, 20).map((c) => `「${c}」(U+${c.codePointAt(0).toString(16).toUpperCase().padStart(4, '0')})`).join('、');
    return [false, `件名のバッククォートの外に英語以外の文字があります: ${shown}。${how}`];
  }
  return [true];
}

export default {
  extends: ['@commitlint/config-conventional'],
  plugins: [{ rules: { 'header-ascii-outside-backticks': headerAsciiOutsideBackticks } }],
  rules: {
    'header-ascii-outside-backticks': [2, 'always'],
    // 本文の1行の長さは見ない。Dependabot の本文は折り返せない URL を含み
    // （https://github.com/dependabot/dependabot-core/issues/2445）、日本語の本文も100字を超えやすい。
    'body-max-line-length': [0],
    // 件名の大文字・小文字は見ない。件名は「PR …」「UI …」「AGENTS.md …」のように
    // 英字の略語や名前で始まることがあり、既定の subject-case では文頭の大文字として落ちてしまう。
    'subject-case': [0],
  },
};
