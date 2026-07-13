//  @ts-check

import { tanstackConfig } from '@tanstack/eslint-config'

export default [
  ...tanstackConfig,
  {
    rules: {
      'import/no-cycle': 'off',
      'import/order': 'off',
      'sort-imports': 'off',
      '@typescript-eslint/array-type': 'off',
      '@typescript-eslint/require-await': 'off',
      'pnpm/json-enforce-catalog': 'off',
    },
  },
  {
    // Plain build/geometry files that live outside the TS project (the typed
    // parser has no tsconfig entry for them): the icon generator and the shared
    // brand geometry (typed for importers via brand.d.ts).
    ignores: [
      'eslint.config.js',
      'prettier.config.js',
      'scripts/**',
      'src/lib/brand.js',
    ],
  },
]
