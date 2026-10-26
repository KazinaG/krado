// Conventional Commits 1.0.0（https://www.conventionalcommits.org/ja/v1.0.0/）を
// commitlint の @commitlint/config-conventional で確かめる。
export default {
  extends: ['@commitlint/config-conventional'],
  rules: {
    // 本文の1行の長さだけは見ない。Dependabot の本文は折り返せない URL を含み
    // （https://github.com/dependabot/dependabot-core/issues/2445）、日本語の本文も100字を超えやすい。
    'body-max-line-length': [0],
  },
};
